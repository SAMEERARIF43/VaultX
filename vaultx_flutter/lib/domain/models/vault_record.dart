import 'vault_models.dart';
import 'vault_record_type.dart';
import 'wallet_details.dart';

/// Backward-compatible encrypted payload stored inside `users/{uid}/credentials/{id}`.
///
/// Always includes the top-level legacy fields (`title`, `username`, `password`,
/// `url`, `category`, `notes`) so existing Web records decrypt seamlessly in Flutter
/// and Flutter login records remain readable in the React/TypeScript web app.
class VaultRecordPayload {
  final String title;
  final String username;
  final String password;
  final String url;
  final String category;
  final String notes;

  final VaultRecordType recordType;
  final String? packageName;
  final String? folder;
  final List<String> tags;
  final bool isFavorite;
  final List<PasswordHistoryEntry> passwordHistory;
  final String? expiresAtIso;
  final String? lastAccessedAtIso;

  final TotpDetails? totp;
  final SecureNoteDetails? secureNote;
  final WifiDetails? wifi;
  final PaymentCardDetails? card;
  final IdentityDetails? identity;
  final LicenseKeyDetails? license;
  final RecoveryCodesDetails? recoveryCodes;

  const VaultRecordPayload({
    required this.title,
    this.username = '',
    this.password = '',
    this.url = '',
    this.category = 'Personal',
    this.notes = '',
    this.recordType = VaultRecordType.login,
    this.packageName,
    this.folder,
    this.tags = const [],
    this.isFavorite = false,
    this.passwordHistory = const [],
    this.expiresAtIso,
    this.lastAccessedAtIso,
    this.totp,
    this.secureNote,
    this.wifi,
    this.card,
    this.identity,
    this.license,
    this.recoveryCodes,
  });

  DateTime? get expiresAt =>
      expiresAtIso != null ? DateTime.tryParse(expiresAtIso!) : null;

  DateTime? get lastAccessedAt =>
      lastAccessedAtIso != null ? DateTime.tryParse(lastAccessedAtIso!) : null;

  CredentialPayload toLegacyCredentialPayload() => CredentialPayload(
        title: title,
        username: username,
        password: password,
        url: url,
        category: category,
        notes: notes,
      );

