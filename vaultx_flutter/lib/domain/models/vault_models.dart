import '../../core/constants/vault_constants.dart';

class KdfParams {
  final String algorithm;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const KdfParams({
    this.algorithm = VaultConstants.kdfAlgorithm,
    this.memoryKiB = VaultConstants.defaultKdfMemoryKiB,
    this.iterations = VaultConstants.defaultKdfIterations,
    this.parallelism = VaultConstants.defaultKdfParallelism,
  });

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    return KdfParams(
      algorithm: json['algorithm'] as String? ?? VaultConstants.kdfAlgorithm,
      memoryKiB: (json['memoryKiB'] as num).toInt(),
      iterations: (json['iterations'] as num).toInt(),
      parallelism: (json['parallelism'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'memoryKiB': memoryKiB,
        'iterations': iterations,
        'parallelism': parallelism,
      };
}

class CredentialPayload {
  final String title;
  final String username;
  final String password;
  final String url;
  final String category;
  final String notes;

  const CredentialPayload({
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.category,
    required this.notes,
  });

  factory CredentialPayload.fromJson(Map<String, dynamic> json) {
    return CredentialPayload(
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      url: json['url'] as String? ?? '',
      category: json['category'] as String? ?? 'Personal',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'category': category,
        'notes': notes,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CredentialPayload &&
        other.title == title &&
        other.username == username &&
        other.password == password &&
        other.url == url &&
        other.category == category &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(title, username, password, url, category, notes);
}

class VaultMasterConfig {
  final String userId;
  final String kdfAlgorithm;
  final int kdfMemoryKiB;
  final int kdfIterations;
  final int kdfParallelism;
  final String masterSalt;
  final String wrappedVaultKey;
  final String wrappedVaultKeyIv;
  final String recoverySalt;
  final String recoveryWrappedVaultKey;
  final String recoveryWrappedVaultKeyIv;
  final String recoveryKeyHint;
  final int keyVersion;

  const VaultMasterConfig({
    required this.userId,
    required this.kdfAlgorithm,
    required this.kdfMemoryKiB,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.masterSalt,
    required this.wrappedVaultKey,
    required this.wrappedVaultKeyIv,
    required this.recoverySalt,
    required this.recoveryWrappedVaultKey,
    required this.recoveryWrappedVaultKeyIv,
    required this.recoveryKeyHint,
    required this.keyVersion,
  });

  KdfParams get kdfParams => KdfParams(
        algorithm: kdfAlgorithm,
        memoryKiB: kdfMemoryKiB,
        iterations: kdfIterations,
        parallelism: kdfParallelism,
      );

  factory VaultMasterConfig.fromMap(Map<String, dynamic> map) {
    return VaultMasterConfig(
      userId: map['userId'] as String? ?? '',
      kdfAlgorithm: map['kdfAlgorithm'] as String? ?? VaultConstants.kdfAlgorithm,
      kdfMemoryKiB: (map['kdfMemoryKiB'] as num).toInt(),
      kdfIterations: (map['kdfIterations'] as num).toInt(),
      kdfParallelism: (map['kdfParallelism'] as num).toInt(),
      masterSalt: map['masterSalt'] as String,
      wrappedVaultKey: map['wrappedVaultKey'] as String,
      wrappedVaultKeyIv: map['wrappedVaultKeyIv'] as String,
      recoverySalt: map['recoverySalt'] as String,
      recoveryWrappedVaultKey: map['recoveryWrappedVaultKey'] as String,
      recoveryWrappedVaultKeyIv: map['recoveryWrappedVaultKeyIv'] as String,
      recoveryKeyHint: map['recoveryKeyHint'] as String,
      keyVersion: (map['keyVersion'] as num).toInt(),
    );
  }

  Map<String, dynamic> toConfigMap() => {
        'userId': userId,
        'kdfAlgorithm': kdfAlgorithm,
        'kdfMemoryKiB': kdfMemoryKiB,
        'kdfIterations': kdfIterations,
        'kdfParallelism': kdfParallelism,
        'masterSalt': masterSalt,
        'wrappedVaultKey': wrappedVaultKey,
        'wrappedVaultKeyIv': wrappedVaultKeyIv,
        'recoverySalt': recoverySalt,
        'recoveryWrappedVaultKey': recoveryWrappedVaultKey,
        'recoveryWrappedVaultKeyIv': recoveryWrappedVaultKeyIv,
        'recoveryKeyHint': recoveryKeyHint,
        'keyVersion': keyVersion,
      };
}

class EncryptedPayloadPair {
  final String ciphertext;
  final String iv;

  const EncryptedPayloadPair({
    required this.ciphertext,
    required this.iv,
  });
}
