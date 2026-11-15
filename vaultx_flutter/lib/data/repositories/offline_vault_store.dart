import 'dart:convert';

import '../../platform/android_security_channel.dart';
import '../models/sharing_emergency_models.dart';
import '../models/user_models.dart';
import '../models/vault_models.dart';
import '../models/vault_record.dart';

/// Abstraction allowing hardware-Keystore wrapping on Android and pure-Dart
/// encrypted/in-memory delegates during headless unit tests.
abstract class OfflineBlobStorageDelegate {
  Future<void> writeProtected(String key, String rawJson);
  Future<String?> readProtected(String key);
  Future<void> deleteProtected(String key);
}

class AndroidKeystoreBlobStorage implements OfflineBlobStorageDelegate {
  final AndroidSecurityChannel _channel;

  AndroidKeystoreBlobStorage(this._channel);

  @override
  Future<void> writeProtected(String key, String rawJson) =>
      _channel.protectOfflineBlob(key, rawJson);

  @override
  Future<String?> readProtected(String key) =>
      _channel.unprotectOfflineBlob(key);

  @override
  Future<void> deleteProtected(String key) => _channel.clearOfflineBlob(key);
}

class OfflineVaultSnapshot {
  final String uid;
  final VaultMasterConfig? masterConfig;
  final List<EncryptedVaultRecord> encryptedRecords;
  final List<PendingOfflineMutation> pendingMutations;
  final DateTime syncedAt;

  const OfflineVaultSnapshot({
    required this.uid,
    required this.masterConfig,
    required this.encryptedRecords,
    this.pendingMutations = const [],
    required this.syncedAt,
  });

