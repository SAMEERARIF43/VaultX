import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/constants/vault_constants.dart';
import '../../core/errors/vault_exceptions.dart';
import '../models/sharing_emergency_models.dart';
import '../models/vault_models.dart';
import '../models/vault_record.dart';
import 'crypto_service.dart';

class SealedShareResult {
  final EphemeralSharePackage package;
  final String encodedEnvelope;
  final String shareKeyBase64Url;

  const SealedShareResult({
    required this.package,
    required this.encodedEnvelope,
    required this.shareKeyBase64Url,
  });
}

/// Zero-knowledge foundations for:
/// 1. End-to-end encrypted ephemeral credential share packages (`VaultX-Share-v1`)
///    where only explicitly selected records are encrypted with a fresh 256-bit key
///    and optional recipient passcode (never stored in plaintext on any server).
/// 2. Emergency contact configuration, waiting-period enforcement, and encrypted
///    Emergency Recovery Bundle generation.
class SharingEmergencyService {
  final VaultCryptoService _crypto;

  SharingEmergencyService({VaultCryptoService? cryptoService})
      : _crypto = cryptoService ?? VaultCryptoService();

  Future<SealedShareResult> createEphemeralShare({
    required DecryptedVaultRecord record,
    required Duration expiresIn,
    String? optionalPasscode,
    bool useIsolate = true,
  }) async {
    final shareIdBytes = _crypto.generateRandomBytes(12);
    final shareId = base64UrlEncode(shareIdBytes).replaceAll('=', '');

    final rawShareKey = _crypto.generateRandomBytes(32);
    final shareKeyBase64Url = base64UrlEncode(rawShareKey).replaceAll('=', '');

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(expiresIn);

    final SecretKey encryptionKey;
    String? passcodeSaltBase64;
    final hasPasscode =
        optionalPasscode != null && optionalPasscode.trim().isNotEmpty;

    if (hasPasscode) {
      final salt = _crypto.generateRandomBytes(VaultConstants.saltLengthBytes);
      passcodeSaltBase64 = base64Encode(salt);
      // Combine share key + user passcode so BOTH the link/envelope key AND
      // out-of-band passcode are required.
      encryptionKey = await _crypto.deriveArgon2idKey(
        '$shareKeyBase64Url::${optionalPasscode.trim()}',
        salt,
        params: const KdfParams(),
        useIsolate: useIsolate,
      );
    } else {
      encryptionKey = SecretKey(Uint8List.fromList(rawShareKey));
    }

    final payloadJson = {
      'shareId': shareId,
      'expiresAtIso': expiresAt.toIso8601String(),
      'recordTitle': record.title,
      'recordType': record.recordType.wireValue,
      'payload': record.payload.toJson(),
    };

    final encrypted = await _crypto.encryptJsonMap(encryptionKey, payloadJson);
    _crypto.wipeBytes(rawShareKey);

    final package = EphemeralSharePackage(
      formatVersion: VaultConstants.shareFormatVersion,
      shareId: shareId,
      createdAtIso: now.toIso8601String(),
      expiresAtIso: expiresAt.toIso8601String(),
      requiresPasscode: hasPasscode,
      passcodeSaltBase64: passcodeSaltBase64,
      ciphertextBase64: encrypted.ciphertext,
      ivBase64: encrypted.iv,
    );

    final encodedEnvelope = jsonEncode(package.toJson());
    return SealedShareResult(
      package: package,
      encodedEnvelope: encodedEnvelope,
      shareKeyBase64Url: shareKeyBase64Url,
    );
  }

  Future<VaultRecordPayload> openEphemeralShare({
    required String encodedEnvelope,
    required String shareKeyBase64Url,
    String? passcode,
    bool useIsolate = true,
  }) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(encodedEnvelope) as Map<String, dynamic>;
    } on FormatException {
      throw const CiphertextTamperedException('Invalid VaultX share envelope.');
    }

    final package = EphemeralSharePackage.fromJson(map);
    if (package.formatVersion != VaultConstants.shareFormatVersion) {
      throw const CiphertextTamperedException('Unsupported share version.');
    }
    if (package.isExpired) {
      throw const CiphertextTamperedException('This shared item has expired.');
    }

    final normalizedKey = shareKeyBase64Url.trim();
    final paddedLength = (normalizedKey.length + 3) & ~3;
    final paddedKey = normalizedKey.padRight(paddedLength, '=');

    final SecretKey decryptionKey;
    if (package.requiresPasscode) {
      if (passcode == null || passcode.trim().isEmpty) {
        throw const InvalidMasterPasswordException(
          'Recipient passcode required to open this shared item.',
        );
      }
      final salt = Uint8List.fromList(
        base64Decode(package.passcodeSaltBase64 ?? ''),
      );
      decryptionKey = await _crypto.deriveArgon2idKey(
        '$normalizedKey::${passcode.trim()}',
        salt,
        params: const KdfParams(),
        useIsolate: useIsolate,
      );
    } else {
      decryptionKey = SecretKey(Uint8List.fromList(base64Url.decode(paddedKey)));
    }

    final decrypted = await _crypto.decryptJsonMap(
      decryptionKey,
      package.ciphertextBase64,
      package.ivBase64,
    );

    final expiresAt =
        DateTime.tryParse(decrypted['expiresAtIso'] as String? ?? '');
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw const CiphertextTamperedException('This shared item has expired.');
    }

    return VaultRecordPayload.fromJson(
      decrypted['payload'] as Map<String, dynamic>,
    );
  }

  /// Creates an encrypted Emergency Recovery Package wrapped with a trusted
  /// contact's dedicated passphrase, enabling zero-knowledge offline escrow
  /// without ever giving admins or Firestore plaintext vault access.
  Future<String> generateEmergencyEscrowBundle({
    required VaultMasterConfig vaultConfig,
    required EmergencyContactConfig contactConfig,
    required String contactEscrowPassphrase,
    required String currentRecoveryKey,
    bool useIsolate = true,
  }) async {
    if (contactEscrowPassphrase.length < 10) {
      throw ArgumentError(
        'Emergency escrow passphrase must be at least 10 characters.',
      );
    }
    final salt = _crypto.generateRandomBytes(VaultConstants.saltLengthBytes);
    final key = await _crypto.deriveArgon2idKey(
      contactEscrowPassphrase,
      salt,
      params: const KdfParams(),
      useIsolate: useIsolate,
    );

    final inner = {
      'contactName': contactConfig.contactName,
      'contactEmail': contactConfig.contactEmail,
      'waitingPeriodHours': contactConfig.waitingPeriodHours,
      'recoveryKey': currentRecoveryKey,
      'keyVersion': vaultConfig.keyVersion,
      'createdAtIso': DateTime.now().toUtc().toIso8601String(),
    };

    final encrypted = await _crypto.encryptJsonMap(key, inner);
    return const JsonEncoder.withIndent('  ').convert({
      'formatVersion': 'VaultX-EmergencyBundle-v1',
      'kdf': const KdfParams().toJson(),
      'salt': base64Encode(salt),
      'ciphertext': encrypted.ciphertext,
      'iv': encrypted.iv,
      'waitingPeriodHours': contactConfig.waitingPeriodHours,
    });
  }
}
