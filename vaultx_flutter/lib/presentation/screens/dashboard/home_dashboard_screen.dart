import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../domain/models/vault_record_type.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import '../vault/record_detail_sheet.dart';
import '../vault/record_editor_sheet.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<String> onSearchVault;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
    required this.onSearchVault,
  });

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final controller = ref.read(vaultSessionProvider.notifier);
    final report = controller.buildSecurityReport();
    final theme = Theme.of(context);

    final displayName =
        state.userProfile?.displayName ?? state.authUser?.displayName ?? 'Vault Owner';

    final alertCount = report.weakPasswords.length +
        report.reusedGroups.length +
        report.localCompromisedPasswords.length +
        report.externalBreachedPasswords.length;

    final recentAccessed = List.of(
      state.decryptedRecords.where((r) => !r.decryptionError),
    )..sort((a, b) {
        final aTime = a.payload.lastAccessedAt ?? a.updatedAt;
        final bTime = b.payload.lastAccessedAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });

    return RefreshIndicator(
      onRefresh: () => controller.refreshAutofillAndBiometricStatus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}, $displayName',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    SyncStatusIndicator(
                      syncState: state.syncState,
                      pendingCount: state.pendingOfflineMutationCount,
                      conflictCount: state.syncConflicts.length,
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Lock Vault',
                icon: const Icon(Icons.lock_outline_rounded),
                onPressed: () => controller.lockVault(
                  reason: 'Vault locked manually.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (q) {
              widget.onSearchVault(q);
              widget.onNavigateTab(1);
            },
            decoration: InputDecoration(
              hintText: 'Search encrypted logins, notes, cards...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () {
                  widget.onSearchVault(_searchCtrl.text);
                  widget.onNavigateTab(1);
                },
              ),
            ),
          ),

          if (state.syncConflicts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              color: VaultXColors.rose.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offline Sync Conflict Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: VaultXColors.rose,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.syncConflicts.first.reason,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => controller.resolveSyncConflict(
                            state.syncConflicts.first,
                            keepLocalVersion: true,
                          ),
                          child: const Text('Keep Local'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => controller.resolveSyncConflict(
                            state.syncConflicts.first,
                            keepLocalVersion: false,
                          ),
                          child: const Text('Use Cloud Version'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Primary Vault Security Score & Metrics Card (No plaintext exposed)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  theme.colorScheme.surface,
                ],
              ),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: report.healthPercentage / 100,
                        strokeWidth: 7,
                        backgroundColor: theme.dividerColor,
                        color: report.healthPercentage >= 80
                            ? VaultXColors.emerald
                            : (report.healthPercentage >= 55
                                ? VaultXColors.amber
                                : VaultXColors.rose),
                      ),
                      Text(
                        '${report.healthPercentage}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vault Security Score',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.totalVaultRecords} records · $alertCount alert(s)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => widget.onNavigateTab(4),
                        child: Text(
                          alertCount == 0
                              ? 'Open Security Center →'
                              : 'Review $alertCount security alert(s) →',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const VaultSectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.35,
            children: [
              _QuickActionTile(
                icon: Icons.add_circle_outline_rounded,
                label: 'Add Login',
                onTap: () => showRecordEditorSheet(context),
              ),
              _QuickActionTile(
                icon: Icons.password_rounded,
                label: 'Generate',
                onTap: () => widget.onNavigateTab(3),
              ),
              _QuickActionTile(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Authenticator',
                onTap: () => widget.onNavigateTab(2),
              ),
              _QuickActionTile(
                icon: Icons.wallet_outlined,
                label: 'Secure Wallet',
                onTap: () => widget.onNavigateTab(6),
              ),
            ],
          ),

          const SizedBox(height: 20),
          VaultSectionHeader(
            title: 'Recently Accessed',
            actionLabel: 'View Vault',
            onAction: () => widget.onNavigateTab(1),
          ),
          const SizedBox(height: 8),
          if (recentAccessed.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Your encrypted vault is empty.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => showRecordEditorSheet(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Credential'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentAccessed.take(5).map((rec) {
              // Dashboard preview never displays passwords or sensitive secrets.
              final subtitle = rec.recordType == VaultRecordType.paymentCard
                  ? '${rec.payload.card?.brand ?? 'Card'} · ${rec.payload.card?.maskedLast4 ?? '••••'}'
                  : (rec.username.isNotEmpty ? rec.username : rec.category);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(rec.recordType.icon),
                  title: Text(
                    rec.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$subtitle · ${rec.recordType.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showRecordDetailSheet(context, rec),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
