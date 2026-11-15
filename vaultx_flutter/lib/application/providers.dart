import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/firestore_vault_repository.dart';
import '../data/repositories/offline_vault_store.dart';
import '../domain/services/backup_service.dart';
import '../domain/services/crypto_service.dart';
import '../domain/services/domain_matching_service.dart';
import '../domain/services/password_generator_service.dart';
import '../domain/services/security_audit_service.dart';
import '../domain/services/sharing_emergency_service.dart';
import '../domain/services/totp_service.dart';
import '../platform/android_security_channel.dart';
import 'vault_session_controller.dart';
import 'vault_session_state.dart';

final cryptoServiceProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});

final passwordGeneratorServiceProvider =
    Provider<PasswordGeneratorService>((ref) {
  return PasswordGeneratorService();
});

final totpServiceProvider = Provider<TotpService>((ref) {
  return TotpService();
});

final domainMatchingServiceProvider = Provider<DomainMatchingService>((ref) {
  return DomainMatchingService();
});

final securityAuditServiceProvider = Provider<SecurityAuditService>((ref) {
  return SecurityAuditService(
    passwordService: ref.watch(passwordGeneratorServiceProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(cryptoService: ref.watch(cryptoServiceProvider));
});

final sharingEmergencyServiceProvider =
    Provider<SharingEmergencyService>((ref) {
  return SharingEmergencyService(
    cryptoService: ref.watch(cryptoServiceProvider),
  );
});

final androidSecurityChannelProvider = Provider<AndroidSecurityChannel>((ref) {
  return AndroidSecurityChannel();
});

final firestoreVaultRepositoryProvider =
    Provider<FirestoreVaultRepository>((ref) {
  return FirestoreVaultRepository(
    cryptoService: ref.watch(cryptoServiceProvider),
  );
});

final offlineVaultStoreProvider = Provider<OfflineVaultStore>((ref) {
  return OfflineVaultStore(
    AndroidKeystoreBlobStorage(ref.watch(androidSecurityChannelProvider)),
  );
});

final vaultSessionProvider =
    StateNotifierProvider<VaultSessionController, VaultSessionState>((ref) {
  return VaultSessionController(
    auth: FirebaseAuth.instance,
    repo: ref.watch(firestoreVaultRepositoryProvider),
    offlineStore: ref.watch(offlineVaultStoreProvider),
    crypto: ref.watch(cryptoServiceProvider),
    auditService: ref.watch(securityAuditServiceProvider),
    backupService: ref.watch(backupServiceProvider),
    sharingService: ref.watch(sharingEmergencyServiceProvider),
    androidChannel: ref.watch(androidSecurityChannelProvider),
  );
});
