import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../domain/models/sharing_emergency_models.dart';
import '../../../domain/models/vault_record.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';

Future<void> showSharingEmergencySheet(
  BuildContext context, {
  DecryptedVaultRecord? recordToShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SharingEmergencySheet(recordToShare: recordToShare),
  );
}

class SharingEmergencySheet extends ConsumerStatefulWidget {
  final DecryptedVaultRecord? recordToShare;

  const SharingEmergencySheet({super.key, this.recordToShare});

  @override
  ConsumerState<SharingEmergencySheet> createState() =>
      _SharingEmergencySheetState();
}

class _SharingEmergencySheetState
    extends ConsumerState<SharingEmergencySheet> {
  final _recipientCtrl = TextEditingController();
  final _passcodeCtrl = TextEditingController();
  final _openEnvelopeCtrl = TextEditingController();
  final _openKeyCtrl = TextEditingController();
  final _openPasscodeCtrl = TextEditingController();

  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  int _waitHours = 72;
  int _expireHours = 24;

  String? _generatedEnvelope;
  String? _generatedShareKey;
  VaultRecordPayload? _openedPayload;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final em = ref.read(vaultSessionProvider).emergencyConfig;
    _contactNameCtrl.text = em.contactName;
    _contactEmailCtrl.text = em.contactEmail;
    _waitHours = em.waitingPeriodHours;
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _passcodeCtrl.dispose();
    _openEnvelopeCtrl.dispose();
    _openKeyCtrl.dispose();
    _openPasscodeCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _createShare() async {
    final rec = widget.recordToShare;
    if (rec == null) return;
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(vaultSessionProvider.notifier)
          .createEphemeralShare(
            record: rec,
            recipientLabel: _recipientCtrl.text,
            expiresIn: Duration(hours: _expireHours),
            optionalPasscode: _passcodeCtrl.text,
          );
      setState(() {
        _generatedEnvelope = res.encodedEnvelope;
        _generatedShareKey = res.shareKeyBase64Url;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decodeShare() async {
    setState(() => _busy = true);
    try {
      final payload = await ref
          .read(sharingEmergencyServiceProvider)
          .openEphemeralShare(
            encodedEnvelope: _openEnvelopeCtrl.text,
            shareKeyBase64Url: _openKeyCtrl.text,
            passcode: _openPasscodeCtrl.text,
          );
      setState(() => _openedPayload = payload);
    } catch (e) {
      if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEmergencyContact() async {
    if (_contactNameCtrl.text.trim().isEmpty ||
        !_contactEmailCtrl.text.contains('@')) {
      showVaultSnackBar(
        context,
        'Enter a valid trusted contact name and email.',
        isError: true,
      );
      return;
    }
    await ref.read(vaultSessionProvider.notifier).saveEmergencyContact(
          contactName: _contactNameCtrl.text,
          contactEmail: _contactEmailCtrl.text,
          waitingPeriodHours: _waitHours,
        );
    if (mounted) {
      showVaultSnackBar(context, 'Trusted emergency contact saved.');
    }
  }

  Future<void> _exportEmergencyEscrow() async {
    final masterCtrl = TextEditingController();
    final escrowCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Emergency Escrow Bundle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Derives an Argon2id + AES-256-GCM encrypted Recovery Bundle for your trusted contact without exposing plaintext on the server.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: masterCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Current Master Password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: escrowCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Trusted Contact Passphrase (10+ chars)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final bundle = await ref
            .read(vaultSessionProvider.notifier)
            .generateEmergencyRecoveryBundle(
              currentMasterPassword: masterCtrl.text,
              contactEscrowPassphrase: escrowCtrl.text,
            );
        await ref.read(vaultSessionProvider.notifier).copySensitiveValue(
              bundle,
              label: 'Encrypted Emergency Bundle',
              isSensitive: true,
            );
        if (mounted) {
          showVaultSnackBar(
            context,
            'Encrypted Emergency Escrow Bundle copied. Share offline with your contact.',
          );
        }
      } catch (e) {
        if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
      }
    }
    masterCtrl.dispose();
    escrowCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) {
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              const TabBar(
                tabs: [
                  Tab(text: 'Zero-Knowledge Share'),
                  Tab(text: 'Emergency Access'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (widget.recordToShare != null) ...[
                          Text(
                            'Seal "${widget.recordToShare!.title}"',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Encrypts only this record with a fresh 256-bit key (AES-256-GCM). No plaintext ever reaches Firestore.',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _recipientCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Recipient Label',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _expireHours,
                            decoration:
                                const InputDecoration(labelText: 'Expires In'),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 Hour')),
                              DropdownMenuItem(value: 24, child: Text('24 Hours')),
                              DropdownMenuItem(value: 168, child: Text('7 Days')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _expireHours = v);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passcodeCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Optional Recipient PIN / Passcode',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _createShare,
                              child: const Text('Create Encrypted Share Package'),
                            ),
                          ),
                        ],
                        if (_generatedEnvelope != null &&
                            _generatedShareKey != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1. Encrypted Share Envelope',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  SelectableText(
                                    _generatedEnvelope!,
                                    maxLines: 3,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => ref
                                        .read(vaultSessionProvider.notifier)
                                        .copySensitiveValue(
                                          _generatedEnvelope!,
                                          label: 'Encrypted Envelope',
                                          isSensitive: false,
                                        ),
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Copy Envelope'),
                                  ),
                                  const Divider(),
                                  const Text(
                                    '2. Out-of-Band Decryption Key',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  SelectableText(
                                    _generatedShareKey!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => ref
                                        .read(vaultSessionProvider.notifier)
                                        .copySensitiveValue(
                                          _generatedShareKey!,
                                          label: 'Share Key',
                                          isSensitive: true,
                                        ),
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Copy Share Key'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        const VaultSectionHeader(
                          title: 'Open Received Share Package',
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _openEnvelopeCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Paste Encrypted Envelope JSON',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _openKeyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paste Share Key',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _openPasscodeCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Passcode (if protected)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _busy ? null : _decodeShare,
                            child: const Text('Decrypt Shared Item'),
                          ),
                        ),
                        if (_openedPayload != null) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: ListTile(
                              title: Text(_openedPayload!.title),
                              subtitle: Text(
                                '${_openedPayload!.username}\n${_openedPayload!.password}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        ],
                        if (state.shareLedger.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const VaultSectionHeader(title: 'Issued Share Ledger'),
                          const SizedBox(height: 8),
                          ...state.shareLedger.map(
                            (s) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(s.recordTitle),
                                subtitle: Text(
                                  '${s.recipientLabel} · ${s.revokedLocally ? 'Revoked locally' : (s.isExpired ? 'Expired' : 'Active')}',
                                ),
                                trailing: s.revokedLocally
                                    ? null
                                    : TextButton(
                                        onPressed: () => ref
                                            .read(vaultSessionProvider.notifier)
                                            .revokeShareLocally(s.shareId),
                                        child: const Text('Revoke'),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: VaultXColors.sky.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Zero-Knowledge Foundation: Trusted contact policy, waiting-period workflow, and encrypted offline Recovery Escrow run client-side. Cloud-automated release across accounts requires future backend Cloud Functions without server plaintext access.',
                            style: TextStyle(fontSize: 12.5, height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _contactNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Trusted Contact Name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Trusted Contact Email',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _waitHours,
                          decoration: const InputDecoration(
                            labelText: 'Mandatory Waiting Period',
                          ),
                          items: const [
                            DropdownMenuItem(value: 24, child: Text('24 Hours')),
                            DropdownMenuItem(value: 72, child: Text('3 Days (72h)')),
                            DropdownMenuItem(value: 168, child: Text('7 Days')),
                            DropdownMenuItem(value: 336, child: Text('14 Days')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _waitHours = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saveEmergencyContact,
                            child: const Text('Save Emergency Contact Policy'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.emergencyConfig.isConfigured) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Workflow Status: ${state.emergencyConfig.status.name}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => ref
                                            .read(vaultSessionProvider.notifier)
                                            .updateEmergencyStatus(
                                              EmergencyAccessStatus
                                                  .requestPendingWaitingPeriod,
                                            ),
                                        child: const Text('Simulate Request'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => ref
                                            .read(vaultSessionProvider.notifier)
                                            .updateEmergencyStatus(
                                              EmergencyAccessStatus
                                                  .readyForLocalRecovery,
                                            ),
                                        child: const Text('Approve Release'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => ref
                                            .read(vaultSessionProvider.notifier)
                                            .updateEmergencyStatus(
                                              EmergencyAccessStatus.denied,
                                            ),
                                        child: const Text('Deny'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _exportEmergencyEscrow,
                                      icon: const Icon(Icons.shield_outlined),
                                      label: const Text(
                                        'Generate Encrypted Escrow Bundle',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
