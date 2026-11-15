import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/constants/vault_constants.dart';
import '../../core/errors/vault_exceptions.dart';
import '../models/vault_models.dart';
import '../models/vault_record.dart';

class VaultInitializationResult {
  final SecretKey vaultKey;
  final String recoveryKey;
  final VaultMasterConfig configData;

  const VaultInitializationResult({
    required this.vaultKey,
    required this.recoveryKey,
    required this.configData,
  });
}

class MasterPasswordRotationResult {
  final String kdfAlgorithm;
  final int kdfMemoryKiB;
  final int kdfIterations;
  final int kdfParallelism;
  final String masterSalt;
  final String wrappedVaultKey;
  final String wrappedVaultKeyIv;
  final int keyVersion;
  final SecretKey vaultKey;

  const MasterPasswordRotationResult({
    required this.kdfAlgorithm,
    required this.kdfMemoryKiB,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.masterSalt,
    required this.wrappedVaultKey,
    required this.wrappedVaultKeyIv,
    required this.keyVersion,
    required this.vaultKey,
  });
}

class RecoveryKeyRotationResult {
  final String recoveryKey;
  final String recoverySalt;
  final String recoveryWrappedVaultKey;
  final String recoveryWrappedVaultKeyIv;
  final String recoveryKeyHint;

  const RecoveryKeyRotationResult({
    required this.recoveryKey,
    required this.recoverySalt,
    required this.recoveryWrappedVaultKey,
    required this.recoveryWrappedVaultKeyIv,
    required this.recoveryKeyHint,
  });
}

/// Zero-knowledge client-side cryptographic engine byte-compatible with src/lib/crypto.ts.
///
/// Specifications:
/// - KDF: Argon2id v1.3, 65536 KiB memory, 3 iterations, parallelism 1, 32-byte key.
/// - Cipher: AES-256-GCM with 12-byte random nonce and 16-byte authentication tag.
/// - Wire Format: `ciphertext` is standard padded Base64 of `cipherTextBytes || tagBytes`,
///   matching Web Crypto `SubtleCrypto.encrypt({ name: 'AES-GCM' })`.
class VaultCryptoService {
  final AesGcm _aesGcm = AesGcm.with256bits(
    nonceLength: VaultConstants.aesGcmNonceLengthBytes,
  );
  final Random _secureRandom = Random.secure();

  Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  void wipeBytes(List<int>? bytes) {
    if (bytes == null) return;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  /// Derives a 256-bit Key Encryption Key (KEK) from [secret] and [salt] using Argon2id.
  /// Offloads 64 MiB memory-hard hashing to a background Isolate by default.
  Future<SecretKey> deriveArgon2idKey(
    String secret,
    Uint8List salt, {
    KdfParams params = const KdfParams(),
    bool useIsolate = true,
  }) async {
    if (params.algorithm != VaultConstants.kdfAlgorithm) {
      throw UnsupportedError('Unsupported KDF algorithm: ${params.algorithm}');
    }

    final secretBytes = Uint8List.fromList(utf8.encode(secret));
    final saltCopy = Uint8List.fromList(salt);

    try {
      final derivedBytes = useIsolate
          ? await Isolate.run(
              () => _runArgon2idRaw(
                secretBytes: secretBytes,
                salt: saltCopy,
                memoryKiB: params.memoryKiB,
                iterations: params.iterations,
                parallelism: params.parallelism,
              ),
            )
          : await _runArgon2idRaw(
              secretBytes: secretBytes,
              salt: saltCopy,
              memoryKiB: params.memoryKiB,
              iterations: params.iterations,
              parallelism: params.parallelism,
            );

      try {
        return SecretKey(Uint8List.fromList(derivedBytes));
      } finally {
        wipeBytes(derivedBytes);
      }
    } finally {
      wipeBytes(secretBytes);
    }
  }

  static Future<Uint8List> _runArgon2idRaw({
    required Uint8List secretBytes,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
  }) async {
    final algorithm = Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: VaultConstants.derivedKeyLengthBytes,
    );

    final derivedKey = await algorithm.deriveKey(
      secretKey: SecretKey(secretBytes),
      nonce: salt,
    );
    final extracted = await derivedKey.extractBytes();
    return Uint8List.fromList(extracted);
  }

