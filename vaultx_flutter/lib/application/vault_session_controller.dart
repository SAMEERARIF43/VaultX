import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/vault_constants.dart';
import '../core/errors/vault_exceptions.dart';
import '../data/repositories/firestore_vault_repository.dart';
import '../data/repositories/offline_vault_store.dart';
import '../domain/models/security_audit_models.dart';
import '../domain/models/sharing_emergency_models.dart';
import '../domain/models/user_models.dart';
import '../domain/models/vault_models.dart';
import '../domain/models/vault_record.dart';
import '../domain/models/vault_record_type.dart';
import '../domain/models/wallet_details.dart';
import '../domain/services/backup_service.dart';
import '../domain/services/crypto_service.dart';
import '../domain/services/security_audit_service.dart';
import '../domain/services/sharing_emergency_service.dart';
import '../platform/android_security_channel.dart';
import 'vault_session_state.dart';

class VaultSessionController extends StateNotifier<VaultSessionState> {
  final FirebaseAuth _auth;
  final FirestoreVaultRepository _repo;
  final OfflineVaultStore _offlineStore;
  final VaultCryptoService _crypto;
  final SecurityAuditService _auditService;
  final BackupService _backupService;
  final SharingEmergencyService _sharingService;
  final AndroidSecurityChannel _androidChannel;

  // Strictly in-memory DEK; never persisted to disk or logged.
  SecretKey? _vaultKey;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<EncryptedVaultRecord>>? _recordsSub;
  Timer? _inactivityTimer;
  Timer? _clipboardTimer;

  VaultSessionController({
    required FirebaseAuth auth,
    required FirestoreVaultRepository repo,
    required OfflineVaultStore offlineStore,
    required VaultCryptoService crypto,
    required SecurityAuditService auditService,
    required BackupService backupService,
    required SharingEmergencyService sharingService,
    required AndroidSecurityChannel androidChannel,
  })  : _auth = auth,
        _repo = repo,
        _offlineStore = offlineStore,
        _crypto = crypto,
        _auditService = auditService,
        _backupService = backupService,
        _sharingService = sharingService,
        _androidChannel = androidChannel,
        super(const VaultSessionState()) {
    _bootstrap();
  }

