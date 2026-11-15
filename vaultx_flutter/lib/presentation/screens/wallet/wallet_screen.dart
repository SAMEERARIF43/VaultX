import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../domain/models/vault_record_type.dart';
import '../vault/record_detail_sheet.dart';
import '../vault/record_editor_sheet.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  VaultRecordType? _typeFilter;

  static const _walletTypes = [
    VaultRecordType.secureNote,
    VaultRecordType.wifi,
    VaultRecordType.paymentCard,
    VaultRecordType.identity,
    VaultRecordType.licenseKey,
    VaultRecordType.recoveryCodes,
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final theme = Theme.of(context);

    final walletRecords = state.decryptedRecords.where((rec) {
      if (!rec.recordType.isWalletRecord) return false;
      if (_typeFilter != null && rec.recordType != _typeFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All Wallet'),
                  selected: _typeFilter == null,
                  onSelected: (_) => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 8),
                ..._walletTypes.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: _typeFilter == t,
                      onSelected: (_) => setState(() => _typeFilter = t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: walletRecords.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 46,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Encrypted Digital Wallet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Store payment cards, Wi-Fi passwords, identity documents, license keys, and recovery codes under client-side AES-256-GCM.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
                    itemCount: walletRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rec = walletRecords[index];
                      final detailSummary = switch (rec.recordType) {
                        VaultRecordType.paymentCard =>
                          '${rec.payload.card?.brand ?? 'Card'} · ${rec.payload.card?.maskedLast4 ?? '••••'}',
                        VaultRecordType.wifi =>
                          'SSID: ${rec.payload.wifi?.ssid ?? rec.title}',
                        VaultRecordType.identity =>
                          '${rec.payload.identity?.documentType ?? 'ID'} · ${rec.payload.identity?.fullName ?? ''}',
                        VaultRecordType.licenseKey =>
                          rec.payload.license?.registeredTo ?? 'Licensed',
                        VaultRecordType.recoveryCodes =>
                          '${rec.payload.recoveryCodes?.codes.length ?? 0} recovery code(s)',
                        _ => 'Encrypted Private Note',
                      };

                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              rec.recordType.icon,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            rec.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('${rec.recordType.label} · $detailSummary'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showRecordDetailSheet(context, rec),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecordEditorSheet(
          context,
          initialType: _typeFilter ?? VaultRecordType.secureNote,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
    );
  }
}
