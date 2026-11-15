import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../application/providers.dart';
import '../../../domain/models/vault_record.dart';
import '../../../domain/models/vault_record_type.dart';
import '../../../domain/models/wallet_details.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import '../vault/record_detail_sheet.dart';

class AuthenticatorScreen extends ConsumerStatefulWidget {
  const AuthenticatorScreen({super.key});

  @override
  ConsumerState<AuthenticatorScreen> createState() =>
      _AuthenticatorScreenState();
}

class _AuthenticatorScreenState extends ConsumerState<AuthenticatorScreen> {
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();
  final Map<String, String> _codes = {};

  @override
  void initState() {
    super.initState();
    _refreshCodes();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowUtc = DateTime.now().toUtc();
      _refreshCodes();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshCodes() async {
    final records = ref.read(vaultSessionProvider).decryptedRecords;
    final totpService = ref.read(totpServiceProvider);
    final nextCodes = <String, String>{};

    for (final rec in records) {
      final totp = rec.payload.totp;
      if (totp == null || rec.decryptionError) continue;
      try {
        nextCodes[rec.id] =
            await totpService.generateCode(totp, timestamp: _nowUtc);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _codes
          ..clear()
          ..addAll(nextCodes);
      });
    }
  }

  Future<void> _saveTotpDetails(TotpDetails details) async {
    final title = details.issuer.isNotEmpty
        ? details.issuer
        : (details.accountName.isNotEmpty
            ? details.accountName
            : '2FA Account');
    await ref.read(vaultSessionProvider.notifier).saveRecord(
          VaultRecordPayload(
            title: title,
            username: details.accountName,
            category: 'Personal',
            recordType: VaultRecordType.totp,
            totp: details,
          ),
        );
    await _refreshCodes();
  }

  Future<void> _openQrScanner() async {
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    var handled = false;

    final scanned = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan 2FA QR Code'),
        content: SizedBox(
          width: 280,
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: MobileScanner(
              controller: controller,
              errorBuilder: (ctx, error) => Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Text(
                  'Camera unavailable (${error.errorCode.name}). Use URI paste or manual Base32 entry instead.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              onDetect: (BarcodeCapture capture) {
                if (handled) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.trim().isNotEmpty) {
                    handled = true;
                    Navigator.of(ctx).pop(raw.trim());
                    break;
                  }
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    await controller.dispose();

    if (scanned != null && mounted) {
      try {
        final parsed = ref.read(totpServiceProvider).parseOtpAuthUri(scanned);
        await _saveTotpDetails(parsed);
        if (mounted) {
          showVaultSnackBar(context, 'Added 2FA token for ${parsed.issuer}.');
        }
      } catch (e) {
        if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _openAddManualDialog() async {
    final uriCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final secretCtrl = TextEditingController();

    final saved = await showDialog<TotpDetails>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add 2FA Token'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uriCtrl,
                decoration: const InputDecoration(
                  labelText: 'Paste otpauth://totp/... URI (optional)',
                ),
              ),
              const SizedBox(height: 12),
              const Text('— or enter manually —', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: issuerCtrl,
                decoration: const InputDecoration(labelText: 'Service / Issuer'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accountCtrl,
                decoration: const InputDecoration(labelText: 'Account Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: secretCtrl,
                decoration: const InputDecoration(labelText: 'Base32 Secret Key'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final totpService = ref.read(totpServiceProvider);
              try {
                if (uriCtrl.text.trim().isNotEmpty) {
                  final parsed =
                      totpService.parseOtpAuthUri(uriCtrl.text.trim());
                  Navigator.of(ctx).pop(parsed);
                } else {
                  totpService.decodeBase32(secretCtrl.text);
                  Navigator.of(ctx).pop(
                    TotpDetails(
                      issuer: issuerCtrl.text.trim().isEmpty
                          ? 'Authenticator'
                          : issuerCtrl.text.trim(),
                      accountName: accountCtrl.text.trim(),
                      secretBase32: secretCtrl.text
                          .trim()
                          .toUpperCase()
                          .replaceAll(RegExp(r'[\s\-]'), ''),
                    ),
                  );
                }
              } catch (e) {
                showVaultSnackBar(ctx, e.toString(), isError: true);
              }
            },
            child: const Text('Encrypt & Add'),
          ),
        ],
      ),
    );

    uriCtrl.dispose();
    issuerCtrl.dispose();
    accountCtrl.dispose();
    secretCtrl.dispose();

    if (saved != null && mounted) {
      await _saveTotpDetails(saved);
      if (mounted) {
        showVaultSnackBar(context, 'Encrypted 2FA token saved.');
      }
    }
  }

  void _showProvisioningQr(TotpDetails details) {
    final uri = ref.read(totpServiceProvider).buildOtpAuthUri(details);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${details.issuer} Setup QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: uri,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Generated locally in memory for offline backup.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final totpService = ref.read(totpServiceProvider);
    final theme = Theme.of(context);

    final totpRecords = state.decryptedRecords
        .where((r) => !r.decryptionError && r.payload.totp != null)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openQrScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openAddManualDialog,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('URI / Manual'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: totpRecords.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 48,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No 2FA Authenticator Tokens',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Scan an otpauth:// QR code or attach a Base32 secret to any Vault login.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: totpRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final rec = totpRecords[index];
                      final totp = rec.payload.totp!;
                      final rawCode = _codes[rec.id] ?? '------';
                      final formattedCode = rawCode.length == 6
                          ? '${rawCode.substring(0, 3)} ${rawCode.substring(3)}'
                          : rawCode;
                      final secondsLeft = totpService.secondsRemaining(
                        totp,
                        timestamp: _nowUtc,
                      );
                      final progress = totpService.progressRemaining(
                        totp,
                        timestamp: _nowUtc,
                      );
                      final isExpiringSoon = secondsLeft <= 5;

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => showRecordDetailSheet(context, rec),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 4,
                                        backgroundColor: theme.dividerColor,
                                        color: isExpiringSoon
                                            ? VaultXColors.rose
                                            : theme.colorScheme.primary,
                                      ),
                                      Text(
                                        '$secondsLeft',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isExpiringSoon
                                              ? VaultXColors.rose
                                              : null,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        totp.issuer.isNotEmpty
                                            ? totp.issuer
                                            : rec.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (totp.accountName.isNotEmpty ||
                                          rec.username.isNotEmpty)
                                        Text(
                                          totp.accountName.isNotEmpty
                                              ? totp.accountName
                                              : rec.username,
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formattedCode,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                          color: isExpiringSoon
                                              ? VaultXColors.rose
                                              : theme.colorScheme.primary,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Inspect Local QR',
                                  icon: const Icon(Icons.qr_code_2_rounded),
                                  onPressed: () => _showProvisioningQr(totp),
                                ),
                                IconButton(
                                  tooltip: 'Copy Code',
                                  icon: const Icon(Icons.copy_rounded),
                                  onPressed: () async {
                                    await ref
                                        .read(vaultSessionProvider.notifier)
                                        .copySensitiveValue(
                                          rawCode,
                                          label: '${rec.title} 2FA code',
                                          isSensitive: true,
                                        );
                                    if (context.mounted) {
                                      showVaultSnackBar(
                                        context,
                                        '2FA code copied.',
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
