import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../screens/authenticator/authenticator_screen.dart';
import '../screens/autofill/autofill_screen.dart';
import '../screens/dashboard/home_dashboard_screen.dart';
import '../screens/generator/generator_screen.dart';
import '../screens/security/security_center_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/vault/vault_list_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../widgets/vaultx_widgets.dart';

class VaultXShell extends ConsumerStatefulWidget {
  const VaultXShell({super.key});

  @override
  ConsumerState<VaultXShell> createState() => _VaultXShellState();
}

class _VaultXShellState extends ConsumerState<VaultXShell>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  String _vaultSearchSeed = '';

  static const _titles = <int, String>{
    0: 'VaultX',
    1: 'Password Vault',
    2: 'Authenticator',
    3: 'Password Generator',
    4: 'Security Center',
    5: 'Android Autofill',
    6: 'Secure Wallet',
    7: 'Settings & Backups',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(vaultSessionProvider.notifier).onAppLifecycleChanged(state);
  }

  int _navBarIndexForTab(int tab) {
    return switch (tab) {
      0 => 0,
      1 => 1,
      2 => 2,
      4 => 3,
      _ => 4, // 3 (Generator), 5 (Autofill), 6 (Wallet), 7 (Settings)
    };
  }

  void _openToolsMenu() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Security Tools & Preferences',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Password Generator'),
                subtitle: const Text('CSPRNG passwords & passphrases'),
                selected: _tabIndex == 3,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _tabIndex = 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phonelink_lock_rounded),
                title: const Text('Android Autofill'),
                subtitle: const Text('System autofill & domain verification'),
                selected: _tabIndex == 5,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _tabIndex = 5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Secure Wallet'),
                subtitle: const Text('Cards, Wi-Fi, identity, notes & codes'),
                selected: _tabIndex == 6,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _tabIndex = 6);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings & Encrypted Backup'),
                subtitle: const Text('Biometrics, FLAG_SECURE, .vaultx export'),
                selected: _tabIndex == 7,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _tabIndex = 7);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_tabIndex) {
      0 => HomeDashboardScreen(
          onNavigateTab: (index) => setState(() => _tabIndex = index),
          onSearchVault: (query) => setState(() => _vaultSearchSeed = query),
        ),
      1 => VaultListScreen(initialSearchQuery: _vaultSearchSeed),
      2 => const AuthenticatorScreen(),
      3 => const GeneratorScreen(),
      4 => const SecurityCenterScreen(),
      5 => const AutofillScreen(),
      6 => const WalletScreen(),
      7 => const SettingsScreen(),
      _ => HomeDashboardScreen(
          onNavigateTab: (index) => setState(() => _tabIndex = index),
          onSearchVault: (query) => setState(() => _vaultSearchSeed = query),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final controller = ref.read(vaultSessionProvider.notifier);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => controller.onUserActivity(),
      child: Scaffold(
        appBar: _tabIndex == 0
            ? null
            : AppBar(
                title: Text(
                  _titles[_tabIndex] ?? 'VaultX',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: [
                  if (_tabIndex != 7)
                    IconButton(
                      tooltip: 'Settings & Backups',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => setState(() => _tabIndex = 7),
                    ),
                  IconButton(
                    tooltip: 'Lock Vault',
                    icon: const Icon(Icons.lock_outline_rounded),
                    onPressed: () => controller.lockVault(
                      reason: 'Vault locked manually.',
                    ),
                  ),
                ],
              ),
        body: SafeArea(
          top: _tabIndex == 0,
          bottom: false,
          child: Column(
            children: [
              ClipboardCountdownBanner(
                secondsLeft: state.clipboardSecondsLeft,
                label: state.lastCopiedLabel ?? 'Secret',
                onClearNow: () => controller.clearClipboardNow(),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navBarIndexForTab(_tabIndex),
          onDestinationSelected: (navIndex) {
            switch (navIndex) {
              case 0:
                setState(() => _tabIndex = 0);
              case 1:
                setState(() => _tabIndex = 1);
              case 2:
                setState(() => _tabIndex = 2);
              case 3:
                setState(() => _tabIndex = 4);
              case 4:
                _openToolsMenu();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded),
              label: 'Vault',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_2_outlined),
              selectedIcon: Icon(Icons.qr_code_2_rounded),
              label: '2FA',
            ),
            NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety_rounded),
              label: 'Security',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Tools',
            ),
          ],
        ),
      ),
    );
  }
}
