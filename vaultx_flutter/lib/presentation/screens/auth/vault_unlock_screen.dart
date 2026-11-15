import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/errors/vault_exceptions.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';

class VaultUnlockScreen extends ConsumerStatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  ConsumerState<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends ConsumerState<VaultUnlockScreen> {
  final _masterCtrl = TextEditingController();
  final _recoveryCtrl = TextEditingController();
  bool _recoveryMode = false;
  bool _obscure = true;
  bool _unlocking = false;

  @override
  void dispose() {
    _masterCtrl.dispose();
    _recoveryCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPasswordOrRecovery() async {
    setState(() => _unlocking = true);
    final controller = ref.read(vaultSessionProvider.notifier);
    try {
      if (_recoveryMode) {
        await controller.unlockWithRecoveryKey(_recoveryCtrl.text);
      } else {
        await controller.unlockWithMasterPassword(_masterCtrl.text);
      }
      _masterCtrl.clear();
      _recoveryCtrl.clear();
    } on InvalidMasterPasswordException catch (e) {
      if (mounted) showVaultSnackBar(context, e.message, isError: true);
    } on InvalidRecoveryKeyException catch (e) {
      if (mounted) showVaultSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() => _unlocking = true);
    try {
      await ref.read(vaultSessionProvider.notifier).unlockWithBiometrics();
    } on BiometricAuthException catch (e) {
      if (mounted && !e.isCancelled) {
        showVaultSnackBar(context, e.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        showVaultSnackBar(
          context,
          'Biometric unlock failed. Enter your Master Password.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final theme = Theme.of(context);
    final email = state.authUser?.email ?? '';
    final canUseBiometrics =
        state.localPreferences.biometricUnlockEnabled &&
            state.hasBiometricEnrolledKey &&
            state.biometricCapability.available;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SyncStatusIndicator(
                    syncState: state.syncState,
                    pendingCount: state.pendingOfflineMutationCount,
                    conflictCount: state.syncConflicts.length,
                  ),
                  TextButton(
                    onPressed: _unlocking
                        ? null
                        : () =>
                            ref.read(vaultSessionProvider.notifier).signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Vault Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (state.lockBannerMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VaultXColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.lockBannerMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (canUseBiometrics) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _unlocking ? null : _unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text('Unlock with Biometrics'),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (!_recoveryMode)
                TextField(
                  controller: _masterCtrl,
                  obscureText: _obscure,
                  onSubmitted: (_) => _unlockWithPasswordOrRecovery(),
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                )
              else
                TextField(
                  controller: _recoveryCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '256-Bit Recovery Key (VX-...)',
                    helperText: state.masterConfig != null
                        ? 'Key hint: ${state.masterConfig!.recoveryKeyHint}'
                        : null,
                    prefixIcon: const Icon(Icons.shield_outlined),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _unlocking ? null : _unlockWithPasswordOrRecovery,
                  child: _unlocking
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Deriving Key...'),
                          ],
                        )
                      : Text(
                          _recoveryMode
                              ? 'Unlock with Recovery Key'
                              : 'Unlock Vault',
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _unlocking
                      ? null
                      : () => setState(() => _recoveryMode = !_recoveryMode),
                  child: Text(
                    _recoveryMode
                        ? 'Back to Master Password'
                        : 'Forgot Master Password? Use Recovery Key',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
