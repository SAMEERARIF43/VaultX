import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants/vault_constants.dart';
import '../../../domain/models/vault_record.dart';
import '../../../domain/models/vault_record_type.dart';
import '../../theme/vaultx_theme.dart';
import '../../widgets/vaultx_widgets.dart';
import 'record_detail_sheet.dart';
import 'record_editor_sheet.dart';

enum _VaultSort { recent, titleAsc, category }

class VaultListScreen extends ConsumerStatefulWidget {
  final String initialSearchQuery;

  const VaultListScreen({
    super.key,
    this.initialSearchQuery = '',
  });

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  late final TextEditingController _searchCtrl;
  String _selectedFilter = 'All';
  String? _selectedFolder;
  String? _selectedTag;
  _VaultSort _sort = _VaultSort.recent;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialSearchQuery);
  }

  @override
  void didUpdateWidget(covariant VaultListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery &&
        widget.initialSearchQuery.isNotEmpty) {
      _searchCtrl.text = widget.initialSearchQuery;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DecryptedVaultRecord> _applyFilters(
    List<DecryptedVaultRecord> all,
  ) {
    final q = _searchCtrl.text.trim().toLowerCase();

    final filtered = all.where((rec) {
      if (_selectedFilter == 'Favorites' && !rec.payload.isFavorite) {
        return false;
      } else if (_selectedFilter == 'Logins' &&
          rec.recordType != VaultRecordType.login &&
          rec.recordType != VaultRecordType.appLogin) {
        return false;
      } else if (_selectedFilter != 'All' &&
          _selectedFilter != 'Favorites' &&
          _selectedFilter != 'Logins' &&
          rec.category != _selectedFilter) {
        return false;
      }

      if (_selectedFolder != null && rec.payload.folder != _selectedFolder) {
        return false;
      }

      if (_selectedTag != null && !rec.payload.tags.contains(_selectedTag)) {
        return false;
      }

      if (q.isNotEmpty) {
        final inTitle = rec.title.toLowerCase().contains(q);
        final inUser = rec.username.toLowerCase().contains(q);
        final inUrl = rec.url.toLowerCase().contains(q);
        final inNotes = rec.notes.toLowerCase().contains(q);
        final inCategory = rec.category.toLowerCase().contains(q);
        final inFolder =
            (rec.payload.folder ?? '').toLowerCase().contains(q);
        final inTags = rec.payload.tags.any((t) => t.toLowerCase().contains(q));
        if (!inTitle &&
            !inUser &&
            !inUrl &&
            !inNotes &&
            !inCategory &&
            !inFolder &&
            !inTags) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (_sort) {
      case _VaultSort.recent:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _VaultSort.titleAsc:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _VaultSort.category:
        filtered.sort((a, b) {
          final c = a.category.compareTo(b.category);
          return c != 0
              ? c
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final controller = ref.read(vaultSessionProvider.notifier);
    final allRecords = state.decryptedRecords;
    final theme = Theme.of(context);

    // Track duplicate non-empty passwords locally to warn inline
    final pwCounts = <String, int>{};
    for (final rec in allRecords) {
      if (!rec.decryptionError && rec.password.isNotEmpty) {
        pwCounts[rec.password] = (pwCounts[rec.password] ?? 0) + 1;
      }
    }

    final folders = allRecords
        .map((r) => r.payload.folder)
        .whereType<String>()
        .where((f) => f.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final tags = allRecords
        .expand((r) => r.payload.tags)
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final filterOptions = <String>[
      'All',
      'Favorites',
      'Logins',
      ...VaultConstants.defaultCategories,
    ];

    final records = _applyFilters(allRecords);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search titles, domains, folders, tags...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_VaultSort>(
                  tooltip: 'Sort Records',
                  initialValue: _sort,
                  onSelected: (val) => setState(() => _sort = val),
                  icon: const Icon(Icons.sort_rounded),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: _VaultSort.recent,
                      child: Text('Recently Updated'),
                    ),
                    PopupMenuItem(
                      value: _VaultSort.titleAsc,
                      child: Text('Title (A–Z)'),
                    ),
                    PopupMenuItem(
                      value: _VaultSort.category,
                      child: Text('Category'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = filterOptions[index];
                final selected = _selectedFilter == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = option),
                );
              },
            ),
          ),
          if (folders.isNotEmpty || tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  if (folders.isNotEmpty)
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedFolder,
                        decoration: const InputDecoration(
                          labelText: 'Folder',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Folders'),
                          ),
                          ...folders.map(
                            (f) => DropdownMenuItem<String?>(
                              value: f,
                              child: Text(f, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedFolder = v),
                      ),
                    ),
                  if (folders.isNotEmpty && tags.isNotEmpty)
                    const SizedBox(width: 10),
                  if (tags.isNotEmpty)
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedTag,
                        decoration: const InputDecoration(
                          labelText: 'Tag',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Tags'),
                          ),
                          ...tags.map(
                            (t) => DropdownMenuItem<String?>(
                              value: t,
                              child: Text('#$t', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedTag = v),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_open_rounded,
                            size: 44,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.65),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            allRecords.isEmpty
                                ? 'No encrypted records yet'
                                : 'No matching records found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            allRecords.isEmpty
                                ? 'Tap + to store your first website login, 2FA secret, or wallet record.'
                                : 'Adjust your search query, category, or folder filters.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rec = records[index];
                      final isReused = (pwCounts[rec.password] ?? 0) > 1;
                      final hasTotp = rec.payload.totp != null;
                      final isRecentlyUsed = rec.payload.lastAccessedAt != null &&
                          DateTime.now()
                                  .difference(rec.payload.lastAccessedAt!)
                                  .inHours <
                              24;

                      final subtitleParts = <String>[];
                      if (rec.username.isNotEmpty) {
                        subtitleParts.add(rec.username);
                      } else if (rec.recordType == VaultRecordType.paymentCard &&
                          rec.payload.card != null) {
                        subtitleParts.add(
                          '${rec.payload.card!.brand} ${rec.payload.card!.maskedLast4}',
                        );
                      } else {
                        subtitleParts.add(rec.recordType.label);
                      }
                      subtitleParts.add(rec.category);
                      if (rec.payload.folder != null) {
                        subtitleParts.add(rec.payload.folder!);
                      }

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: rec.decryptionError
                                  ? VaultXColors.rose.withValues(alpha: 0.14)
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              rec.decryptionError
                                  ? Icons.error_outline_rounded
                                  : rec.recordType.icon,
                              color: rec.decryptionError
                                  ? VaultXColors.rose
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rec.title.isEmpty
                                      ? 'Untitled Record'
                                      : rec.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (rec.payload.isFavorite)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                              if (hasTotp)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              if (isReused)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Tooltip(
                                    message: 'Duplicate password detected',
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: VaultXColors.amber,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                subtitleParts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isRecentlyUsed)
                                Text(
                                  'Used recently',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: rec.password.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Copy Password',
                                  icon: const Icon(Icons.copy_rounded, size: 20),
                                  onPressed: () async {
                                    await controller.copySensitiveValue(
                                      rec.password,
                                      label: '${rec.title} password',
                                      isSensitive: true,
                                    );
                                    if (context.mounted) {
                                      showVaultSnackBar(
                                        context,
                                        'Password copied with auto-wipe timer.',
                                      );
                                    }
                                  },
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () => showRecordDetailSheet(context, rec),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecordEditorSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Record'),
      ),
    );
  }
}