  void _bootstrap() {
    _refreshPlatformCapabilities();
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _refreshPlatformCapabilities() async {
    final bioCap = await _androidChannel.canAuthenticateBiometrics();
    final hasBioKey = await _androidChannel.hasBiometricVaultKey();
    final afStatus = await _androidChannel.getAutofillStatus();
    if (!mounted) return;
    state = state.copyWith(
      biometricCapability: bioCap,
      hasBiometricEnrolledKey: hasBioKey,
      autofillStatus: afStatus,
    );
  }

  Future<void> refreshAutofillAndBiometricStatus() =>
      _refreshPlatformCapabilities();

  Future<void> _onAuthStateChanged(User? user) async {
    await _recordsSub?.cancel();
    _recordsSub = null;

    if (user == null) {
      _clearInMemorySecrets();
      state = VaultSessionState(
        authReady: true,
        biometricCapability: state.biometricCapability,
        hasBiometricEnrolledKey: state.hasBiometricEnrolledKey,
        autofillStatus: state.autofillStatus,
      );
      return;
    }

    state = state.copyWith(authReady: true, authUser: user);
    await _loadUserEnvironment(user);
  }

  Future<void> _loadUserEnvironment(User user) async {
    final prefs = await _offlineStore.loadLocalPrefs(user.uid);
    final shareLedger = await _offlineStore.loadShareLedger(user.uid);
    final emergencyCfg = await _offlineStore.loadEmergencyConfig(user.uid);
    await _androidChannel
        .setScreenshotProtection(prefs.screenshotProtectionEnabled);

    if (!user.emailVerified) {
      state = state.copyWith(
        localPreferences: prefs,
        shareLedger: shareLedger,
        emergencyConfig: emergencyCfg,
        clearUserProfile: true,
        clearMasterConfig: true,
      );
      return;
    }

    state = state.copyWith(
      dataLoading: true,
      localPreferences: prefs,
      shareLedger: shareLedger,
      emergencyConfig: emergencyCfg,
      syncState: OfflineSyncState.syncing,
    );

    final cachedSnapshot = await _offlineStore.loadSnapshot(user.uid);

    try {
      final remote = await _repo.fetchUserVaultState(user.uid);
      final effectiveConfig = remote.masterConfig ?? cachedSnapshot?.masterConfig;

      state = state.copyWith(
        dataLoading: false,
        userProfile: remote.profile,
        masterConfig: effectiveConfig,
        securitySettings:
            remote.settings ?? UserSecuritySettings(userId: user.uid),
        pendingOfflineMutationCount:
            cachedSnapshot?.pendingMutations.length ?? 0,
      );

      if (effectiveConfig != null) {
        _subscribeToCloudRecords(user.uid, effectiveConfig);
      }
    } catch (_) {
      // Offline fallback using strictly encrypted local snapshot
      if (cachedSnapshot != null && cachedSnapshot.masterConfig != null) {
        state = state.copyWith(
          dataLoading: false,
          masterConfig: cachedSnapshot.masterConfig,
          encryptedRecords: cachedSnapshot.encryptedRecords,
          lastSyncedAt: cachedSnapshot.syncedAt,
          pendingOfflineMutationCount: cachedSnapshot.pendingMutations.length,
          syncState: OfflineSyncState.offlineCached,
        );
      } else {
        state = state.copyWith(
          dataLoading: false,
          syncState: OfflineSyncState.error,
        );
      }
    }
  }

  void _subscribeToCloudRecords(String uid, VaultMasterConfig masterConfig) {
    _recordsSub?.cancel();
    _recordsSub = _repo.watchEncryptedRecords(uid).listen(
      (remoteRecords) async {
        final existingSnapshot = await _offlineStore.loadSnapshot(uid);
        final pending = existingSnapshot?.pendingMutations ?? const [];

        final conflicts = _offlineStore.detectConflicts(
          pending: pending,
          remoteRecords: remoteRecords,
        );

        await _offlineStore.saveSnapshot(
          OfflineVaultSnapshot(
            uid: uid,
            masterConfig: masterConfig,
            encryptedRecords: remoteRecords,
            pendingMutations: pending,
            syncedAt: DateTime.now(),
          ),
        );

        if (!mounted) return;
        state = state.copyWith(
          encryptedRecords: remoteRecords,
          lastSyncedAt: DateTime.now(),
          pendingOfflineMutationCount: pending.length,
          syncConflicts: conflicts,
          syncState: conflicts.isNotEmpty
              ? OfflineSyncState.conflictDetected
              : OfflineSyncState.synced,
        );

        if (_vaultKey != null) {
          await _decryptAllInMemory(remoteRecords);
        }

        if (pending.isNotEmpty && conflicts.isEmpty && _vaultKey != null) {
          await _replayPendingMutations(uid, pending);
        }
      },
      onError: (_) {
        if (!mounted) return;
        state = state.copyWith(syncState: OfflineSyncState.offlineCached);
      },
    );
  }

  Future<void> _replayPendingMutations(
    String uid,
    List<PendingOfflineMutation> pending,
  ) async {
    final remaining = <PendingOfflineMutation>[];
    for (final m in pending) {
      try {
        if (m.type == PendingMutationType.delete) {
          await _repo.deleteEncryptedRecord(
            uid: uid,
            credentialId: m.credentialId,
          );
        } else if (m.encryptedRecord != null && _vaultKey != null) {
          final payload = await _crypto.decryptVaultRecordPayload(
            _vaultKey!,
            m.encryptedRecord!.ciphertext,
            m.encryptedRecord!.iv,
          );
          if (m.type == PendingMutationType.create) {
            await _repo.createEncryptedRecord(
              uid: uid,
              vaultKey: _vaultKey!,
              keyVersion: state.masterConfig?.keyVersion ?? 1,
              payload: payload,
              explicitCredentialId: m.credentialId,
            );
          } else {
            await _repo.updateEncryptedRecord(
              uid: uid,
              credentialId: m.credentialId,
              vaultKey: _vaultKey!,
              keyVersion: state.masterConfig?.keyVersion ?? 1,
              payload: payload,
            );
          }
        }
      } catch (_) {
        remaining.add(m);
      }
    }

    final snapshot = await _offlineStore.loadSnapshot(uid);
    if (snapshot != null) {
      await _offlineStore.saveSnapshot(
        OfflineVaultSnapshot(
          uid: uid,
          masterConfig: snapshot.masterConfig,
          encryptedRecords: snapshot.encryptedRecords,
          pendingMutations: remaining,
          syncedAt: DateTime.now(),
        ),
      );
    }
    if (mounted) {
      state = state.copyWith(
        pendingOfflineMutationCount: remaining.length,
        syncState: remaining.isEmpty
            ? OfflineSyncState.synced
            : OfflineSyncState.offlineCached,
      );
    }
  }

  Future<void> _decryptAllInMemory(List<EncryptedVaultRecord> records) async {
    final key = _vaultKey;
    if (key == null) return;

    final decrypted = <DecryptedVaultRecord>[];
    for (final rec in records) {
      try {
        final payload = await _crypto.decryptVaultRecordPayload(
          key,
          rec.ciphertext,
          rec.iv,
        );
        decrypted.add(
          DecryptedVaultRecord(
            id: rec.id,
            keyVersion: rec.keyVersion,
            createdAt: rec.createdAt,
            updatedAt: rec.updatedAt,
            payload: payload,
          ),
        );
      } catch (_) {
        decrypted.add(
          DecryptedVaultRecord(
            id: rec.id,
            keyVersion: rec.keyVersion,
            createdAt: rec.createdAt,
            updatedAt: rec.updatedAt,
            payload: const VaultRecordPayload(
              title: 'Unreadable Record',
              notes: 'Decryption failed with current vault key.',
            ),
            decryptionError: true,
          ),
        );
      }
    }

    if (!mounted || _vaultKey == null) return;
    state = state.copyWith(decryptedRecords: decrypted);
    await _syncAutofillCacheIfEnabled(decrypted);
  }

  Future<void> _syncAutofillCacheIfEnabled(
    List<DecryptedVaultRecord> decrypted,
  ) async {
    final key = _vaultKey;
    if (key == null) return;
    if (!state.localPreferences.autofillIndexSyncEnabled ||
        !state.hasBiometricEnrolledKey) {
      return;
    }
    final entries = decrypted
        .where(
          (r) =>
              !r.decryptionError &&
              (r.recordType == VaultRecordType.login ||
                  r.recordType == VaultRecordType.appLogin) &&
              (r.username.isNotEmpty || r.password.isNotEmpty),
        )
        .map(
          (r) => {
            'id': r.id,
            'title': r.title,
            'username': r.username,
            'password': r.password,
            'url': r.url,
            'packageName': r.payload.packageName ?? '',
          },
        )
        .toList();

    final encrypted = await _crypto.encryptJsonMap(key, {'entries': entries});
    await _androidChannel.syncAutofillIndex(
      ciphertextBase64: encrypted.ciphertext,
      ivBase64: encrypted.iv,
    );
  }

  // --- Authentication Flows ---

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
    }
    await cred.user?.sendEmailVerification();
  }

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'aborted-by-user',
        message: 'Google sign-in was cancelled.',
      );
    }
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    final updated = _auth.currentUser;
    if (updated != null) {
      state = state.copyWith(authUser: updated);
      if (updated.emailVerified) {
        await _loadUserEnvironment(updated);
      }
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // --- Vault Key Lifecycle ---

  Future<String> setupMasterPassword({
    required String masterPassword,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Signed-in verified user required.');
    }

    final init = await _crypto.initializeVaultKeys(
      masterPassword,
      userId: user.uid,
    );

    await _repo.initializeVaultInFirestore(
      uid: user.uid,
      email: user.email!,
      displayName:
          displayName ?? user.displayName ?? user.email!.split('@').first,
      profileExists: state.userProfile != null,
      configData: init.configData,
    );

    _vaultKey = init.vaultKey;
    _resetInactivityTimer();
    await _loadUserEnvironment(user);

    state = state.copyWith(
      isVaultUnlocked: true,
      pendingRecoveryCeremonyKey: init.recoveryKey,
      clearLockBanner: true,
    );

    return init.recoveryKey;
  }

  void acknowledgeRecoveryCeremony() {
    state = state.copyWith(clearPendingRecoveryKey: true);
  }

  Future<void> unlockWithMasterPassword(String masterPassword) async {
    final cfg = state.masterConfig;
    if (cfg == null) {
      throw StateError('Vault configuration not found.');
    }
    final key = await _crypto.unlockVaultWithMasterPassword(masterPassword, cfg);
    _vaultKey = key;
    _resetInactivityTimer();
    state = state.copyWith(
      isVaultUnlocked: true,
      clearLockBanner: true,
    );
    await _decryptAllInMemory(state.encryptedRecords);
  }

  Future<void> unlockWithRecoveryKey(String recoveryKey) async {
    final cfg = state.masterConfig;
    if (cfg == null) {
      throw StateError('Vault configuration not found.');
    }
    final key = await _crypto.unlockVaultWithRecoveryKey(recoveryKey, cfg);
    _vaultKey = key;
    _resetInactivityTimer();
    state = state.copyWith(
      isVaultUnlocked: true,
      clearLockBanner: true,
    );
    await _decryptAllInMemory(state.encryptedRecords);
  }

  Future<bool> verifyMasterPassword(String masterPassword) async {
    final cfg = state.masterConfig;
    if (cfg == null) return false;
    try {
      await _crypto.unlockVaultWithMasterPassword(masterPassword, cfg);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Biometric Hardware Keystore Integration ---

  Future<void> enableBiometricUnlock() async {
    final key = _vaultKey;
    final uid = state.authUser?.uid;
    if (key == null || uid == null) {
      throw StateError('Unlock vault with your Master Password first.');
    }
    final rawBase64 = await _crypto.exportRawKeyBase64(key);
    await _androidChannel.enrollBiometricVaultKey(rawBase64);

    final updatedPrefs =
        state.localPreferences.copyWith(biometricUnlockEnabled: true);
    await _offlineStore.saveLocalPrefs(uid, updatedPrefs);

    state = state.copyWith(
      localPreferences: updatedPrefs,
      hasBiometricEnrolledKey: true,
    );
    await _syncAutofillCacheIfEnabled(state.decryptedRecords);
  }

  Future<void> disableBiometricUnlock() async {
    final uid = state.authUser?.uid;
    await _androidChannel.clearBiometricVaultKey();
    await _androidChannel.clearAutofillIndex();

    if (uid != null) {
      final updatedPrefs =
          state.localPreferences.copyWith(biometricUnlockEnabled: false);
      await _offlineStore.saveLocalPrefs(uid, updatedPrefs);
      state = state.copyWith(
        localPreferences: updatedPrefs,
        hasBiometricEnrolledKey: false,
      );
    }
  }

  Future<void> unlockWithBiometrics() async {
    final uid = state.authUser?.uid;
    try {
      final dekBase64 = await _androidChannel.unlockBiometricVaultKey();
      final key = _crypto.importRawKeyBase64(dekBase64);
      _vaultKey = key;
      _resetInactivityTimer();
      state = state.copyWith(
        isVaultUnlocked: true,
        clearLockBanner: true,
      );
      await _decryptAllInMemory(state.encryptedRecords);
    } on BiometricAuthException catch (e) {
      if (e.isInvalidated && uid != null) {
        final updatedPrefs =
            state.localPreferences.copyWith(biometricUnlockEnabled: false);
        await _offlineStore.saveLocalPrefs(uid, updatedPrefs);
        await _androidChannel.clearAutofillIndex();
        state = state.copyWith(
          localPreferences: updatedPrefs,
          hasBiometricEnrolledKey: false,
        );
      }
      rethrow;
    }
  }

  // --- Session Lock & Lifecycle Security ---

  void onUserActivity() {
    if (_vaultKey != null) {
      _resetInactivityTimer();
    }
  }

  void onAppLifecycleChanged(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused &&
        state.localPreferences.lockOnBackground &&
        _vaultKey != null) {
      lockVault(reason: 'Vault locked automatically when moved to background.');
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_vaultKey == null) return;
    final minutes = state.securitySettings.autoLockMinutes
        .clamp(VaultConstants.minAutoLockMinutes, VaultConstants.maxAutoLockMinutes);
    _inactivityTimer = Timer(Duration(minutes: minutes), () {
      lockVault(reason: 'Vault locked automatically after inactivity.');
    });
  }

  void lockVault({String? reason}) {
    _clearInMemorySecrets();
    state = state.copyWith(
      isVaultUnlocked: false,
      decryptedRecords: const [],
      clearPendingRecoveryKey: true,
      lockBannerMessage: reason,
    );
  }

  void _clearInMemorySecrets() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _vaultKey = null;
  }

  Future<void> signOut() async {
    final uid = state.authUser?.uid;
    _clearInMemorySecrets();
    _clipboardTimer?.cancel();
    await _androidChannel.clearClipboardNow();
    await _androidChannel.clearBiometricVaultKey();
    await _androidChannel.clearAutofillIndex();
    if (uid != null) {
      await _offlineStore.clearAllForUser(uid);
    }
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Ignore if signed in via email/password
    }
    await _auth.signOut();
  }

  // --- Record CRUD & Password History ---

  Future<void> saveRecord(
    VaultRecordPayload payload, {
    String? existingId,
  }) async {
    final uid = state.authUser?.uid;
    final key = _vaultKey;
    final cfg = state.masterConfig;
    if (uid == null || key == null || cfg == null) {
      throw StateError('Vault must be unlocked before saving.');
    }

    var effectivePayload = payload;
    DateTime baseUpdatedAt = DateTime.now();

    if (existingId != null) {
      final existing = state.decryptedRecords
          .where((r) => r.id == existingId)
          .firstOrNull;
      if (existing != null) {
        baseUpdatedAt = existing.updatedAt;
        if (existing.password.isNotEmpty &&
            existing.password != payload.password &&
            payload.password.isNotEmpty) {
          final updatedHistory = [
            PasswordHistoryEntry(
              password: existing.password,
              changedAtIso: existing.updatedAt.toUtc().toIso8601String(),
            ),
            ...payload.passwordHistory,
          ].take(VaultConstants.maxPasswordHistoryEntries).toList();
          effectivePayload = payload.copyWith(passwordHistory: updatedHistory);
        }
      }
    }

    try {
      if (existingId == null) {
        await _repo.createEncryptedRecord(
          uid: uid,
          vaultKey: key,
          keyVersion: cfg.keyVersion,
          payload: effectivePayload,
        );
      } else {
        await _repo.updateEncryptedRecord(
          uid: uid,
          credentialId: existingId,
          vaultKey: key,
          keyVersion: cfg.keyVersion,
          payload: effectivePayload,
        );
      }
    } catch (_) {
      // Queue encrypted offline mutation instead of losing user's work
      final id = existingId ?? _crypto.generateCredentialId();
      final enc = await _crypto.encryptVaultRecordPayload(key, effectivePayload);
      final now = DateTime.now();
      final offlineRec = EncryptedVaultRecord(
        id: id,
        userId: uid,
        ciphertext: enc.ciphertext,
        iv: enc.iv,
        keyVersion: cfg.keyVersion,
        createdAt: now,
        updatedAt: now,
      );

      final currentSnap = await _offlineStore.loadSnapshot(uid);
      final updatedRecords = List<EncryptedVaultRecord>.from(
        state.encryptedRecords.where((r) => r.id != id),
      )..insert(0, offlineRec);

      final updatedMutations = [
        ...(currentSnap?.pendingMutations ?? const []),
        PendingOfflineMutation(
          credentialId: id,
          type: existingId == null
              ? PendingMutationType.create
              : PendingMutationType.update,
          encryptedRecord: offlineRec,
          baseRemoteUpdatedAt: baseUpdatedAt,
          queuedAt: now,
        ),
      ];

      await _offlineStore.saveSnapshot(
        OfflineVaultSnapshot(
          uid: uid,
          masterConfig: cfg,
          encryptedRecords: updatedRecords,
          pendingMutations: updatedMutations,
          syncedAt: now,
        ),
      );
      state = state.copyWith(
        encryptedRecords: updatedRecords,
        pendingOfflineMutationCount: updatedMutations.length,
        syncState: OfflineSyncState.offlineCached,
      );
      await _decryptAllInMemory(updatedRecords);
    }
  }

  Future<void> markRecordAccessed(DecryptedVaultRecord record) async {
    final uid = state.authUser?.uid;
    final key = _vaultKey;
    final cfg = state.masterConfig;
    if (uid == null || key == null || cfg == null || record.decryptionError) {
      return;
    }
    try {
      final updated = record.payload.copyWith(
        lastAccessedAtIso: DateTime.now().toUtc().toIso8601String(),
      );
      await _repo.updateEncryptedRecord(
        uid: uid,
        credentialId: record.id,
        vaultKey: key,
        keyVersion: cfg.keyVersion,
        payload: updated,
      );
    } catch (_) {
      // Best-effort offline tolerance
    }
  }

  Future<void> toggleFavorite(DecryptedVaultRecord record) async {
    await saveRecord(
      record.payload.copyWith(isFavorite: !record.payload.isFavorite),
      existingId: record.id,
    );
  }

  Future<void> deleteRecord(String credentialId) async {
    final uid = state.authUser?.uid;
    if (uid == null) return;
    await _repo.deleteEncryptedRecord(uid: uid, credentialId: credentialId);
  }

  Future<void> resolveSyncConflict(
    SyncConflictItem conflict, {
    required bool keepLocalVersion,
  }) async {
    final uid = state.authUser?.uid;
    final key = _vaultKey;
    final cfg = state.masterConfig;
    if (uid == null || key == null || cfg == null) return;

    if (keepLocalVersion) {
      final localPayload = await _crypto.decryptVaultRecordPayload(
        key,
        conflict.localRecord.ciphertext,
        conflict.localRecord.iv,
      );
      await _repo.updateEncryptedRecord(
        uid: uid,
        credentialId: conflict.recordId,
        vaultKey: key,
        keyVersion: cfg.keyVersion,
        payload: localPayload,
      );
    }

    final snapshot = await _offlineStore.loadSnapshot(uid);
    if (snapshot != null) {
      final cleaned = snapshot.pendingMutations
          .where((m) => m.credentialId != conflict.recordId)
          .toList();
      await _offlineStore.saveSnapshot(
        OfflineVaultSnapshot(
          uid: uid,
          masterConfig: snapshot.masterConfig,
          encryptedRecords: snapshot.encryptedRecords,
          pendingMutations: cleaned,
          syncedAt: DateTime.now(),
        ),
      );
      state = state.copyWith(
        pendingOfflineMutationCount: cleaned.length,
        syncConflicts: state.syncConflicts
            .where((c) => c.recordId != conflict.recordId)
            .toList(),
        syncState: OfflineSyncState.synced,
      );
    }
  }

  // --- Clipboard Safety ---

  Future<void> copySensitiveValue(
    String value, {
    required String label,
    bool isSensitive = true,
  }) async {
    final clearSeconds = state.securitySettings.clipboardClearSeconds;
    await _androidChannel.copySensitiveText(
      text: value,
      isSensitive: isSensitive,
      clearAfterSeconds: clearSeconds,
    );

    _clipboardTimer?.cancel();
    if (!isSensitive) {
      state = state.copyWith(
        clipboardSecondsLeft: 0,
        clearClipboardLabel: true,
      );
      return;
    }

    state = state.copyWith(
      clipboardSecondsLeft: clearSeconds,
      lastCopiedLabel: label,
    );

    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = state.clipboardSecondsLeft - 1;
      if (next <= 0) {
        timer.cancel();
        _androidChannel.clearClipboardNow();
        state = state.copyWith(
          clipboardSecondsLeft: 0,
          clearClipboardLabel: true,
        );
      } else {
        state = state.copyWith(clipboardSecondsLeft: next);
      }
    });
  }

  Future<void> clearClipboardNow() async {
    _clipboardTimer?.cancel();
    _clipboardTimer = null;
    await _androidChannel.clearClipboardNow();
    if (mounted) {
      state = state.copyWith(
        clipboardSecondsLeft: 0,
        clearClipboardLabel: true,
      );
    }
  }

  // --- Settings & Key Rotation ---

  Future<void> updateCloudSecuritySettings({
    required int autoLockMinutes,
    required int clipboardClearSeconds,
    required bool requireReauthForReveal,
  }) async {
    final uid = state.authUser?.uid;
    if (uid == null) return;
    await _repo.updateSecuritySettings(
      uid: uid,
      autoLockMinutes: autoLockMinutes,
      clipboardClearSeconds: clipboardClearSeconds,
      requireReauthForReveal: requireReauthForReveal,
    );
    state = state.copyWith(
      securitySettings: state.securitySettings.copyWith(
        autoLockMinutes: autoLockMinutes,
        clipboardClearSeconds: clipboardClearSeconds,
        requireReauthForReveal: requireReauthForReveal,
      ),
    );
    _resetInactivityTimer();
  }

  Future<void> updateLocalDevicePreferences(
    LocalDevicePreferences nextPrefs,
  ) async {
    final uid = state.authUser?.uid;
    await _androidChannel
        .setScreenshotProtection(nextPrefs.screenshotProtectionEnabled);
    if (!nextPrefs.autofillIndexSyncEnabled) {
      await _androidChannel.clearAutofillIndex();
    }
    if (uid != null) {
      await _offlineStore.saveLocalPrefs(uid, nextPrefs);
    }
    state = state.copyWith(localPreferences: nextPrefs);
    if (nextPrefs.autofillIndexSyncEnabled && _vaultKey != null) {
      await _syncAutofillCacheIfEnabled(state.decryptedRecords);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final uid = state.authUser?.uid;
    if (uid == null) return;
    await _repo.updateDisplayName(uid: uid, displayName: displayName);
    state = state.copyWith(
      userProfile: state.userProfile?.copyWith(displayName: displayName.trim()),
    );
  }

  Future<void> changeMasterPassword({
    String? currentMasterPassword,
    String? recoveryKey,
    required String newMasterPassword,
  }) async {
    final uid = state.authUser?.uid;
    final cfg = state.masterConfig;
    if (uid == null || cfg == null) {
      throw StateError('Vault configuration unavailable.');
    }

    final rotated = await _crypto.rotateMasterPasswordWrapper(
      currentMasterPassword: currentMasterPassword,
      recoveryKey: recoveryKey,
      newMasterPassword: newMasterPassword,
      config: cfg,
    );

    await _repo.updateMasterWrapper(uid: uid, rotation: rotated);
    _vaultKey = rotated.vaultKey;

    final updatedCfg = VaultMasterConfig(
      userId: cfg.userId,
      kdfAlgorithm: rotated.kdfAlgorithm,
      kdfMemoryKiB: rotated.kdfMemoryKiB,
      kdfIterations: rotated.kdfIterations,
      kdfParallelism: rotated.kdfParallelism,
      masterSalt: rotated.masterSalt,
      wrappedVaultKey: rotated.wrappedVaultKey,
      wrappedVaultKeyIv: rotated.wrappedVaultKeyIv,
      recoverySalt: cfg.recoverySalt,
      recoveryWrappedVaultKey: cfg.recoveryWrappedVaultKey,
      recoveryWrappedVaultKeyIv: cfg.recoveryWrappedVaultKeyIv,
      recoveryKeyHint: cfg.recoveryKeyHint,
      keyVersion: rotated.keyVersion,
    );
    state = state.copyWith(masterConfig: updatedCfg);

    if (state.hasBiometricEnrolledKey) {
      final raw = await _crypto.exportRawKeyBase64(rotated.vaultKey);
      await _androidChannel.enrollBiometricVaultKey(raw);
    }
  }

  Future<String> regenerateRecoveryKey(String currentMasterPassword) async {
    final uid = state.authUser?.uid;
    final cfg = state.masterConfig;
    if (uid == null || cfg == null) {
      throw StateError('Vault configuration unavailable.');
    }
    final rotated = await _crypto.rotateRecoveryKeyWrapper(
      currentMasterPassword,
      cfg,
    );
    await _repo.updateRecoveryWrapper(uid: uid, rotation: rotated);

    final updatedCfg = VaultMasterConfig(
      userId: cfg.userId,
      kdfAlgorithm: cfg.kdfAlgorithm,
      kdfMemoryKiB: cfg.kdfMemoryKiB,
      kdfIterations: cfg.kdfIterations,
      kdfParallelism: cfg.kdfParallelism,
      masterSalt: cfg.masterSalt,
      wrappedVaultKey: cfg.wrappedVaultKey,
      wrappedVaultKeyIv: cfg.wrappedVaultKeyIv,
      recoverySalt: rotated.recoverySalt,
      recoveryWrappedVaultKey: rotated.recoveryWrappedVaultKey,
      recoveryWrappedVaultKeyIv: rotated.recoveryWrappedVaultKeyIv,
      recoveryKeyHint: rotated.recoveryKeyHint,
      keyVersion: cfg.keyVersion,
    );
    state = state.copyWith(masterConfig: updatedCfg);
    return rotated.recoveryKey;
  }

  // --- Security Center K-Anonymity Scan ---

  SecurityAuditReport buildSecurityReport() => _auditService.runAudit(
        state.decryptedRecords,
        externalBreachCountsByRecordId: state.externalBreachCounts,
        lastExternalScanAt: state.lastExternalBreachScanAt,
      );

  Future<void> runExternalBreachScan() async {
    if (!state.isVaultUnlocked) return;
    state = state.copyWith(isRunningBreachScan: true);
    try {
      final counts = await _auditService
          .checkPasswordsWithKAnonymity(state.decryptedRecords);
      if (!mounted) return;
      state = state.copyWith(
        externalBreachCounts: counts,
        lastExternalBreachScanAt: DateTime.now(),
        isRunningBreachScan: false,
      );
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isRunningBreachScan: false);
      }
      rethrow;
    }
  }

  // --- Encrypted Backup & Restore ---

  Future<String> exportEncryptedBackup(String backupPassphrase) =>
      _backupService.exportEncryptedBackupJson(
        records: state.decryptedRecords,
        backupPassphrase: backupPassphrase,
      );

  Future<int> restoreEncryptedBackup({
    required String rawJson,
    required String backupPassphrase,
  }) async {
    final result = await _backupService.decryptBackupJson(
      rawJson: rawJson,
      backupPassphrase: backupPassphrase,
    );

    final existingById = {
      for (final r in state.decryptedRecords) r.id: r,
    };

    var importedCount = 0;
    for (final entry in result.entries) {
      final existing = existingById[entry.id];
      if (existing == null) {
        await saveRecord(entry.payload);
        importedCount++;
      } else if (entry.updatedAt.isAfter(existing.updatedAt)) {
        await saveRecord(entry.payload, existingId: existing.id);
        importedCount++;
      }
    }
    return importedCount;
  }

  // --- Zero-Knowledge Sharing & Emergency Access Foundation ---

  Future<SealedShareResult> createEphemeralShare({
    required DecryptedVaultRecord record,
    required String recipientLabel,
    required Duration expiresIn,
    String? optionalPasscode,
  }) async {
    final uid = state.authUser?.uid;
    final res = await _sharingService.createEphemeralShare(
      record: record,
      expiresIn: expiresIn,
      optionalPasscode: optionalPasscode,
    );

    if (uid != null) {
      final updatedLedger = [
        ShareLedgerEntry(
          shareId: res.package.shareId,
          recordId: record.id,
          recordTitle: record.title,
          recipientLabel: recipientLabel.trim().isEmpty
              ? 'External Recipient'
              : recipientLabel.trim(),
          createdAt: DateTime.now(),
          expiresAt: res.package.expiresAt ?? DateTime.now().add(expiresIn),
        ),
        ...state.shareLedger,
      ];
      await _offlineStore.saveShareLedger(uid, updatedLedger);
      state = state.copyWith(shareLedger: updatedLedger);
    }
    return res;
  }

  Future<void> revokeShareLocally(String shareId) async {
    final uid = state.authUser?.uid;
    final updated = state.shareLedger
        .map((e) => e.shareId == shareId ? e.copyWith(revokedLocally: true) : e)
        .toList();
    if (uid != null) {
      await _offlineStore.saveShareLedger(uid, updated);
    }
    state = state.copyWith(shareLedger: updated);
  }

  Future<void> saveEmergencyContact({
    required String contactName,
    required String contactEmail,
    required int waitingPeriodHours,
  }) async {
    final uid = state.authUser?.uid;
    final cfg = EmergencyContactConfig(
      contactName: contactName.trim(),
      contactEmail: contactEmail.trim(),
      waitingPeriodHours: waitingPeriodHours,
      status: EmergencyAccessStatus.configured,
      updatedAt: DateTime.now(),
    );
    if (uid != null) {
      await _offlineStore.saveEmergencyConfig(uid, cfg);
    }
    state = state.copyWith(emergencyConfig: cfg);
  }

  Future<void> updateEmergencyStatus(EmergencyAccessStatus status) async {
    final uid = state.authUser?.uid;
    final cfg = state.emergencyConfig.copyWith(
      status: status,
      requestedAt: status == EmergencyAccessStatus.requestPendingWaitingPeriod
          ? DateTime.now()
          : state.emergencyConfig.requestedAt,
      clearRequestedAt: status == EmergencyAccessStatus.configured ||
          status == EmergencyAccessStatus.denied,
      updatedAt: DateTime.now(),
    );
    if (uid != null) {
      await _offlineStore.saveEmergencyConfig(uid, cfg);
    }
    state = state.copyWith(emergencyConfig: cfg);
  }

  Future<String> generateEmergencyRecoveryBundle({
    required String currentMasterPassword,
    required String contactEscrowPassphrase,
  }) async {
    final cfg = state.masterConfig;
    if (cfg == null) throw StateError('Vault configuration unavailable.');

    final rotatedRecovery = await regenerateRecoveryKey(currentMasterPassword);
    return _sharingService.generateEmergencyEscrowBundle(
      vaultConfig: cfg,
      contactConfig: state.emergencyConfig,
      contactEscrowPassphrase: contactEscrowPassphrase,
      currentRecoveryKey: rotatedRecovery,
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _recordsSub?.cancel();
    _inactivityTimer?.cancel();
    _clipboardTimer?.cancel();
    _clearInMemorySecrets();
    super.dispose();
  }
}
