import 'dart:convert';
import 'dart:typed_data';

import '../../core/constants/vault_constants.dart';
import '../../core/errors/vault_exceptions.dart';
import '../models/vault_models.dart';
import '../models/vault_record.dart';
import 'crypto_service.dart';

class BackupRecordEntry {
  final String id;
  final int keyVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VaultRecordPayload payload;

  const BackupRecordEntry({
    required this.id,
    required this.keyVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.payload,
  });

  factory BackupRecordEntry.fromJson(Map<String, dynamic> json) =>
      BackupRecordEntry(
        id: json['id'] as String,
        keyVersion: (json['keyVersion'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        payload:
            VaultRecordPayload.fromJson(json['payload'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyVersion': keyVersion,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'payload': payload.toJson(),
      };
}

class EncryptedBackupRestoreResult {
  final DateTime exportedAt;
  final int recordCount;
  final List<BackupRecordEntry> entries;

  const EncryptedBackupRestoreResult({
    required this.exportedAt,
    required this.recordCount,
    required this.entries,
  });
}

/// Encrypted portable vault backup service (`VaultXBackup-v1`).
/// Uses Argon2id (64 MiB, 3 iterations, parallelism 1) + AES-256-GCM (12-byte nonce, 16-byte tag).
class BackupService {
  final VaultCryptoService _crypto;

  BackupService({VaultCryptoService? cryptoService})
      : _crypto = cryptoService ?? VaultCryptoService();

  Future<String> exportEncryptedBackupJson({
    required List<DecryptedVaultRecord> records,
    required String backupPassphrase,
    KdfParams kdfParams = const KdfParams(),
    bool useIsolate = true,
  }) async {
    if (backupPassphrase.length < 8) {
      throw ArgumentError('Backup passphrase must be at least 8 characters.');
    }

    final validRecords = records.where((r) => !r.decryptionError).toList();
    final salt = _crypto.generateRandomBytes(VaultConstants.saltLengthBytes);
    final key = await _crypto.deriveArgon2idKey(
      backupPassphrase,
      salt,
      params: kdfParams,
      useIsolate: useIsolate,
    );

    final exportedAt = DateTime.now().toUtc();
    final innerPayload = {
      'exportedAtIso': exportedAt.toIso8601String(),
      'records': validRecords
          .map(
            (r) => BackupRecordEntry(
              id: r.id,
              keyVersion: r.keyVersion,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
              payload: r.payload,
            ).toJson(),
          )
          .toList(),
    };

    final encrypted = await _crypto.encryptJsonMap(key, innerPayload);

    final envelope = {
      'formatVersion': VaultConstants.backupFormatVersion,
      'exportedAtIso': exportedAt.toIso8601String(),
      'recordCount': validRecords.length,
      'kdf': kdfParams.toJson(),
      'salt': base64Encode(salt),
      'ciphertext': encrypted.ciphertext,
      'iv': encrypted.iv,
    };

    return '${const JsonEncoder.withIndent('  ').convert(envelope)}\n';
  }

  Future<EncryptedBackupRestoreResult> decryptBackupJson({
    required String rawJson,
    required String backupPassphrase,
    bool useIsolate = true,
  }) async {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(rawJson) as Map<String, dynamic>;
    } on FormatException {
      throw const CiphertextTamperedException('Backup file is not valid JSON.');
    }

    if (envelope['formatVersion'] != VaultConstants.backupFormatVersion) {
      throw const CiphertextTamperedException(
        'Unsupported encrypted backup format version.',
      );
    }

    final kdf = KdfParams.fromJson(envelope['kdf'] as Map<String, dynamic>);
    final salt = Uint8List.fromList(base64Decode(envelope['salt'] as String));
    final ciphertext = envelope['ciphertext'] as String;
    final iv = envelope['iv'] as String;

    final key = await _crypto.deriveArgon2idKey(
      backupPassphrase,
      salt,
      params: kdf,
      useIsolate: useIsolate,
    );

    final Map<String, dynamic> inner;
    try {
      inner = await _crypto.decryptJsonMap(key, ciphertext, iv);
    } on CiphertextTamperedException {
      throw const InvalidMasterPasswordException(
        'Incorrect backup passphrase or corrupted backup file.',
      );
    }

    final exportedAt =
        DateTime.tryParse(inner['exportedAtIso'] as String? ?? '') ??
            DateTime.now();
    final entries = (inner['records'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BackupRecordEntry.fromJson)
        .toList();

    return EncryptedBackupRestoreResult(
      exportedAt: exportedAt,
      recordCount: entries.length,
      entries: entries,
    );
  }
}
