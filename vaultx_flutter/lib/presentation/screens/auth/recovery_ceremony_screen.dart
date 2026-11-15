import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';

class RecoveryKeyCeremonyScreen extends ConsumerStatefulWidget {
  final String recoveryKey;

  const RecoveryKeyCeremonyScreen({super.key, required this.recoveryKey});

  @override
  ConsumerState<RecoveryKeyCeremonyScreen> createState() =>
      _RecoveryKeyCeremonyScreenState();
}

class _RecoveryKeyCeremonyScreenState
    extends ConsumerState<RecoveryKeyCeremonyScreen> {
  bool _confirmedSaved = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VaultXColors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: VaultXColors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: VaultXColors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Save this 256-bit Recovery Key offline. VaultX cannot recover your vault if you lose both your Master Password and Recovery Key.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Emergency Recovery Key',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        widget.recoveryKey,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(vaultSessionProvider.notifier)
                                .copySensitiveValue(
                                  widget.recoveryKey,
                                  label: 'Recovery Key',
                                  isSensitive: true,
                                );
                            if (context.mounted) {
                              showVaultSnackBar(
                                context,
                                'Recovery Key copied securely. Store it offline and clear clipboard.',
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy Recovery Key'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _confirmedSaved,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _confirmedSaved = v ?? false),
                title: const Text(
                  'I have written down or stored my Recovery Key safely offline.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirmedSaved
                      ? () => ref
                          .read(vaultSessionProvider.notifier)
                          .acknowledgeRecoveryCeremony()
                      : null,
                  child: const Text('Enter My Encrypted Vault'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
