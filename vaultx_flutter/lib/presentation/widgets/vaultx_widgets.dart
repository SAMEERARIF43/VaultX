import 'package:flutter/material.dart';

import '../../domain/models/security_audit_models.dart';
import '../../domain/models/sharing_emergency_models.dart';
import '../theme/vaultx_theme.dart';

class VaultSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const VaultSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  final PasswordStrengthResult result;

  const PasswordStrengthMeter({super.key, required this.result});

  Color _colorForScore(int score) => switch (score) {
        4 => VaultXColors.emerald,
        3 => const Color(0xFF22C55E),
        2 => VaultXColors.amber,
        _ => VaultXColors.rose,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorForScore(result.score);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final filled = index < result.score || (result.score == 0 && index == 0 && result.entropyBits > 0);
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: filled ? color : theme.dividerColor,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${result.label} · ${result.entropyBits} bits',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              'Est. crack: ${result.crackTimeLabel}',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ClipboardCountdownBanner extends StatelessWidget {
  final int secondsLeft;
  final String label;
  final VoidCallback onClearNow;

  const ClipboardCountdownBanner({
    super.key,
    required this.secondsLeft,
    required this.label,
    required this.onClearNow,
  });

  @override
  Widget build(BuildContext context) {
    if (secondsLeft <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.content_paste_off_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label copied · auto-wiping in ${secondsLeft}s',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onClearNow,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class SyncStatusIndicator extends StatelessWidget {
  final OfflineSyncState syncState;
  final int pendingCount;
  final int conflictCount;
  final VoidCallback? onTapConflicts;

  const SyncStatusIndicator({
    super.key,
    required this.syncState,
    required this.pendingCount,
    required this.conflictCount,
    this.onTapConflicts,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (syncState) {
      OfflineSyncState.synced => (
          Icons.cloud_done_outlined,
          'Cloud Synced',
          VaultXColors.emerald,
        ),
      OfflineSyncState.syncing => (
          Icons.sync_rounded,
          'Syncing Vault',
          VaultXColors.sky,
        ),
      OfflineSyncState.offlineCached => (
          Icons.offline_pin_outlined,
          pendingCount > 0
              ? 'Offline · $pendingCount queued'
              : 'Encrypted Offline Cache',
          VaultXColors.amber,
        ),
      OfflineSyncState.conflictDetected => (
          Icons.warning_amber_rounded,
          '$conflictCount Sync Conflict(s)',
          VaultXColors.rose,
        ),
      OfflineSyncState.error => (
          Icons.cloud_off_rounded,
          'Sync Unavailable',
          VaultXColors.rose,
        ),
      OfflineSyncState.idle => (
          Icons.lock_outline_rounded,
          'Ready',
          VaultXColors.darkTextSecondary,
        ),
    };

    return InkWell(
      onTap: conflictCount > 0 ? onTapConflicts : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showVaultSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? VaultXColors.rose : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