  factory VaultRecordPayload.fromJson(Map<String, dynamic> json) {
    final type = VaultRecordType.fromWire(json['recordType'] as String?);
    return VaultRecordPayload(
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      url: json['url'] as String? ?? '',
      category: json['category'] as String? ?? 'Personal',
      notes: json['notes'] as String? ?? '',
      recordType: type,
      packageName: json['packageName'] as String?,
      folder: json['folder'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      isFavorite: json['isFavorite'] as bool? ?? false,
      passwordHistory: (json['passwordHistory'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(PasswordHistoryEntry.fromJson)
              .toList() ??
          const [],
      expiresAtIso: json['expiresAtIso'] as String?,
      lastAccessedAtIso: json['lastAccessedAtIso'] as String?,
      totp: json['totp'] is Map<String, dynamic>
          ? TotpDetails.fromJson(json['totp'] as Map<String, dynamic>)
          : null,
      secureNote: json['secureNote'] is Map<String, dynamic>
          ? SecureNoteDetails.fromJson(
              json['secureNote'] as Map<String, dynamic>,
            )
          : null,
      wifi: json['wifi'] is Map<String, dynamic>
          ? WifiDetails.fromJson(json['wifi'] as Map<String, dynamic>)
          : null,
      card: json['card'] is Map<String, dynamic>
          ? PaymentCardDetails.fromJson(json['card'] as Map<String, dynamic>)
          : null,
      identity: json['identity'] is Map<String, dynamic>
          ? IdentityDetails.fromJson(json['identity'] as Map<String, dynamic>)
          : null,
      license: json['license'] is Map<String, dynamic>
          ? LicenseKeyDetails.fromJson(json['license'] as Map<String, dynamic>)
          : null,
      recoveryCodes: json['recoveryCodes'] is Map<String, dynamic>
          ? RecoveryCodesDetails.fromJson(
              json['recoveryCodes'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'category': category,
      'notes': notes,
    };

    if (recordType != VaultRecordType.login) {
      map['recordType'] = recordType.wireValue;
    }
    if (packageName != null && packageName!.trim().isNotEmpty) {
      map['packageName'] = packageName!.trim();
    }
    if (folder != null && folder!.trim().isNotEmpty) {
      map['folder'] = folder!.trim();
    }
    if (tags.isNotEmpty) {
      map['tags'] = tags;
    }
    if (isFavorite) {
      map['isFavorite'] = true;
    }
    if (passwordHistory.isNotEmpty) {
      map['passwordHistory'] = passwordHistory.map((e) => e.toJson()).toList();
    }
    if (expiresAtIso != null && expiresAtIso!.isNotEmpty) {
      map['expiresAtIso'] = expiresAtIso;
    }
    if (lastAccessedAtIso != null && lastAccessedAtIso!.isNotEmpty) {
      map['lastAccessedAtIso'] = lastAccessedAtIso;
    }
    if (totp != null) map['totp'] = totp!.toJson();
    if (secureNote != null) map['secureNote'] = secureNote!.toJson();
    if (wifi != null) map['wifi'] = wifi!.toJson();
    if (card != null) map['card'] = card!.toJson();
    if (identity != null) map['identity'] = identity!.toJson();
    if (license != null) map['license'] = license!.toJson();
    if (recoveryCodes != null) map['recoveryCodes'] = recoveryCodes!.toJson();

    return map;
  }

  VaultRecordPayload copyWith({
    String? title,
    String? username,
    String? password,
    String? url,
    String? category,
    String? notes,
    VaultRecordType? recordType,
    String? packageName,
    bool clearPackageName = false,
    String? folder,
    bool clearFolder = false,
    List<String>? tags,
    bool? isFavorite,
    List<PasswordHistoryEntry>? passwordHistory,
    String? expiresAtIso,
    bool clearExpiresAt = false,
    String? lastAccessedAtIso,
    TotpDetails? totp,
    SecureNoteDetails? secureNote,
    WifiDetails? wifi,
    PaymentCardDetails? card,
    IdentityDetails? identity,
    LicenseKeyDetails? license,
    RecoveryCodesDetails? recoveryCodes,
  }) {
    return VaultRecordPayload(
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      recordType: recordType ?? this.recordType,
      packageName:
          clearPackageName ? null : (packageName ?? this.packageName),
      folder: clearFolder ? null : (folder ?? this.folder),
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      passwordHistory: passwordHistory ?? this.passwordHistory,
      expiresAtIso:
          clearExpiresAt ? null : (expiresAtIso ?? this.expiresAtIso),
      lastAccessedAtIso: lastAccessedAtIso ?? this.lastAccessedAtIso,
      totp: totp ?? this.totp,
      secureNote: secureNote ?? this.secureNote,
      wifi: wifi ?? this.wifi,
      card: card ?? this.card,
      identity: identity ?? this.identity,
      license: license ?? this.license,
      recoveryCodes: recoveryCodes ?? this.recoveryCodes,
    );
  }
}

class EncryptedVaultRecord {
  final String id;
  final String userId;
  final String ciphertext;
  final String iv;
  final int keyVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EncryptedVaultRecord({
    required this.id,
    required this.userId,
    required this.ciphertext,
    required this.iv,
    required this.keyVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EncryptedVaultRecord.fromJson(Map<String, dynamic> json) =>
      EncryptedVaultRecord(
        id: json['id'] as String,
        userId: json['userId'] as String,
        ciphertext: json['ciphertext'] as String,
        iv: json['iv'] as String,
        keyVersion: (json['keyVersion'] as num).toInt(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'ciphertext': ciphertext,
        'iv': iv,
        'keyVersion': keyVersion,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class DecryptedVaultRecord {
  final String id;
  final int keyVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VaultRecordPayload payload;
  final bool decryptionError;

  const DecryptedVaultRecord({
    required this.id,
    required this.keyVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.payload,
    this.decryptionError = false,
  });

  String get title => payload.title;
  String get username => payload.username;
  String get password => payload.password;
  String get url => payload.url;
  String get category => payload.category;
  String get notes => payload.notes;
  VaultRecordType get recordType => payload.recordType;
}
