class VaultConstants {
  VaultConstants._();

  static const String firebaseProjectId = 'arctic-digit-87cdj';
  static const String firestoreDatabaseId = 'ai-studio-8494ca94-6f4d-44cf-b5ad-d01b20e7a342';

  static const String kdfAlgorithm = 'Argon2id';
  static const int defaultKdfMemoryKiB = 65536; // 64 MiB
  static const int defaultKdfIterations = 3;
  static const int defaultKdfParallelism = 1;
  static const int derivedKeyLengthBytes = 32; // 256-bit

  static const int saltLengthBytes = 16; // 128-bit
  static const int aesGcmNonceLengthBytes = 12; // 96-bit
  static const int aesGcmTagLengthBytes = 16; // 128-bit
  static const int maxCiphertextBase64Length = 32768;

  static const String recoveryKeyAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const int recoveryKeyRawLength = 52;
  static const int minNormalizedRecoveryKeyLength = 32;

  static const List<String> defaultCategories = [
    'Work',
    'Finance',
    'Social',
    'Developer',
    'Shopping',
    'Entertainment',
    'Personal',
  ];

  static const int minAutoLockMinutes = 1;
  static const int maxAutoLockMinutes = 120;
  static const int defaultAutoLockMinutes = 15;

  static const int minClipboardClearSeconds = 10;
  static const int maxClipboardClearSeconds = 300;
  static const int defaultClipboardClearSeconds = 30;

  static const int stalePasswordDays = 180;
  static const int maxPasswordHistoryEntries = 10;

  static const int defaultTotpPeriodSeconds = 30;
  static const int defaultTotpDigits = 6;

  static const String backupFormatVersion = 'VaultXBackup-v1';
  static const String shareFormatVersion = 'VaultX-Share-v1';
  static const String hibpRangeApiBase = 'https://api.pwnedpasswords.com/range/';
}
