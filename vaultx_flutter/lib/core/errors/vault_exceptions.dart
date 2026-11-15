class InvalidMasterPasswordException implements Exception {
  final String message;

  const InvalidMasterPasswordException([
    this.message = 'Incorrect master password or corrupted vault key.',
  ]);

  @override
  String toString() => 'InvalidMasterPasswordException: $message';
}

class InvalidRecoveryKeyException implements Exception {
  final String message;

  const InvalidRecoveryKeyException([
    this.message = 'Invalid recovery key. Please verify all characters.',
  ]);

  @override
  String toString() => 'InvalidRecoveryKeyException: $message';
}

class CiphertextTamperedException implements Exception {
  final String message;

  const CiphertextTamperedException([
    this.message = 'AES-256-GCM authentication failed. Ciphertext, IV, or tag is invalid.',
  ]);

  @override
  String toString() => 'CiphertextTamperedException: $message';
}

class BiometricAuthException implements Exception {
  final String code;
  final String message;

  const BiometricAuthException(this.code, this.message);

  bool get isInvalidated => code == 'BIOMETRIC_INVALIDATED';
  bool get isCancelled => code == 'BIOMETRIC_CANCELLED';

  @override
  String toString() => 'BiometricAuthException($code): $message';
}

class FirestoreOperationException implements Exception {
  final String operationType;
  final String path;
  final String message;

  const FirestoreOperationException({
    required this.operationType,
    required this.path,
    required this.message,
  });

  @override
  String toString() =>
      'FirestoreOperationException($operationType @ $path): $message';
}

class OfflineStorageException implements Exception {
  final String message;

  const OfflineStorageException(this.message);

  @override
  String toString() => 'OfflineStorageException: $message';
}
