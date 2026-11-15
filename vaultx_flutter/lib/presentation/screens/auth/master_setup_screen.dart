import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../widgets/vaultx_widgets.dart';

class MasterPasswordSetupScreen extends ConsumerStatefulWidget {
  const MasterPasswordSetupScreen({super.key});

  @override
  ConsumerState<MasterPasswordSetupScreen> createState() =>
      _MasterPasswordSetupScreenState();
}

class _MasterPasswordSetupScreenState
    extends ConsumerState<MasterPasswordSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _masterCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(vaultSessionProvider).authUser;
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _masterCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _creating = true);
    try {
      await ref.read(vaultSessionProvider.notifier).setupMasterPassword(
            masterPassword: _masterCtrl.text,
            displayName: _nameCtrl.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        showVaultSnackBar(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pwService = ref.read(passwordGeneratorServiceProvider);
    final strength = pwService.evaluateStrength(_masterCtrl.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Password Setup'),
        actions: [
          TextButton(
            onPressed: _creating
                ? null
                : () => ref.read(vaultSessionProvider.notifier).signOut(),
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Your Zero-Knowledge Key',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Master Password derives a 256-bit AES key locally using Argon2id (64 MiB, 3 iterations). It is never transmitted or stored.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vault Profile Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a display name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _masterCtrl,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Master Password (12+ chars)',
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
                  validator: (v) {
                    if (v == null || v.length < 12) {
                      return 'Use at least 12 characters for your Master Password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                PasswordStrengthMeter(result: strength),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Master Password',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded),
                  ),
                  validator: (v) {
                    if (v != _masterCtrl.text) {
                      return 'Master passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _creating ? null : _initialize,
                    child: _creating
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Deriving Argon2id Vault Key...'),
                            ],
                          )
                        : const Text('Initialize Encrypted Vault'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
