import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../domain/models/vault_record.dart';
import '../../../domain/models/vault_record_type.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import '../sharing/sharing_emergency_sheet.dart';
import 'record_editor_sheet.dart';

Future<void> showRecordDetailSheet(
  BuildContext context,
  DecryptedVaultRecord record,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => RecordDetailSheet(record: record),
  );
}

class RecordDetailSheet extends ConsumerStatefulWidget {
  final DecryptedVaultRecord record;

  const RecordDetailSheet({super.key, required this.record});

  @override
  ConsumerState<RecordDetailSheet> createState() => _RecordDetailSheetState();
}

class _RecordDetailSheetState extends ConsumerState<RecordDetailSheet> {
  bool _secretRevealed = false;
  Timer? _totpTicker;
  String? _totpCode;
  int _totpSecondsLeft = 30;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(vaultSessionProvider.notifier).markRecordAccessed(widget.record);
    });
    if (widget.record.payload.totp != null) {
      _refreshTotp();
      _totpTicker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refreshTotp(),
      );
    }
  }

  @override
  void dispose() {
    _totpTicker?.cancel();
    super.dispose();
  }

  Future<void> _refreshTotp() async {
    final totp = widget.record.payload.totp;
    if (totp == null) return;
    final service = ref.read(totpServiceProvider);
    try {
      final code = await service.generateCode(totp);
      final left = service.secondsRemaining(totp);
      if (mounted) {
        setState(() {
          _totpCode = code;
          _totpSecondsLeft = left;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleReveal() async {
    if (_secretRevealed) {
      setState(() => _secretRevealed = false);
      return;
    }

    final requireReauth =
        ref.read(vaultSessionProvider).securitySettings.requireReauthForReveal;
    if (!requireReauth) {
      setState(() => _secretRevealed = true);
      return;
    }

    final pwCtrl = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Master Password'),
        content: TextField(
          controller: pwCtrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Master Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(vaultSessionProvider.notifier)
                  .verifyMasterPassword(pwCtrl.text);
              if (ctx.mounted) Navigator.of(ctx).pop(ok);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    pwCtrl.dispose();

    if (verified == true && mounted) {
      setState(() => _secretRevealed = true);
    } else if (verified == false && mounted) {
      showVaultSnackBar(context, 'Incorrect master password.', isError: true);
    }
  }

  Future<void> _copy(String value, String label, {bool sensitive = true}) async {
    await ref.read(vaultSessionProvider.notifier).copySensitiveValue(
          value,
          label: label,
          isSensitive: sensitive,
        );
    if (mounted) {
      showVaultSnackBar(
        context,
        sensitive
            ? '$label copied with automatic clipboard wipe.'
            : '$label copied.',
      );
    }
  }

  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Encrypted Record?'),
        content: Text(
          'Permanently delete "${widget.record.title}" from your encrypted cloud vault?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VaultXColors.rose),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(vaultSessionProvider.notifier)
          .deleteRecord(widget.record.id);
      if (mounted) {
        Navigator.of(context).pop();
        showVaultSnackBar(context, 'Record deleted.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = ref
            .watch(vaultSessionProvider)
            .decryptedRecords
            .where((r) => r.id == widget.record.id)
            .firstOrNull ??
        widget.record;
    final p = rec.payload;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollCtrl) {
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(p.recordType.icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${p.recordType.label} · ${p.category}${p.folder != null ? ' · ${p.folder}' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    p.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: p.isFavorite ? Colors.amber : null,
                  ),
                  onPressed: () =>
                      ref.read(vaultSessionProvider.notifier).toggleFavorite(rec),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (p.username.isNotEmpty)
              _DetailFieldCard(
                label: 'Username / Email',
                value: p.username,
                onCopy: () => _copy(p.username, 'Username', sensitive: false),
              ),

            if (p.password.isNotEmpty)
              _DetailFieldCard(
                label: p.recordType == VaultRecordType.wifi
                    ? 'Wi-Fi Passphrase'
                    : 'Password',
                value: _secretRevealed ? p.password : '••••••••••••••••',
                monospace: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _secretRevealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _toggleReveal,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => _copy(p.password, 'Password'),
                    ),
                  ],
                ),
              ),

            if (p.totp != null && _totpCode != null)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '2FA Authenticator Code',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_totpCode!.substring(0, 3)} ${_totpCode!.substring(3)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_totpSecondsLeft}s',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () => _copy(_totpCode!, '2FA Code'),
                      ),
                    ],
                  ),
                ),
              ),

            if (p.url.isNotEmpty)
              _DetailFieldCard(
                label: 'Website URL',
                value: p.url,
                onCopy: () => _copy(p.url, 'URL', sensitive: false),
              ),

            if (p.packageName != null && p.packageName!.isNotEmpty)
              _DetailFieldCard(
                label: 'Android Package',
                value: p.packageName!,
                onCopy: () =>
                    _copy(p.packageName!, 'Package Name', sensitive: false),
              ),

            if (p.card != null) ...[
              _DetailFieldCard(
                label: 'Cardholder & Brand',
                value: '${p.card!.cardholderName} · ${p.card!.brand}',
              ),
              _DetailFieldCard(
                label: 'Card Number',
                value: _secretRevealed
                    ? p.card!.cardNumber
                    : p.card!.maskedLast4,
                monospace: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _secretRevealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _toggleReveal,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () =>
                          _copy(p.card!.cardNumber, 'Card Number'),
                    ),
                  ],
                ),
              ),
              _DetailFieldCard(
                label: 'Expiry & CVV',
                value:
                    '${p.card!.expiryMonth}/${p.card!.expiryYear} · CVV: ${_secretRevealed ? p.card!.cvv : '•••'}',
                onCopy: () => _copy(p.card!.cvv, 'CVV'),
              ),
            ],

            if (p.identity != null) ...[
              _DetailFieldCard(
                label: p.identity!.documentType,
                value:
                    '${p.identity!.fullName}\n${_secretRevealed ? p.identity!.documentNumber : '••••••'}\n${p.identity!.issuingCountry}',
                trailing: IconButton(
                  icon: Icon(
                    _secretRevealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: _toggleReveal,
                ),
                onCopy: () =>
                    _copy(p.identity!.documentNumber, 'Document Number'),
              ),
            ],

            if (p.license != null)
              _DetailFieldCard(
                label: 'Software License Key',
                value: _secretRevealed ? p.license!.licenseKey : '••••••••••••',
                monospace: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _secretRevealed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _toggleReveal,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () =>
                          _copy(p.license!.licenseKey, 'License Key'),
                    ),
                  ],
                ),
              ),

            if (p.recoveryCodes != null && p.recoveryCodes!.codes.isNotEmpty)
              _DetailFieldCard(
                label: 'Recovery Codes (${p.recoveryCodes!.codes.length})',
                value: _secretRevealed
                    ? p.recoveryCodes!.codes.join('\n')
                    : 'Tap eye icon to reveal codes',
                monospace: true,
                trailing: IconButton(
                  icon: Icon(
                    _secretRevealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: _toggleReveal,
                ),
              ),

            if (p.notes.isNotEmpty)
              _DetailFieldCard(
                label: 'Encrypted Notes',
                value: p.notes,
              ),

            if (p.passwordHistory.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Password History (${p.passwordHistory.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: p.passwordHistory
                    .map(
                      (h) => ListTile(
                        dense: true,
                        title: Text(
                          _secretRevealed ? h.password : '••••••••••••',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        subtitle: Text(
                          h.changedAt?.toLocal().toString().split('.').first ??
                              h.changedAtIso,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () => _copy(h.password, 'Previous Password'),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              'Created ${rec.createdAt.toLocal().toString().split('.').first} · Updated ${rec.updatedAt.toLocal().toString().split('.').first}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showRecordEditorSheet(context, existing: rec);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        showSharingEmergencySheet(context, recordToShare: rec),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('E2EE Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _deleteRecord,
                style: TextButton.styleFrom(foregroundColor: VaultXColors.rose),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Record'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailFieldCard extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final VoidCallback? onCopy;
  final Widget? trailing;

  const _DetailFieldCard({
    required this.label,
    required this.value,
    this.monospace = false,
    this.onCopy,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    value,
                    style: TextStyle(
                      fontFamily: monospace ? 'monospace' : null,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onCopy != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                onPressed: onCopy,
              ),
          ],
        ),
      ),
    );
  }
}
