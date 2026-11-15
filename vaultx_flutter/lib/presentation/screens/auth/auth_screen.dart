import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../widgets/vaultx_widgets.dart';

enum _AuthMode { login, register, forgotPassword }

class AuthScreen extends ConsumerStatefulWidget {
  final String initialMode;

  const AuthScreen({super.key, this.initialMode = 'login'});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late _AuthMode _mode;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'register'
        ? _AuthMode.register
        : _AuthMode.login;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _friendlyFirebaseAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Invalid email or account password.',
      'email-already-in-use' =>
        'An account already exists with this email address.',
      'weak-password' =>
        'Account password is too weak. Use at least 8 characters.',
      'too-many-requests' =>
        'Too many authentication attempts. Wait a moment and retry.',
      'network-request-failed' =>
        'Network unavailable. Check connectivity and try again.',
      'aborted-by-user' => 'Google sign-in was cancelled.',
      _ => e.message ?? 'Authentication failed. Please try again.',
    };
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final controller = ref.read(vaultSessionProvider.notifier);

    try {
      switch (_mode) {
        case _AuthMode.login:
          await controller.signInWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
          break;
        case _AuthMode.register:
          await controller.registerWithEmail(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text,
          );
          if (mounted) {
            showVaultSnackBar(
              context,
              'Account created. Check your inbox for the verification link.',
            );
          }
          break;
        case _AuthMode.forgotPassword:
          await controller.sendPasswordReset(_emailCtrl.text);
          if (mounted) {
            showVaultSnackBar(
              context,
              'Password reset email sent. Note: your separate Master Password cannot be reset via email.',
            );
            setState(() => _mode = _AuthMode.login);
          }
          break;
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showVaultSnackBar(context, _friendlyFirebaseAuthError(e), isError: true);
      }
    } catch (e) {
      if (mounted) {
        showVaultSnackBar(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _submitting = true);
    try {
      await ref.read(vaultSessionProvider.notifier).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showVaultSnackBar(context, _friendlyFirebaseAuthError(e), isError: true);
      }
    } catch (e) {
      if (mounted) {
        showVaultSnackBar(context, 'Google sign-in failed.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (_mode) {
      _AuthMode.login => 'Sign In to VaultX',
      _AuthMode.register => 'Create Cloud Account',
      _AuthMode.forgotPassword => 'Reset Cloud Password',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/onboarding'),
        ),
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
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Firebase account authenticates cloud sync. Your separate Master Password encrypts your vault locally.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 24),
                if (_mode == _AuthMode.register) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: _mode == _AuthMode.forgotPassword
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || !v.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                if (_mode != _AuthMode.forgotPassword) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Account Login Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Minimum 8 characters required';
                      }
                      return null;
                    },
                  ),
                ],
                if (_mode == _AuthMode.login)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(
                                () => _mode = _AuthMode.forgotPassword,
                              ),
                      child: const Text('Forgot account password?'),
                    ),
                  )
                else
                  const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            switch (_mode) {
                              _AuthMode.login => 'Sign In',
                              _AuthMode.register => 'Create Account',
                              _AuthMode.forgotPassword => 'Send Reset Link',
                            },
                          ),
                  ),
                ),
                if (_mode != _AuthMode.forgotPassword) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.dividerColor)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or'),
                      ),
                      Expanded(child: Divider(color: theme.dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _signInGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _mode = _mode == _AuthMode.register
                                  ? _AuthMode.login
                                  : _AuthMode.register;
                            }),
                    child: Text(
                      _mode == _AuthMode.register
                          ? 'Already registered? Sign In'
                          : 'Need a VaultX account? Create one',
                    ),
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