  /// Generates a 256-bit recovery key formatted identically to TypeScript `generateRecoveryKey()`.
  /// Output: `VX-XXXX-XXXX-...` (13 groups of 4 unambiguous Base32 chars).
  String generateRecoveryKey() {
    final randomBytes = generateRandomBytes(VaultConstants.recoveryKeyRawLength);
    try {
      final buffer = StringBuffer();
      for (var i = 0; i < VaultConstants.recoveryKeyRawLength; i++) {
        buffer.write(VaultConstants.recoveryKeyAlphabet[randomBytes[i] & 31]);
      }
      final raw = buffer.toString();
      final groups = <String>[];
      for (var i = 0; i < raw.length; i += 4) {
        groups.add(raw.substring(i, i + 4));
      }
      return 'VX-${groups.join('-')}';
    } finally {
      wipeBytes(randomBytes);
    }
  }

  /// Preserves the `VX` prefix and strips separators, matching TypeScript `normalizeRecoveryKey()`.
  String normalizeRecoveryKey(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String getRecoveryKeyHint(String recoveryKey) {
    final normalized = normalizeRecoveryKey(recoveryKey);
    if (normalized.length < 4) return '••••-$normalized';
    return '••••-${normalized.substring(normalized.length - 4)}';
  }

  Future<EncryptedPayloadPair> _wrapVaultKeyBytes(
    Uint8List vaultKeyBytes,
    SecretKey kek,
  ) async {
    final iv = generateRandomBytes(VaultConstants.aesGcmNonceLengthBytes);
    final secretBox = await _aesGcm.encrypt(
      vaultKeyBytes,
      secretKey: kek,
      nonce: iv,
    );
    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return EncryptedPayloadPair(
      ciphertext: base64Encode(combined),
      iv: base64Encode(iv),
    );
  }

  Future<Uint8List> _unwrapVaultKeyBytes(
    String wrappedBase64,
    String ivBase64,
    SecretKey kek,
  ) async {
    final combined = base64Decode(wrappedBase64);
    if (combined.length < VaultConstants.aesGcmTagLengthBytes) {
      throw const CiphertextTamperedException('Wrapped vault key payload too short.');
    }
    final iv = base64Decode(ivBase64);
    if (iv.length != VaultConstants.aesGcmNonceLengthBytes) {
      throw const CiphertextTamperedException('Invalid AES-GCM nonce length.');
    }

    final splitIndex = combined.length - VaultConstants.aesGcmTagLengthBytes;
    final cipherText = combined.sublist(0, splitIndex);
    final mac = Mac(combined.sublist(splitIndex));
    final secretBox = SecretBox(cipherText, nonce: iv, mac: mac);

    final decrypted = await _aesGcm.decrypt(secretBox, secretKey: kek);
    return Uint8List.fromList(decrypted);
  }

  Future<VaultInitializationResult> initializeVaultKeys(
    String masterPassword, {
    String userId = '',
    KdfParams kdfParams = const KdfParams(),
    bool useIsolate = true,
  }) async {
    final vaultKeyBytes = generateRandomBytes(VaultConstants.derivedKeyLengthBytes);
    final masterSalt = generateRandomBytes(VaultConstants.saltLengthBytes);
    final recoverySalt = generateRandomBytes(VaultConstants.saltLengthBytes);
    final recoveryKey = generateRecoveryKey();

    try {
      final masterKek = await deriveArgon2idKey(
        masterPassword,
        masterSalt,
        params: kdfParams,
        useIsolate: useIsolate,
      );
      final wrappedMaster = await _wrapVaultKeyBytes(vaultKeyBytes, masterKek);

      final recoveryKek = await deriveArgon2idKey(
        normalizeRecoveryKey(recoveryKey),
        recoverySalt,
        params: kdfParams,
        useIsolate: useIsolate,
      );
      final wrappedRecovery = await _wrapVaultKeyBytes(vaultKeyBytes, recoveryKek);

      final vaultKey = SecretKey(Uint8List.fromList(vaultKeyBytes));

      return VaultInitializationResult(
        vaultKey: vaultKey,
        recoveryKey: recoveryKey,
        configData: VaultMasterConfig(
          userId: userId,
          kdfAlgorithm: kdfParams.algorithm,
          kdfMemoryKiB: kdfParams.memoryKiB,
          kdfIterations: kdfParams.iterations,
          kdfParallelism: kdfParams.parallelism,
          masterSalt: base64Encode(masterSalt),
          wrappedVaultKey: wrappedMaster.ciphertext,
          wrappedVaultKeyIv: wrappedMaster.iv,
          recoverySalt: base64Encode(recoverySalt),
          recoveryWrappedVaultKey: wrappedRecovery.ciphertext,
          recoveryWrappedVaultKeyIv: wrappedRecovery.iv,
          recoveryKeyHint: getRecoveryKeyHint(recoveryKey),
          keyVersion: 1,
        ),
      );
    } finally {
      wipeBytes(vaultKeyBytes);
    }
  }

  Future<SecretKey> unlockVaultWithMasterPassword(
    String masterPassword,
    VaultMasterConfig config, {
    bool useIsolate = true,
  }) async {
    final salt = Uint8List.fromList(base64Decode(config.masterSalt));
    final kek = await deriveArgon2idKey(
      masterPassword,
      salt,
      params: config.kdfParams,
      useIsolate: useIsolate,
    );

    Uint8List? rawVaultKey;
    try {
      rawVaultKey = await _unwrapVaultKeyBytes(
        config.wrappedVaultKey,
        config.wrappedVaultKeyIv,
        kek,
      );
      return SecretKey(Uint8List.fromList(rawVaultKey));
    } catch (_) {
      throw const InvalidMasterPasswordException();
    } finally {
      wipeBytes(rawVaultKey);
    }
  }

  Future<SecretKey> unlockVaultWithRecoveryKey(
    String recoveryKeyInput,
    VaultMasterConfig config, {
    bool useIsolate = true,
  }) async {
    final normalized = normalizeRecoveryKey(recoveryKeyInput);
    if (normalized.length < VaultConstants.minNormalizedRecoveryKeyLength) {
      throw const InvalidRecoveryKeyException();
    }

    final salt = Uint8List.fromList(base64Decode(config.recoverySalt));
    final kek = await deriveArgon2idKey(
      normalized,
      salt,
      params: config.kdfParams,
      useIsolate: useIsolate,
    );

    Uint8List? rawVaultKey;
    try {
      rawVaultKey = await _unwrapVaultKeyBytes(
        config.recoveryWrappedVaultKey,
        config.recoveryWrappedVaultKeyIv,
        kek,
      );
      return SecretKey(Uint8List.fromList(rawVaultKey));
    } catch (_) {
      throw const InvalidRecoveryKeyException();
    } finally {
      wipeBytes(rawVaultKey);
    }
  }

  Future<MasterPasswordRotationResult> rotateMasterPasswordWrapper({
    String? currentMasterPassword,
    String? recoveryKey,
    required String newMasterPassword,
    required VaultMasterConfig config,
    bool useIsolate = true,
  }) async {
    final params = config.kdfParams;
    Uint8List? rawVaultKey;

    try {
      if (currentMasterPassword != null) {
        final oldKek = await deriveArgon2idKey(
          currentMasterPassword,
          Uint8List.fromList(base64Decode(config.masterSalt)),
          params: params,
          useIsolate: useIsolate,
        );
        try {
          rawVaultKey = await _unwrapVaultKeyBytes(
            config.wrappedVaultKey,
            config.wrappedVaultKeyIv,
            oldKek,
          );
        } catch (_) {
          throw const InvalidMasterPasswordException('Current master password is incorrect.');
        }
      } else if (recoveryKey != null) {
        final recoveryKek = await deriveArgon2idKey(
          normalizeRecoveryKey(recoveryKey),
          Uint8List.fromList(base64Decode(config.recoverySalt)),
          params: params,
          useIsolate: useIsolate,
        );
        try {
          rawVaultKey = await _unwrapVaultKeyBytes(
            config.recoveryWrappedVaultKey,
            config.recoveryWrappedVaultKeyIv,
            recoveryKek,
          );
        } catch (_) {
          throw const InvalidRecoveryKeyException();
        }
      } else {
        throw ArgumentError('Either currentMasterPassword or recoveryKey must be provided.');
      }

      final newSalt = generateRandomBytes(VaultConstants.saltLengthBytes);
      // Keep vault KDF parameters consistent with recoveryWrappedVaultKey on the same doc.
      final newKek = await deriveArgon2idKey(
        newMasterPassword,
        newSalt,
        params: params,
        useIsolate: useIsolate,
      );
      final wrapped = await _wrapVaultKeyBytes(rawVaultKey, newKek);
      final vaultKey = SecretKey(Uint8List.fromList(rawVaultKey));

      return MasterPasswordRotationResult(
        kdfAlgorithm: params.algorithm,
        kdfMemoryKiB: params.memoryKiB,
        kdfIterations: params.iterations,
        kdfParallelism: params.parallelism,
        masterSalt: base64Encode(newSalt),
        wrappedVaultKey: wrapped.ciphertext,
        wrappedVaultKeyIv: wrapped.iv,
        keyVersion: config.keyVersion + 1,
        vaultKey: vaultKey,
      );
    } finally {
      wipeBytes(rawVaultKey);
    }
  }

  Future<RecoveryKeyRotationResult> rotateRecoveryKeyWrapper(
    String currentMasterPassword,
    VaultMasterConfig config, {
    bool useIsolate = true,
  }) async {
    final params = config.kdfParams;
    final masterKek = await deriveArgon2idKey(
      currentMasterPassword,
      Uint8List.fromList(base64Decode(config.masterSalt)),
      params: params,
      useIsolate: useIsolate,
    );

    Uint8List? rawVaultKey;
    try {
      try {
        rawVaultKey = await _unwrapVaultKeyBytes(
          config.wrappedVaultKey,
          config.wrappedVaultKeyIv,
          masterKek,
        );
      } catch (_) {
        throw const InvalidMasterPasswordException('Master password verification failed.');
      }

      final newRecoveryKey = generateRecoveryKey();
      final newRecoverySalt = generateRandomBytes(VaultConstants.saltLengthBytes);
      final recoveryKek = await deriveArgon2idKey(
        normalizeRecoveryKey(newRecoveryKey),
        newRecoverySalt,
        params: params,
        useIsolate: useIsolate,
      );
      final wrapped = await _wrapVaultKeyBytes(rawVaultKey, recoveryKek);

      return RecoveryKeyRotationResult(
        recoveryKey: newRecoveryKey,
        recoverySalt: base64Encode(newRecoverySalt),
        recoveryWrappedVaultKey: wrapped.ciphertext,
        recoveryWrappedVaultKeyIv: wrapped.iv,
        recoveryKeyHint: getRecoveryKeyHint(newRecoveryKey),
      );
    } finally {
      wipeBytes(rawVaultKey);
    }
  }

  Future<EncryptedPayloadPair> encryptJsonMap(
    SecretKey key,
    Map<String, dynamic> payloadMap,
  ) async {
    final iv = generateRandomBytes(VaultConstants.aesGcmNonceLengthBytes);
    final plaintextBytes = Uint8List.fromList(utf8.encode(jsonEncode(payloadMap)));

    try {
      final secretBox = await _aesGcm.encrypt(
        plaintextBytes,
        secretKey: key,
        nonce: iv,
      );
      final combined = Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);
      return EncryptedPayloadPair(
        ciphertext: base64Encode(combined),
        iv: base64Encode(iv),
      );
    } finally {
      wipeBytes(plaintextBytes);
    }
  }

