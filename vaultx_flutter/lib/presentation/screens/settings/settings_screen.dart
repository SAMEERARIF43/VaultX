import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/providers.dart';
import '../../../core/constants/vault_constants.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import '../sharing/sharing_emergency_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _editDisplayName(String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profile Display Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Display Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null && saved.trim().isNotEmpty && mounted) {
      await ref.read(vaultSessionProvider.notifier).updateDisplayName(saved);
      if (mounted) showVaultSnackBar(context, 'Profile display name updated.');
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    setState(() => _busy = true);
    final controller = ref.read(vaultSessionProvider.notifier);
    try {
      if (enable) {
        await controller.enableBiometricUnlock();
        if (mounted) {
          showVaultSnackBar(
            context,
            'Hardware Android Keystore biometric unlock enabled.',
          );
        }
      } else {
        await controller.disableBiometricUnlock();
        if (mounted) {
          showVaultSnackBar(context, 'Biometric unlock disabled.');
        }
      }
    } catch (e) {
      if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup() async {
    final passCtrl = TextEditingController();
    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Encrypted Backup (.vaultx)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Creates an Argon2id (64 MiB) + AES-256-GCM encrypted backup file. Never exports plaintext passwords.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup Passphrase (8+ chars)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(passCtrl.text),
            child: const Text('Export'),
          ),
        ],
      ),
    );
    passCtrl.dispose();

    if (passphrase == null || passphrase.length < 8) {
      if (passphrase != null && mounted) {
        showVaultSnackBar(
          context,
          'Backup passphrase must be at least 8 characters.',
          isError: true,
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final jsonBackup = await ref
          .read(vaultSessionProvider.notifier)
          .exportEncryptedBackup(passphrase);
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/vaultx_backup_$ts.vaultx');
      await file.writeAsString(jsonBackup);

      await SharePlus.instance.share(
        ShareParams(
          subject: 'VaultX Encrypted Vault Backup',
          text: 'Encrypted VaultXBackup-v1 archive.',
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (picked == null || picked.files.first.path == null) return;

    final rawJson = await File(picked.files.first.path!).readAsString();
    if (!mounted) return;

    final passCtrl = TextEditingController();
    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decrypt Backup Archive'),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Backup Passphrase'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(passCtrl.text),
            child: const Text('Decrypt & Import'),
          ),
        ],
      ),
    );
    passCtrl.dispose();

    if (passphrase == null || passphrase.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await ref
          .read(vaultSessionProvider.notifier)
          .restoreEncryptedBackup(
            rawJson: rawJson,
            backupPassphrase: passphrase,
          );
      if (mounted) {
        showVaultSnackBar(
          context,
          'Restored $count encrypted record(s) into your vault.',
        );
      }
    } catch (e) {
      if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotateMasterPasswordDialog() async {
    final currentCtrl = TextEditingController();
    final nextCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rotate Master Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Re-wraps your existing 256-bit DEK under a new Argon2id Master Key without losing existing records.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Current Master Password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nextCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Master Password (12+ chars)',
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
            child: const Text('Rotate Key'),
          ),
        ],
      ),
    );

    if (confirmed == true && nextCtrl.text.length >= 12 && mounted) {
      try {
        await ref.read(vaultSessionProvider.notifier).changeMasterPassword(
              currentMasterPassword: currentCtrl.text,
              newMasterPassword: nextCtrl.text,
            );
        if (mounted) {
          showVaultSnackBar(context, 'Master Password rotated successfully.');
        }
      } catch (e) {
        if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
      }
    }
    currentCtrl.dispose();
    nextCtrl.dispose();
  }

  Future<void> _rotateRecoveryKeyDialog() async {
    final masterCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate 256-Bit Recovery Key'),
        content: TextField(
          controller: masterCtrl,
          obscureText: true,
          decoration:
              const InputDecoration(labelText: 'Confirm Master Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final newKey = await ref
            .read(vaultSessionProvider.notifier)
            .regenerateRecoveryKey(masterCtrl.text);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('New Recovery Key'),
              content: SelectableText(
                newKey,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(vaultSessionProvider.notifier)
                      .copySensitiveValue(
                        newKey,
                        label: 'New Recovery Key',
                        isSensitive: true,
                      ),
                  child: const Text('Copy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
      }
    }
    masterCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final controller = ref.read(vaultSessionProvider.notifier);
    final prefs = state.localPreferences;
    final cloud = state.securitySettings;
    final profileName =
        state.userProfile?.displayName ?? state.authUser?.displayName ?? 'Vault Owner';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
            title: Text(
              profileName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(state.authUser?.email ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editDisplayName(profileName),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const VaultSectionHeader(title: 'Appearance'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ],
              selected: {prefs.themeMode},
              onSelectionChanged: (set) => controller.updateLocalDevicePreferences(
                prefs.copyWith(themeMode: set.first),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const VaultSectionHeader(title: 'Android Device Security'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Biometric Unlock (Android Keystore)'),
                subtitle: Text(
                  state.biometricCapability.available
                      ? 'Uses BiometricPrompt.CryptoObject hardware key wrapping'
                      : 'Biometrics unavailable on this device (${state.biometricCapability.status})',
                ),
                value: prefs.biometricUnlockEnabled && state.hasBiometricEnrolledKey,
                onChanged: _busy || !state.biometricCapability.available
                    ? null
                    : _toggleBiometrics,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Screenshot & Recents Blur (FLAG_SECURE)'),
                subtitle: const Text(
                  'Blocks Android screenshots, screen recording, and app-switcher previews.',
                ),
                value: prefs.screenshotProtectionEnabled,
                onChanged: (v) => controller.updateLocalDevicePreferences(
                  prefs.copyWith(screenshotProtectionEnabled: v),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Lock Immediately on Background'),
                subtitle: const Text(
                  'Clears in-memory vault encryption key when leaving VaultX.',
                ),
                value: prefs.lockOnBackground,
                onChanged: (v) => controller.updateLocalDevicePreferences(
                  prefs.copyWith(lockOnBackground: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const VaultSectionHeader(title: 'Vault Policies (Synced)'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Auto-Lock Inactivity Timeout'),
                trailing: DropdownButton<int>(
                  value: cloud.autoLockMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [1, 5, 15, 30, 60]
                      .map((m) => DropdownMenuItem(value: m, child: Text('${m}m')))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) {
                      controller.updateCloudSecuritySettings(
                        autoLockMinutes: m,
                        clipboardClearSeconds: cloud.clipboardClearSeconds,
                        requireReauthForReveal: cloud.requireReauthForReveal,
                      );
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Clipboard Auto-Wipe Timer'),
                trailing: DropdownButton<int>(
                  value: cloud.clipboardClearSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [10, 20, 30, 60, 120]
                      .map((s) => DropdownMenuItem(value: s, child: Text('${s}s')))
                      .toList(),
                  onChanged: (s) {
                    if (s != null) {
                      controller.updateCloudSecuritySettings(
                        autoLockMinutes: cloud.autoLockMinutes,
                        clipboardClearSeconds: s,
                        requireReauthForReveal: cloud.requireReauthForReveal,
                      );
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Require Master Password Before Reveal'),
                value: cloud.requireReauthForReveal,
                onChanged: (v) => controller.updateCloudSecuritySettings(
                  autoLockMinutes: cloud.autoLockMinutes,
                  clipboardClearSeconds: cloud.clipboardClearSeconds,
                  requireReauthForReveal: v,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const VaultSectionHeader(title: 'Backup, Keys & Zero-Knowledge Sharing'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Export Encrypted Backup (.vaultx)'),
                subtitle: const Text('Argon2id + AES-256-GCM archive'),
                onTap: _busy ? null : _exportBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Restore Encrypted Backup'),
                subtitle: const Text('Decrypt & merge records locally'),
                onTap: _busy ? null : _restoreBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Zero-Knowledge Share & Emergency Access'),
                subtitle: const Text('Ephemeral shares & trusted escrow bundle'),
                onTap: () => showSharingEmergencySheet(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: const Text('Rotate Master Password'),
                onTap: _rotateMasterPasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Regenerate 256-Bit Recovery Key'),
                onTap: _rotateRecoveryKeyDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cryptographic & Cloud Configuration',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'KDF: Argon2id v1.3 (${VaultConstants.defaultKdfMemoryKiB} KiB, ${VaultConstants.defaultKdfIterations} iter, p=${VaultConstants.defaultKdfParallelism})\n'
                  'Cipher: AES-256-GCM (12B nonce, 16B tag)\n'
                  'Firebase Project: ${VaultConstants.firebaseProjectId}\n'
                  'Firestore DB: ${VaultConstants.firestoreDatabaseId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.lockVault(
                  reason: 'Vault locked manually.',
                ),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Lock Vault'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: VaultXColors.rose,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => controller.signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
