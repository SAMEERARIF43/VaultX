import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/security_audit_models.dart';
import '../domain/models/sharing_emergency_models.dart';
import '../domain/models/user_models.dart';
import '../domain/models/vault_models.dart';
import '../domain/models/vault_record.dart';
import '../platform/android_security_channel.dart';

class VaultSessionState {
  final bool authReady;
  final User? authUser;
  final bool dataLoading;
  final UserProfile? userProfile;
  final VaultMasterConfig? masterConfig;
  final UserSecuritySettings securitySettings;
  final LocalDevicePreferences localPreferences;

  final bool isVaultUnlocked;
  final String? pendingRecoveryCeremonyKey;
  final List<EncryptedVaultRecord> encryptedRecords;
  final List<DecryptedVaultRecord> decryptedRecords;

  final OfflineSyncState syncState;
  final DateTime? lastSyncedAt;
  final int pendingOfflineMutationCount;
  final List<SyncConflictItem> syncConflicts;

  final Map<String, int> externalBreachCounts;
  final DateTime? lastExternalBreachScanAt;
  final bool isRunningBreachScan;

  final List<ShareLedgerEntry> shareLedger;
  final EmergencyContactConfig emergencyConfig;

  final BiometricCapability biometricCapability;
  final bool hasBiometricEnrolledKey;
  final AutofillServiceStatus autofillStatus;

  final int clipboardSecondsLeft;
  final String? lastCopiedLabel;
  final String? lockBannerMessage;

  const VaultSessionState({
    this.authReady = false,
    this.authUser,
    this.dataLoading = false,
    this.userProfile,
    this.masterConfig,
    this.securitySettings = const UserSecuritySettings(),
    this.localPreferences = const LocalDevicePreferences(),
    this.isVaultUnlocked = false,
    this.pendingRecoveryCeremonyKey,
    this.encryptedRecords = const [],
    this.decryptedRecords = const [],
    this.syncState = OfflineSyncState.idle,
    this.lastSyncedAt,
    this.pendingOfflineMutationCount = 0,
    this.syncConflicts = const [],
    this.externalBreachCounts = const {},
    this.lastExternalBreachScanAt,
    this.isRunningBreachScan = false,
    this.shareLedger = const [],
    this.emergencyConfig = const EmergencyContactConfig(),
    this.biometricCapability =
        const BiometricCapability(available: false, status: 'unknown'),
    this.hasBiometricEnrolledKey = false,
    this.autofillStatus =
        const AutofillServiceStatus(supported: false, isDefaultProvider: false),
    this.clipboardSecondsLeft = 0,
    this.lastCopiedLabel,
    this.lockBannerMessage,
  });

  bool get isSignedIn => authUser != null;
  bool get isEmailVerified => authUser?.emailVerified ?? false;
  bool get isVaultInitialized =>
      masterConfig != null && (userProfile?.vaultInitialized ?? true);

  VaultSessionState copyWith({
    bool? authReady,
    User? authUser,
    bool clearAuthUser = false,
    bool? dataLoading,
    UserProfile? userProfile,
    bool clearUserProfile = false,
    VaultMasterConfig? masterConfig,
    bool clearMasterConfig = false,
    UserSecuritySettings? securitySettings,
    LocalDevicePreferences? localPreferences,
    bool? isVaultUnlocked,
    String? pendingRecoveryCeremonyKey,
    bool clearPendingRecoveryKey = false,
    List<EncryptedVaultRecord>? encryptedRecords,
    List<DecryptedVaultRecord>? decryptedRecords,
    OfflineSyncState? syncState,
    DateTime? lastSyncedAt,
    int? pendingOfflineMutationCount,
    List<SyncConflictItem>? syncConflicts,
    Map<String, int>? externalBreachCounts,
    DateTime? lastExternalBreachScanAt,
    bool? isRunningBreachScan,
    List<ShareLedgerEntry>? shareLedger,
    EmergencyContactConfig? emergencyConfig,
    BiometricCapability? biometricCapability,
    bool? hasBiometricEnrolledKey,
    AutofillServiceStatus? autofillStatus,
    int? clipboardSecondsLeft,
    String? lastCopiedLabel,
    bool clearClipboardLabel = false,
    String? lockBannerMessage,
    bool clearLockBanner = false,
  }) {
    return VaultSessionState(
      authReady: authReady ?? this.authReady,
      authUser: clearAuthUser ? null : (authUser ?? this.authUser),
      dataLoading: dataLoading ?? this.dataLoading,
      userProfile:
          clearUserProfile ? null : (userProfile ?? this.userProfile),
      masterConfig:
          clearMasterConfig ? null : (masterConfig ?? this.masterConfig),
      securitySettings: securitySettings ?? this.securitySettings,
      localPreferences: localPreferences ?? this.localPreferences,
      isVaultUnlocked: isVaultUnlocked ?? this.isVaultUnlocked,
      pendingRecoveryCeremonyKey: clearPendingRecoveryKey
          ? null
          : (pendingRecoveryCeremonyKey ?? this.pendingRecoveryCeremonyKey),
      encryptedRecords: encryptedRecords ?? this.encryptedRecords,
      decryptedRecords: decryptedRecords ?? this.decryptedRecords,
      syncState: syncState ?? this.syncState,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingOfflineMutationCount:
          pendingOfflineMutationCount ?? this.pendingOfflineMutationCount,
      syncConflicts: syncConflicts ?? this.syncConflicts,
      externalBreachCounts: externalBreachCounts ?? this.externalBreachCounts,
      lastExternalBreachScanAt:
          lastExternalBreachScanAt ?? this.lastExternalBreachScanAt,
      isRunningBreachScan: isRunningBreachScan ?? this.isRunningBreachScan,
      shareLedger: shareLedger ?? this.shareLedger,
      emergencyConfig: emergencyConfig ?? this.emergencyConfig,
      biometricCapability: biometricCapability ?? this.biometricCapability,
      hasBiometricEnrolledKey:
          hasBiometricEnrolledKey ?? this.hasBiometricEnrolledKey,
      autofillStatus: autofillStatus ?? this.autofillStatus,
      clipboardSecondsLeft: clipboardSecondsLeft ?? this.clipboardSecondsLeft,
      lastCopiedLabel:
          clearClipboardLabel ? null : (lastCopiedLabel ?? this.lastCopiedLabel),
      lockBannerMessage:
          clearLockBanner ? null : (lockBannerMessage ?? this.lockBannerMessage),
    );
  }
}
