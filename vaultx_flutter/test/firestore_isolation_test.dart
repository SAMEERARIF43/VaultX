import 'package:test/test.dart';
import 'package:vaultx_flutter/core/constants/vault_constants.dart';
import 'package:vaultx_flutter/core/errors/vault_exceptions.dart';
import 'package:vaultx_flutter/domain/models/vault_record.dart';
import 'package:vaultx_flutter/domain/services/crypto_service.dart';

void main() {
  group('Firestore Database & Security Invariants', () {
    test('enforces VaultX Firebase project and named Firestore database ID', () {
      expect(VaultConstants.firebaseProjectId, 'arctic-digit-87cdj');
      expect(
        VaultConstants.firestoreDatabaseId,
        'ai-studio-8494ca94-6f4d-44cf-b5ad-d01b20e7a342',
      );
      expect(VaultConstants.firestoreDatabaseId, isNot('(default)'));
    });

    test('encrypted VaultRecordPayload satisfies Firestore 32KB ciphertext bound',
        () async {
      final crypto = VaultCryptoService();
      final key = crypto.importRawKeyBase64(
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      );
      const payload = VaultRecordPayload(
        title: 'Production Login',
        username: 'user@vaultx.test',
        password: 'StrongPassword!2026',
        url: 'https://vaultx.test',
        category: 'Personal',
        notes: 'Encrypted locally before Firestore upload.',
      );

      final encrypted = await crypto.encryptVaultRecordPayload(key, payload);
      expect(
        encrypted.ciphertext.length,
        lessThanOrEqualTo(VaultConstants.maxCiphertextBase64Length),
      );
      expect(encrypted.iv.length, lessThanOrEqualTo(64));

      final decrypted = await crypto.decryptVaultRecordPayload(
        key,
        encrypted.ciphertext,
        encrypted.iv,
      );
      expect(decrypted.title, payload.title);
      expect(decrypted.password, payload.password);
    });

    test('BiometricAuthException classifies invalidation & cancellation flags',
        () {
      const invalidated = BiometricAuthException(
        'BIOMETRIC_INVALIDATED',
        'Biometrics changed.',
      );
      const cancelled = BiometricAuthException(
        'BIOMETRIC_CANCELLED',
        'Cancelled.',
      );
      expect(invalidated.isInvalidated, isTrue);
      expect(invalidated.isCancelled, isFalse);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isInvalidated, isFalse);
    });
  });
}
