import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../widgets/vaultx_widgets.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _busy = false;

  Future<void> _checkStatus() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(vaultSessionProvider.notifier)
          .refreshEmailVerification();
      final verified = ref.read(vaultSessionProvider).isEmailVerified;
      if (!verified && mounted) {
        showVaultSnackBar(
          context,
          'Email not verified yet. Open the verification link in your inbox first.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await ref.read(vaultSessionProvider.notifier).sendVerificationEmail();
      if (mounted) {
        showVaultSnackBar(context, 'Verification email re-sent.');
      }
    } catch (e) {
      if (mounted) {
        showVaultSnackBar(context, 'Unable to send email right now.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final email = state.authUser?.email ?? 'your email';
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'VaultX Firestore security rules strictly block cloud vault reads and writes until $email is verified.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _checkStatus,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I Verified My Email'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _resend,
                  child: const Text('Resend Verification Link'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(vaultSessionProvider.notifier).signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
