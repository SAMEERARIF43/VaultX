import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/vault_session_state.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/master_setup_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/recovery_ceremony_screen.dart';
import '../screens/auth/vault_unlock_screen.dart';
import 'vaultx_shell.dart';

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<VaultSessionState>(
      vaultSessionProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final vaultXRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: notifier,
    redirect: (context, goState) {
      final s = ref.read(vaultSessionProvider);
      final loc = goState.matchedLocation;

      if (!s.authReady) {
        return loc == '/loading' ? null : '/loading';
      }

      if (!s.isSignedIn) {
        if (loc == '/onboarding' || loc == '/auth') return null;
        return '/onboarding';
      }

      if (!s.isEmailVerified) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      if (s.dataLoading && s.masterConfig == null) {
        return loc == '/loading' ? null : '/loading';
      }

      if (!s.isVaultInitialized) {
        return loc == '/master-setup' ? null : '/master-setup';
      }

      if (s.pendingRecoveryCeremonyKey != null) {
        return loc == '/recovery-ceremony' ? null : '/recovery-ceremony';
      }

      if (!s.isVaultUnlocked) {
        return loc == '/unlock' ? null : '/unlock';
      }

      return loc == '/vault' ? null : '/vault';
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'login';
          return AuthScreen(initialMode: mode);
        },
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/master-setup',
        builder: (context, state) => const MasterPasswordSetupScreen(),
      ),
      GoRoute(
        path: '/recovery-ceremony',
        builder: (context, state) {
          final key = ref.read(vaultSessionProvider).pendingRecoveryCeremonyKey ?? '';
          return RecoveryKeyCeremonyScreen(recoveryKey: key);
        },
      ),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const VaultUnlockScreen(),
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) => const VaultXShell(),
      ),
    ],
  );
});
