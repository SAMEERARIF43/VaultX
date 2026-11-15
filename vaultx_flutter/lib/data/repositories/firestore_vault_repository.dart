import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

import '../../core/constants/vault_constants.dart';
import '../../core/errors/vault_exceptions.dart';
import '../models/user_models.dart';
import '../models/vault_models.dart';
import '../models/vault_record.dart';
import '../../domain/services/crypto_service.dart';
import 'firestore_config.dart';

class UserVaultRemoteState {
  final UserProfile? profile;
  final VaultMasterConfig? masterConfig;
  final UserSecuritySettings? settings;

  const UserVaultRemoteState({
    required this.profile,
    required this.masterConfig,
    required this.settings,
  });
}

class FirestoreVaultRepository {
  final VaultCryptoService _crypto;
  final FirebaseFirestore? _injectedFirestore;

  FirestoreVaultRepository({
    VaultCryptoService? cryptoService,
    FirebaseFirestore? firestore,
  })  : _crypto = cryptoService ?? VaultCryptoService(),
        _injectedFirestore = firestore;

  FirebaseFirestore get _db {
    final db = _injectedFirestore ?? FirestoreConfig.db;
    FirestoreConfig.assertNamedDatabaseConfigured(db);
    return db;
  }

  DateTime _toDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    return DateTime.now();
  }

  Future<UserVaultRemoteState> fetchUserVaultState(String uid) async {
    final db = _db;
    UserProfile? profile;
    VaultMasterConfig? masterConfig;
    UserSecuritySettings? settings;

    try {
      final userSnap = await db.collection('users').doc(uid).get();
      if (userSnap.exists) {
        final data = userSnap.data()!;
        profile = UserProfile(
          uid: data['uid'] as String,
          email: data['email'] as String,
          displayName: data['displayName'] as String,
          vaultInitialized: data['vaultInitialized'] as bool? ?? false,
          createdAt: _toDate(data['createdAt']),
          updatedAt: _toDate(data['updatedAt']),
        );
      }
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'get',
        path: 'users/$uid',
        message: e.toString(),
      );
    }

    try {
      final masterSnap = await db
          .collection('users')
          .doc(uid)
          .collection('vaultConfig')
          .doc('master')
          .get();
      if (masterSnap.exists) {
        final d = masterSnap.data()!;
        masterConfig = VaultMasterConfig.fromMap({
          ...d,
          'userId': d['userId'] ?? uid,
        });
      }
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'get',
        path: 'users/$uid/vaultConfig/master',
        message: e.toString(),
      );
    }

    try {
      final settingsSnap = await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .get();
      if (settingsSnap.exists) {
        final s = settingsSnap.data()!;
        settings = UserSecuritySettings(
          userId: s['userId'] as String? ?? uid,
          autoLockMinutes: (s['autoLockMinutes'] as num?)?.toInt() ??
              VaultConstants.defaultAutoLockMinutes,
          clipboardClearSeconds:
              (s['clipboardClearSeconds'] as num?)?.toInt() ??
                  VaultConstants.defaultClipboardClearSeconds,
          requireReauthForReveal: s['requireReauthForReveal'] as bool? ?? false,
          updatedAt: _toDate(s['updatedAt']),
        );
      }
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'get',
        path: 'users/$uid/settings/preferences',
        message: e.toString(),
      );
    }

    return UserVaultRemoteState(
      profile: profile,
      masterConfig: masterConfig,
      settings: settings,
    );
  }

  Future<void> initializeVaultInFirestore({
    required String uid,
    required String email,
    required String displayName,
    required bool profileExists,
    required VaultMasterConfig configData,
  }) async {
    final db = _db;
    final rawName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : email.split('@').first;
    final cleanName = rawName.length > 100
        ? rawName.substring(0, 100)
        : (rawName.isEmpty ? 'Vault User' : rawName);
    final cleanEmail = email.trim().toLowerCase();
    final boundedEmail =
        cleanEmail.length > 254 ? cleanEmail.substring(0, 254) : cleanEmail;

    final batch = db.batch();
    final userRef = db.collection('users').doc(uid);
    final masterRef =
        db.collection('users').doc(uid).collection('vaultConfig').doc('master');
    final settingsRef =
        db.collection('users').doc(uid).collection('settings').doc('preferences');

    if (profileExists) {
      batch.update(userRef, {
        'displayName': cleanName,
        'vaultInitialized': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(userRef, {
        'uid': uid,
        'email': boundedEmail,
        'displayName': cleanName,
        'vaultInitialized': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(masterRef, {
      ...configData.toConfigMap(),
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(settingsRef, {
      'userId': uid,
      'autoLockMinutes': VaultConstants.defaultAutoLockMinutes,
      'clipboardClearSeconds': VaultConstants.defaultClipboardClearSeconds,
      'requireReauthForReveal': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'writeBatch',
        path: 'users/$uid/vaultConfig/master',
        message: e.toString(),
      );
    }
  }

  Stream<List<EncryptedVaultRecord>> watchEncryptedRecords(String uid) {
    final db = _db;
    // Matches firestore.rules allow list invariant: resource.data.userId == request.auth.uid
    return db
        .collection('users')
        .doc(uid)
        .collection('credentials')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs.map((docSnap) {
        final d = docSnap.data();
        return EncryptedVaultRecord(
          id: d['id'] as String? ?? docSnap.id,
          userId: d['userId'] as String? ?? uid,
          ciphertext: d['ciphertext'] as String,
          iv: d['iv'] as String,
          keyVersion: (d['keyVersion'] as num).toInt(),
          createdAt: _toDate(d['createdAt']),
          updatedAt: _toDate(d['updatedAt']),
        );
      }).toList();
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return records;
    });
  }

  Future<String> createEncryptedRecord({
    required String uid,
    required SecretKey vaultKey,
    required int keyVersion,
    required VaultRecordPayload payload,
    String? explicitCredentialId,
  }) async {
    final db = _db;
    final credentialId = explicitCredentialId ?? _crypto.generateCredentialId();
    final encrypted = await _crypto.encryptVaultRecordPayload(vaultKey, payload);

    if (encrypted.ciphertext.length > VaultConstants.maxCiphertextBase64Length) {
      throw ArgumentError(
        'Encrypted record exceeds Firestore 32 KB limit.',
      );
    }

    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('credentials')
          .doc(credentialId)
          .set({
        'id': credentialId,
        'userId': uid,
        'ciphertext': encrypted.ciphertext,
        'iv': encrypted.iv,
        'keyVersion': keyVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return credentialId;
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'create',
        path: 'users/$uid/credentials/$credentialId',
        message: e.toString(),
      );
    }
  }

  Future<void> updateEncryptedRecord({
    required String uid,
    required String credentialId,
    required SecretKey vaultKey,
    required int keyVersion,
    required VaultRecordPayload payload,
  }) async {
    final db = _db;
    final encrypted = await _crypto.encryptVaultRecordPayload(vaultKey, payload);

    if (encrypted.ciphertext.length > VaultConstants.maxCiphertextBase64Length) {
      throw ArgumentError(
        'Encrypted record exceeds Firestore 32 KB limit.',
      );
    }

    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('credentials')
          .doc(credentialId)
          .update({
        'ciphertext': encrypted.ciphertext,
        'iv': encrypted.iv,
        'keyVersion': keyVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'update',
        path: 'users/$uid/credentials/$credentialId',
        message: e.toString(),
      );
    }
  }

  Future<void> deleteEncryptedRecord({
    required String uid,
    required String credentialId,
  }) async {
    final db = _db;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('credentials')
          .doc(credentialId)
          .delete();
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'delete',
        path: 'users/$uid/credentials/$credentialId',
        message: e.toString(),
      );
    }
  }

  Future<void> updateSecuritySettings({
    required String uid,
    required int autoLockMinutes,
    required int clipboardClearSeconds,
    required bool requireReauthForReveal,
  }) async {
    final db = _db;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .update({
        'autoLockMinutes': autoLockMinutes.clamp(
          VaultConstants.minAutoLockMinutes,
          VaultConstants.maxAutoLockMinutes,
        ),
        'clipboardClearSeconds': clipboardClearSeconds.clamp(
          VaultConstants.minClipboardClearSeconds,
          VaultConstants.maxClipboardClearSeconds,
        ),
        'requireReauthForReveal': requireReauthForReveal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'update',
        path: 'users/$uid/settings/preferences',
        message: e.toString(),
      );
    }
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final clean = displayName.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }
    final bounded = clean.length > 100 ? clean.substring(0, 100) : clean;
    final db = _db;
    try {
      await db.collection('users').doc(uid).update({
        'displayName': bounded,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'update',
        path: 'users/$uid',
        message: e.toString(),
      );
    }
  }

  Future<void> updateMasterWrapper({
    required String uid,
    required MasterPasswordRotationResult rotation,
  }) async {
    final db = _db;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('vaultConfig')
          .doc('master')
          .update({
        'kdfAlgorithm': rotation.kdfAlgorithm,
        'kdfMemoryKiB': rotation.kdfMemoryKiB,
        'kdfIterations': rotation.kdfIterations,
        'kdfParallelism': rotation.kdfParallelism,
        'masterSalt': rotation.masterSalt,
        'wrappedVaultKey': rotation.wrappedVaultKey,
        'wrappedVaultKeyIv': rotation.wrappedVaultKeyIv,
        'keyVersion': rotation.keyVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'update',
        path: 'users/$uid/vaultConfig/master',
        message: e.toString(),
      );
    }
  }

  Future<void> updateRecoveryWrapper({
    required String uid,
    required RecoveryKeyRotationResult rotation,
  }) async {
    final db = _db;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('vaultConfig')
          .doc('master')
          .update({
        'recoverySalt': rotation.recoverySalt,
        'recoveryWrappedVaultKey': rotation.recoveryWrappedVaultKey,
        'recoveryWrappedVaultKeyIv': rotation.recoveryWrappedVaultKeyIv,
        'recoveryKeyHint': rotation.recoveryKeyHint,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreOperationException(
        operationType: 'update',
        path: 'users/$uid/vaultConfig/master',
        message: e.toString(),
      );
    }
  }
}
