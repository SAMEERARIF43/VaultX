import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import '../vault/record_detail_sheet.dart';

class AutofillScreen extends ConsumerStatefulWidget {
  const AutofillScreen({super.key});

  @override
  ConsumerState<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends ConsumerState<AutofillScreen> {
  final _domainTestCtrl = TextEditingController(text: 'https://github.com');
  final _pkgTestCtrl = TextEditingController();

  @override
  void dispose() {
    _domainTestCtrl.dispose();
    _pkgTestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final controller = ref.read(vaultSessionProvider.notifier);
    final matcher = ref.read(domainMatchingServiceProvider);
    final theme = Theme.of(context);

    final matches = matcher.matchRecordsForAutofill(
      state.decryptedRecords,
      webDomain: _domainTestCtrl.text.trim(),
      androidPackage: _pkgTestCtrl.text.trim().isEmpty
          ? null
          : _pkgTestCtrl.text.trim(),
    );

    final autofillSupported = state.autofillStatus.supported;
    final isDefault = state.autofillStatus.isDefaultProvider;
    final biometricReady =
        state.localPreferences.biometricUnlockEnabled &&
            state.hasBiometricEnrolledKey;

    return RefreshIndicator(
      onRefresh: () => controller.refreshAutofillAndBiometricStatus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isDefault
                                  ? VaultXColors.emerald
                                  : VaultXColors.amber)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDefault
                              ? Icons.verified_user_rounded
                              : Icons.phonelink_lock_rounded,
                          color: isDefault
                              ? VaultXColors.emerald
                              : VaultXColors.amber,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDefault
                                  ? 'VaultX Autofill Active'
                                  : 'Enable Android Autofill',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              !autofillSupported
                                  ? 'Requires Android 8.0+ runtime'
                                  : isDefault
                                      ? 'System default autofill provider enabled'
                                      : 'Not yet selected in Android system settings',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final opened = await ref
                            .read(androidSecurityChannelProvider)
                            .openAutofillSystemSettings();
                        if (!opened && context.mounted) {
                          showVaultSnackBar(
                            context,
                            'Open Android Settings > Passwords & accounts > Autofill service and select VaultX.',
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_suggest_rounded),
                      label: Text(
                        isDefault
                            ? 'Manage Android Autofill Settings'
                            : 'Select VaultX as Autofill Service',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const VaultSectionHeader(title: 'Zero-Plaintext Security Readiness'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Sync Encrypted Autofill Index',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Stores credentials encrypted with your Vault DEK + Android Keystore so Android Autofill never stores plaintext.',
                  ),
                  value: state.localPreferences.autofillIndexSyncEnabled,
                  onChanged: (v) => controller.updateLocalDevicePreferences(
                    state.localPreferences
                        .copyWith(autofillIndexSyncEnabled: v),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    biometricReady
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: biometricReady
                        ? VaultXColors.emerald
                        : VaultXColors.amber,
                  ),
                  title: const Text('Biometric Hardware DEK Enrollment'),
                  subtitle: Text(
                    biometricReady
                        ? 'Enrolled · BiometricPrompt.CryptoObject required before filling'
                        : 'Enable Biometric Unlock in Settings so Autofill can authenticate & unwrap your vault key.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const VaultSectionHeader(title: 'Strict Domain & Package Matcher'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verify which encrypted credentials match a browser domain or Android package. Unrelated domains and wildcards are strictly rejected.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _domainTestCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Target Website Domain / URL',
                      hintText: 'https://accounts.google.com',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pkgTestCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Target Android Package (optional)',
                      hintText: 'com.github.android',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${matches.length} Matching Credential(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (matches.isEmpty)
                    Text(
                      'No credentials match this domain/package.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    ...matches.map(
                      (rec) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(rec.recordType.icon),
                        title: Text(rec.title),
                        subtitle: Text(
                          '${rec.username} · ${rec.url.isNotEmpty ? rec.url : (rec.payload.packageName ?? '')}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showRecordDetailSheet(context, rec),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
