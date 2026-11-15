import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/vaultx_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.verified_user_rounded,
      title: 'Zero-Knowledge By Design',
      body:
          'Every password, note, card, and 2FA secret is derived with Argon2id (64 MiB) and encrypted on your device with AES-256-GCM before leaving your phone.',
    ),
    (
      icon: Icons.fingerprint_rounded,
      title: 'Biometric Autofill Across Android',
      body:
          'Verify once with Android BiometricPrompt hardware security to autofill credentials strictly into matching websites and apps.',
    ),
    (
      icon: Icons.qr_code_2_rounded,
      title: '2FA Authenticator & Health Audit',
      body:
          'Generate time-based 6-digit codes, monitor weak or reused credentials, and run privacy-preserving k-anonymity breach checks locally.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'VaultX',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                VaultXColors.emerald.withValues(alpha: 0.22),
                                VaultXColors.sky.withValues(alpha: 0.12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: VaultXColors.emerald.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 46,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.78),
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final active = index == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: active
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_page < _slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      context.go('/auth?mode=register');
                    }
                  },
                  child: Text(
                    _page < _slides.length - 1 ? 'Continue' : 'Create VaultX Account',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/auth?mode=login'),
                  child: const Text('I Already Have an Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
