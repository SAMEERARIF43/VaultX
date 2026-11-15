import 'vault_record.dart';

class EphemeralSharePackage {
  final String formatVersion;
  final String shareId;
  final String createdAtIso;
  final String expiresAtIso;
  final bool requiresPasscode;
  final String? passcodeSaltBase64;
  final String ciphertextBase64;
  final String ivBase64;

  const EphemeralSharePackage({
    required this.formatVersion,
    required this.shareId,
    required this.createdAtIso,
    required this.expiresAtIso,
    required this.requiresPasscode,
    this.passcodeSaltBase64,
    required this.ciphertextBase64,
    required this.ivBase64,
  });

  DateTime? get expiresAt => DateTime.tryParse(expiresAtIso);
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory EphemeralSharePackage.fromJson(Map<String, dynamic> json) =>
      EphemeralSharePackage(
        formatVersion: json['formatVersion'] as String? ?? '',
        shareId: json['shareId'] as String? ?? '',
        createdAtIso: json['createdAtIso'] as String? ?? '',
        expiresAtIso: json['expiresAtIso'] as String? ?? '',
        requiresPasscode: json['requiresPasscode'] as bool? ?? false,
        passcodeSaltBase64: json['passcodeSaltBase64'] as String?,
        ciphertextBase64: json['ciphertextBase64'] as String? ?? '',
        ivBase64: json['ivBase64'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'shareId': shareId,
        'createdAtIso': createdAtIso,
        'expiresAtIso': expiresAtIso,
        'requiresPasscode': requiresPasscode,
        if (passcodeSaltBase64 != null)
          'passcodeSaltBase64': passcodeSaltBase64,
        'ciphertextBase64': ciphertextBase64,
        'ivBase64': ivBase64,
      };
}

class ShareLedgerEntry {
  final String shareId;
  final String recordId;
  final String recordTitle;
  final String recipientLabel;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool revokedLocally;

  const ShareLedgerEntry({
    required this.shareId,
    required this.recordId,
    required this.recordTitle,
    required this.recipientLabel,
    required this.createdAt,
    required this.expiresAt,
    this.revokedLocally = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory ShareLedgerEntry.fromJson(Map<String, dynamic> json) =>
      ShareLedgerEntry(
        shareId: json['shareId'] as String? ?? '',
        recordId: json['recordId'] as String? ?? '',
        recordTitle: json['recordTitle'] as String? ?? '',
        recipientLabel: json['recipientLabel'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now(),
        revokedLocally: json['revokedLocally'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'shareId': shareId,
        'recordId': recordId,
        'recordTitle': recordTitle,
        'recipientLabel': recipientLabel,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'revokedLocally': revokedLocally,
      };

  ShareLedgerEntry copyWith({bool? revokedLocally}) => ShareLedgerEntry(
        shareId: shareId,
        recordId: recordId,
        recordTitle: recordTitle,
        recipientLabel: recipientLabel,
        createdAt: createdAt,
        expiresAt: expiresAt,
        revokedLocally: revokedLocally ?? this.revokedLocally,
      );
}

enum EmergencyAccessStatus {
  unconfigured,
  configured,
  requestPendingWaitingPeriod,
  consentRequired,
  readyForLocalRecovery,
  denied,
}

class EmergencyContactConfig {
  final String contactName;
  final String contactEmail;
  final int waitingPeriodHours;
  final EmergencyAccessStatus status;
  final DateTime? requestedAt;
  final DateTime? updatedAt;

  const EmergencyContactConfig({
    this.contactName = '',
    this.contactEmail = '',
    this.waitingPeriodHours = 72,
    this.status = EmergencyAccessStatus.unconfigured,
    this.requestedAt,
    this.updatedAt,
  });

  bool get isConfigured => contactName.isNotEmpty && contactEmail.isNotEmpty;

  Duration? get remainingWait {
    if (status != EmergencyAccessStatus.requestPendingWaitingPeriod ||
        requestedAt == null) {
      return null;
    }
    final unlockAt = requestedAt!.add(Duration(hours: waitingPeriodHours));
    final diff = unlockAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory EmergencyContactConfig.fromJson(Map<String, dynamic> json) =>
      EmergencyContactConfig(
        contactName: json['contactName'] as String? ?? '',
        contactEmail: json['contactEmail'] as String? ?? '',
        waitingPeriodHours: (json['waitingPeriodHours'] as num?)?.toInt() ?? 72,
        status: EmergencyAccessStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String?),
          orElse: () => EmergencyAccessStatus.unconfigured,
        ),
        requestedAt: json['requestedAt'] != null
            ? DateTime.tryParse(json['requestedAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'contactName': contactName,
        'contactEmail': contactEmail,
        'waitingPeriodHours': waitingPeriodHours,
        'status': status.name,
        if (requestedAt != null) 'requestedAt': requestedAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  EmergencyContactConfig copyWith({
    String? contactName,
    String? contactEmail,
    int? waitingPeriodHours,
    EmergencyAccessStatus? status,
    DateTime? requestedAt,
    bool clearRequestedAt = false,
    DateTime? updatedAt,
  }) {
    return EmergencyContactConfig(
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      waitingPeriodHours: waitingPeriodHours ?? this.waitingPeriodHours,
      status: status ?? this.status,
      requestedAt: clearRequestedAt ? null : (requestedAt ?? this.requestedAt),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum OfflineSyncState {
  idle,
  syncing,
  synced,
  offlineCached,
  conflictDetected,
  error,
}

class SyncConflictItem {
  final String recordId;
  final EncryptedVaultRecord localRecord;
  final EncryptedVaultRecord remoteRecord;
  final String reason;

  const SyncConflictItem({
    required this.recordId,
    required this.localRecord,
    required this.remoteRecord,
    required this.reason,
  });
}