  Future<Map<String, dynamic>> decryptJsonMap(
    SecretKey key,
    String ciphertextBase64,
    String ivBase64,
  ) async {
    final Uint8List combined;
    final Uint8List iv;
    try {
      combined = Uint8List.fromList(base64Decode(ciphertextBase64));
      iv = Uint8List.fromList(base64Decode(ivBase64));
    } on FormatException {
      throw const CiphertextTamperedException('Malformed Base64 ciphertext or IV.');
    }

    if (combined.length < VaultConstants.aesGcmTagLengthBytes) {
      throw const CiphertextTamperedException('Encrypted payload too short.');
    }
    if (iv.length != VaultConstants.aesGcmNonceLengthBytes) {
      throw const CiphertextTamperedException('Invalid AES-GCM nonce length.');
    }

    final splitIndex = combined.length - VaultConstants.aesGcmTagLengthBytes;
    final cipherText = combined.sublist(0, splitIndex);
    final mac = Mac(combined.sublist(splitIndex));
    final secretBox = SecretBox(cipherText, nonce: iv, mac: mac);

    try {
      final decryptedBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      final jsonStr = utf8.decode(decryptedBytes);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const CiphertextTamperedException('Decrypted JSON is not an object.');
      }
      return decoded;
    } on SecretBoxAuthenticationError {
      throw const CiphertextTamperedException();
    } on FormatException {
      throw const CiphertextTamperedException('Decrypted payload is not valid UTF-8 JSON.');
    }
  }

  Future<EncryptedPayloadPair> encryptCredentialPayload(
    SecretKey vaultKey,
    CredentialPayload payload,
  ) =>
      encryptJsonMap(vaultKey, payload.toJson());

  Future<CredentialPayload> decryptCredentialPayload(
    SecretKey vaultKey,
    String ciphertextBase64,
    String ivBase64,
  ) async {
    final map = await decryptJsonMap(vaultKey, ciphertextBase64, ivBase64);
    return CredentialPayload.fromJson(map);
  }

  Future<EncryptedPayloadPair> encryptVaultRecordPayload(
    SecretKey vaultKey,
    VaultRecordPayload payload,
  ) =>
      encryptJsonMap(vaultKey, payload.toJson());

  Future<VaultRecordPayload> decryptVaultRecordPayload(
    SecretKey vaultKey,
    String ciphertextBase64,
    String ivBase64,
  ) async {
    final map = await decryptJsonMap(vaultKey, ciphertextBase64, ivBase64);
    return VaultRecordPayload.fromJson(map);
  }

  /// Exports the 32-byte DEK in Base64 strictly for passing to native Android Keystore
  /// biometric wrapping (`BiometricPrompt.CryptoObject`). Never log or persist raw Base64.
  Future<String> exportRawKeyBase64(SecretKey vaultKey) async {
    final bytes = Uint8List.fromList(await vaultKey.extractBytes());
    try {
      return base64Encode(bytes);
    } finally {
      wipeBytes(bytes);
    }
  }

  SecretKey importRawKeyBase64(String rawBase64) {
    final bytes = Uint8List.fromList(base64Decode(rawBase64));
    if (bytes.length != VaultConstants.derivedKeyLengthBytes) {
      wipeBytes(bytes);
      throw const CiphertextTamperedException('Invalid unwrapped vault key length.');
    }
    return SecretKey(bytes);
  }

  /// Generates a Firestore document ID matching `src/lib/vaultService.ts` (`cred_<32 hex chars>`).
  String generateCredentialId() {
    final bytes = generateRandomBytes(16);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'cred_$hex';
  }
}