  factory OfflineVaultSnapshot.fromJson(Map<String, dynamic> json) =>
      OfflineVaultSnapshot(
        uid: json['uid'] as String? ?? '',
        masterConfig: json['masterConfig'] is Map<String, dynamic>
            ? VaultMasterConfig.fromMap(
                json['masterConfig'] as Map<String, dynamic>,
              )
            : null,
        encryptedRecords: (json['encryptedRecords'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EncryptedVaultRecord.fromJson)
            .toList(),
        pendingMutations: (json['pendingMutations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PendingOfflineMutation.fromJson)
            .toList(),
        syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        if (masterConfig != null) 'masterConfig': masterConfig!.toConfigMap(),
        'encryptedRecords': encryptedRecords.map((e) => e.toJson()).toList(),
        'pendingMutations': pendingMutations.map((e) => e.toJson()).toList(),
        'syncedAt': syncedAt.toIso8601String(),
      };
}

enum PendingMutationType { create, update, delete }

class PendingOfflineMutation {
  final String credentialId;
  final PendingMutationType type;
  final EncryptedVaultRecord? encryptedRecord;
  final DateTime baseRemoteUpdatedAt;
  final DateTime queuedAt;

  const PendingOfflineMutation({
    required this.credentialId,
    required this.type,
    this.encryptedRecord,
    required this.baseRemoteUpdatedAt,
    required this.queuedAt,
  });

  factory PendingOfflineMutation.fromJson(Map<String, dynamic> json) =>
      PendingOfflineMutation(
        credentialId: json['credentialId'] as String,
        type: PendingMutationType.values.firstWhere(
          (e) => e.name == (json['type'] as String?),
          orElse: () => PendingMutationType.update,
        ),
        encryptedRecord: json['encryptedRecord'] is Map<String, dynamic>
            ? EncryptedVaultRecord.fromJson(
                json['encryptedRecord'] as Map<String, dynamic>,
              )
            : null,
        baseRemoteUpdatedAt:
            DateTime.tryParse(json['baseRemoteUpdatedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        queuedAt: DateTime.tryParse(json['queuedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'credentialId': credentialId,
        'type': type.name,
        if (encryptedRecord != null)
          'encryptedRecord': encryptedRecord!.toJson(),
        'baseRemoteUpdatedAt': baseRemoteUpdatedAt.toIso8601String(),
        'queuedAt': queuedAt.toIso8601String(),
      };
}

/// Manages strictly encrypted local persistence:
/// - Vault snapshot stores ONLY AES-256-GCM ciphertext records wrapped inside
///   an Android Keystore-protected blob (never plaintext secrets).
/// - Detects remote vs. pending-offline timestamp conflicts rather than
///   silently overwriting newer cloud records.
class OfflineVaultStore {
  final OfflineBlobStorageDelegate _delegate;

  OfflineVaultStore(this._delegate);

  String _snapshotKey(String uid) => 'vault_snapshot_$uid';
  String _prefsKey(String uid) => 'device_prefs_$uid';
  String _shareLedgerKey(String uid) => 'share_ledger_$uid';
  String _emergencyKey(String uid) => 'emergency_cfg_$uid';

  Future<void> saveSnapshot(OfflineVaultSnapshot snapshot) async {
    await _delegate.writeProtected(
      _snapshotKey(snapshot.uid),
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<OfflineVaultSnapshot?> loadSnapshot(String uid) async {
    final raw = await _delegate.readProtected(_snapshotKey(uid));
    if (raw == null || raw.isEmpty) return null;
    try {
      return OfflineVaultSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocalPrefs(String uid, LocalDevicePreferences prefs) async {
    await _delegate.writeProtected(_prefsKey(uid), jsonEncode(prefs.toJson()));
  }

  Future<LocalDevicePreferences> loadLocalPrefs(String uid) async {
    final raw = await _delegate.readProtected(_prefsKey(uid));
    if (raw == null || raw.isEmpty) return const LocalDevicePreferences();
    try {
      return LocalDevicePreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const LocalDevicePreferences();
    }
  }

  Future<void> saveShareLedger(String uid, List<ShareLedgerEntry> entries) async {
    await _delegate.writeProtected(
      _shareLedgerKey(uid),
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<ShareLedgerEntry>> loadShareLedger(String uid) async {
    final raw = await _delegate.readProtected(_shareLedgerKey(uid));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ShareLedgerEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveEmergencyConfig(
    String uid,
    EmergencyContactConfig config,
  ) async {
    await _delegate.writeProtected(
      _emergencyKey(uid),
      jsonEncode(config.toJson()),
    );
  }

  Future<EmergencyContactConfig> loadEmergencyConfig(String uid) async {
    final raw = await _delegate.readProtected(_emergencyKey(uid));
    if (raw == null || raw.isEmpty) return const EmergencyContactConfig();
    try {
      return EmergencyContactConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const EmergencyContactConfig();
    }
  }

  Future<void> clearAllForUser(String uid) async {
    await _delegate.deleteProtected(_snapshotKey(uid));
    await _delegate.deleteProtected(_shareLedgerKey(uid));
    await _delegate.deleteProtected(_emergencyKey(uid));
  }

  /// Evaluates pending offline edits against incoming remote Firestore records
  /// to prevent silent overwriting of newer remote vault data.
  List<SyncConflictItem> detectConflicts({
    required List<PendingOfflineMutation> pending,
    required List<EncryptedVaultRecord> remoteRecords,
  }) {
    final remoteMap = {for (final r in remoteRecords) r.id: r};
    final conflicts = <SyncConflictItem>[];

    for (final mutation in pending) {
      final remote = remoteMap[mutation.credentialId];
      if (mutation.type == PendingMutationType.update &&
          remote != null &&
          mutation.encryptedRecord != null) {
        // Remote updated AFTER the local edit's base timestamp
        if (remote.updatedAt.isAfter(mutation.baseRemoteUpdatedAt)) {
          conflicts.add(
            SyncConflictItem(
              recordId: mutation.credentialId,
              localRecord: mutation.encryptedRecord!,
              remoteRecord: remote,
              reason:
                  'Cloud record was updated at ${remote.updatedAt.toIso8601String()} after offline edit started.',
            ),
          );
        }
      }
    }

    return conflicts;
  }
}
