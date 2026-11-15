import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../domain/models/security_audit_models.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import '../vault/record_editor_sheet.dart';

class SecurityCenterScreen extends ConsumerWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultSessionProvider);
    final controller = ref.read(vaultSessionProvider.notifier);
    final report = controller.buildSecurityReport();
    final theme = Theme.of(context);

    return ListView(
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
                    Text(
                      '${report.healthPercentage}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: report.healthPercentage >= 80
                            ? VaultXColors.emerald
                            : (report.healthPercentage >= 55
                                ? VaultXColors.amber
                                : VaultXColors.rose),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vault Security Health',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${report.totalPasswordAccounts} password accounts audited locally',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MetricBox(
                      label: 'Weak',
                      value: report.weakPasswords.length.toString(),
                      color: VaultXColors.amber,
                    ),
                    const SizedBox(width: 8),
                    _MetricBox(
                      label: 'Reused',
                      value: report.reusedCount.toString(),
                      color: VaultXColors.rose,
                    ),
                    const SizedBox(width: 8),
                    _MetricBox(
                      label: 'Old >180d',
                      value: report.oldPasswords.length.toString(),
                      color: VaultXColors.sky,
                    ),
                    const SizedBox(width: 8),
                    _MetricBox(
                      label: 'Breached',
                      value: report.externalBreachedPasswords.length.toString(),
                      color: VaultXColors.rose,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy-Preserving Breach Check (K-Anonymity)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Computes SHA-1 locally on device and queries HaveIBeenPwned using ONLY the first 5 hex characters (k-anonymity). Plaintext passwords never leave your phone.',
                  style: theme.textTheme.bodySmall,
                ),
                if (report.lastExternalBreachScanAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Last verified scan: ${report.lastExternalBreachScanAt!.toLocal().toString().split('.').first}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.isRunningBreachScan
                        ? null
                        : () async {
                            try {
                              await controller.runExternalBreachScan();
                              if (context.mounted) {
                                showVaultSnackBar(
                                  context,
                                  'K-anonymity breach check completed.',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showVaultSnackBar(
                                  context,
                                  e.toString(),
                                  isError: true,
                                );
                              }
                            }
                          },
                    icon: state.isRunningBreachScan
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar_rounded),
                    label: Text(
                      state.isRunningBreachScan
                          ? 'Checking 5-Char SHA-1 Prefixes...'
                          : 'Run K-Anonymity Breach Scan',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (report.externalBreachedPasswords.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(
            title: 'Externally Verified Breaches (HIBP K-Anonymity)',
          ),
          const SizedBox(height: 8),
          ...report.externalBreachedPasswords.map(
            (item) => _IssueCard(item: item, color: VaultXColors.rose),
          ),
        ],

        if (report.localCompromisedPasswords.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(
            title: 'Local Heuristic Risks (Offline Corpus / Username Reuse)',
          ),
          const SizedBox(height: 8),
          ...report.localCompromisedPasswords.map(
            (item) => _IssueCard(item: item, color: VaultXColors.rose),
          ),
        ],

        if (report.reusedGroups.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(title: 'Reused Password Groups'),
          const SizedBox(height: 8),
          ...report.reusedGroups.map(
            (group) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: const Icon(
                  Icons.copy_all_rounded,
                  color: VaultXColors.rose,
                ),
                title: Text(
                  '${group.count} accounts share the same password',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: group.records
                    .map(
                      (rec) => ListTile(
                        title: Text(rec.title),
                        subtitle: Text(rec.username),
                        trailing: TextButton(
                          onPressed: () =>
                              showRecordEditorSheet(context, existing: rec),
                          child: const Text('Rotate'),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],

        if (report.weakPasswords.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(title: 'Weak Passwords'),
          const SizedBox(height: 8),
          ...report.weakPasswords.map(
            (item) => _IssueCard(item: item, color: VaultXColors.amber),
          ),
        ],

        if (report.expiringOrExpiredPasswords.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(title: 'Expiration Reminders'),
          const SizedBox(height: 8),
          ...report.expiringOrExpiredPasswords.map(
            (item) => _IssueCard(item: item, color: VaultXColors.amber),
          ),
        ],

        if (report.oldPasswords.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(title: 'Passwords Older Than 180 Days'),
          const SizedBox(height: 8),
          ...report.oldPasswords.map(
            (item) => _IssueCard(item: item, color: VaultXColors.sky),
          ),
        ],

        if (report.missingInfoAccounts.isNotEmpty) ...[
          const SizedBox(height: 20),
          const VaultSectionHeader(title: 'Missing URL / Username Metadata'),
          const SizedBox(height: 8),
          ...report.missingInfoAccounts.map(
            (item) => _IssueCard(item: item, color: VaultXColors.sky),
          ),
        ],

        if (report.weakPasswords.isEmpty &&
            report.reusedGroups.isEmpty &&
            report.localCompromisedPasswords.isEmpty &&
            report.externalBreachedPasswords.isEmpty) ...[
          const SizedBox(height: 20),
          Card(
            color: VaultXColors.emerald.withValues(alpha: 0.1),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, color: VaultXColors.emerald),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No critical weak, reused, or breached credentials detected.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final SecurityIssueItem item;
  final Color color;

  const _IssueCard({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.shield_outlined, color: color),
        title: Text(
          item.record.title.isEmpty ? 'Untitled' : item.record.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${item.reason}\n${item.recommendation}'),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () =>
              showRecordEditorSheet(context, existing: item.record),
          child: const Text('Fix'),
        ),
      ),
    );
  }
}
