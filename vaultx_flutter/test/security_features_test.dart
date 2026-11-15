import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:vaultx_flutter/core/constants/vault_constants.dart';
import 'package:vaultx_flutter/core/errors/vault_exceptions.dart';
import 'package:vaultx_flutter/data/repositories/offline_vault_store.dart';
import 'package:vaultx_flutter/domain/models/security_audit_models.dart';
import 'package:vaultx_flutter/domain/models/sharing_emergency_models.dart';
import 'package:vaultx_flutter/domain/models/vault_models.dart';
import 'package:vaultx_flutter/domain/models/vault_record.dart';
import 'package:vaultx_flutter/domain/models/vault_record_type.dart';
import 'package:vaultx_flutter/domain/models/wallet_details.dart';
import 'package:vaultx_flutter/domain/services/backup_service.dart';
import 'package:vaultx_flutter/domain/services/crypto_service.dart';
import 'package:vaultx_flutter/domain/services/domain_matching_service.dart';
import 'package:vaultx_flutter/domain/services/password_generator_service.dart';
import 'package:vaultx_flutter/domain/services/security_audit_service.dart';
import 'package:vaultx_flutter/domain/services/sharing_emergency_service.dart';
import 'package:vaultx_flutter/domain/services/totp_service.dart';

class _InMemoryBlobStorage implements OfflineBlobStorageDelegate {
  final Map<String, String> _store = {};

  Map<String, String> get rawEntries => Map.unmodifiable(_store);

  @override
  Future<void> writeProtected(String key, String rawJson) async {
    _store[key] = rawJson;
  }

  @override
  Future<String?> readProtected(String key) async => _store[key];

  @override
  Future<void> deleteProtected(String key) async {
    _store.remove(key);
  }
}

void main() {
  group('RFC 6238 TOTP Authenticator Engine', () {
    final totpService = TotpService();

    test('matches official RFC 6238 SHA-1 8-digit test vectors', () async {
      // RFC 6238 ASCII seed "12345678901234567890" -> Base32 "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
      const details = TotpDetails(
        issuer: 'RFC6238',
        accountName: 'test@vaultx.app',
        secretBase32: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        algorithm: TotpAlgorithm.sha1,
        digits: 8,
        periodSeconds: 30,
      );

      final codeAt59 = await totpService.generateCode(
        details,
        timestamp: DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true),
      );
      expect(codeAt59, '94287082');

      final codeAt1111111109 = await totpService.generateCode(
        details,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000, isUtc: true),
      );
      expect(codeAt1111111109, '07081804');
    });

    test('parses and builds otpauth://totp URIs and rejects invalid ones', () {
      const uri =
          'otpauth://totp/GitHub:alice%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA256&digits=6&period=30';
      final parsed = totpService.parseOtpAuthUri(uri);

      expect(parsed.issuer, 'GitHub');
      expect(parsed.accountName, 'alice@example.com');
      expect(parsed.secretBase32, 'JBSWY3DPEHPK3PXP');
      expect(parsed.algorithm, TotpAlgorithm.sha256);
      expect(parsed.digits, 6);
      expect(parsed.periodSeconds, 30);

      final rebuilt = totpService.parseOtpAuthUri(
        totpService.buildOtpAuthUri(parsed),
      );
      expect(rebuilt.secretBase32, parsed.secretBase32);
      expect(rebuilt.issuer, parsed.issuer);

      expect(
        () => totpService.parseOtpAuthUri('https://example.com?secret=ABC'),
        throwsA(isA<TotpException>()),
      );
      expect(
        () => totpService.parseOtpAuthUri('otpauth://totp/Test?secret=INVALID!'),
        throwsA(isA<TotpException>()),
      );
    });
  });

  group('Cryptographically Secure Password & Passphrase Generator', () {
    final generator = PasswordGeneratorService();

    test('enforces character pools, length, ambiguous exclusion, and randomness',
        () {
      const opts = PasswordGeneratorOptions(
        length: 22,
        uppercase: true,
        lowercase: true,
        numbers: true,
        symbols: true,
        excludeAmbiguous: true,
      );

      final generated = <String>{};
      for (var i = 0; i < 25; i++) {
        final pw = generator.generate(opts);
        expect(pw.length, 22);
        expect(RegExp(r'[A-Z]').hasMatch(pw), isTrue);
        expect(RegExp(r'[a-z]').hasMatch(pw), isTrue);
        expect(RegExp(r'[0-9]').hasMatch(pw), isTrue);
        expect(RegExp(r'[^a-zA-Z0-9]').hasMatch(pw), isTrue);
        expect(RegExp(r'[0Oo1lI|]').hasMatch(pw), isFalse);
        generated.add(pw);
      }
      expect(generated.length, 25);
    });

    test('generates memorable multi-word passphrases & evaluates strength', () {
      final phrase = generator.generatePassphrase(
        wordCount: 5,
        separator: '-',
        capitalizeWords: true,
        includeNumber: true,
      );
      final parts = phrase.split('-');
      expect(parts.length, 5);
      expect(RegExp(r'\d{2}$').hasMatch(parts.join()), isTrue);

      final weak = generator.evaluateStrength('123456');
      final strong = generator.evaluateStrength('X#9kLm!2Qp7vR@4zT8wN');
      expect(weak.score, lessThanOrEqualTo(1));
      expect(strong.score, 4);
    });
  });

  group('Strict Domain & Android Package Autofill Matching', () {
    final matcher = DomainMatchingService();
    final now = DateTime.utc(2026, 11, 1);

    final records = [
      DecryptedVaultRecord(
        id: 'gh',
        keyVersion: 1,
        createdAt: now,
        updatedAt: now,
        payload: const VaultRecordPayload(
          title: 'GitHub',
          username: 'dev@vaultx.test',
          password: 'pw1',
          url: 'https://github.com/login',
          packageName: 'com.github.android',
        ),
      ),
      DecryptedVaultRecord(
        id: 'wildcard',
        keyVersion: 1,
        createdAt: now,
        updatedAt: now,
        payload: const VaultRecordPayload(
          title: 'Wildcard Bad',
          username: 'bad',
          password: 'pw2',
          url: 'https://*.github.com',
        ),
      ),
      DecryptedVaultRecord(
        id: 'note',
        keyVersion: 1,
        createdAt: now,
        updatedAt: now,
        payload: const VaultRecordPayload(
          title: 'Note',
          url: 'https://github.com',
          recordType: VaultRecordType.secureNote,
        ),
      ),
    ];

    test('matches exact domain, subdomain, and Android package; rejects spoofing',
        () {
      expect(
        matcher
            .matchRecordsForAutofill(records, webDomain: 'https://github.com')
            .map((e) => e.id),
        ['gh'],
      );
      expect(
        matcher
            .matchRecordsForAutofill(records, webDomain: 'https://gist.github.com')
            .map((e) => e.id),
        ['gh'],
      );
      expect(
        matcher
            .matchRecordsForAutofill(
              records,
              androidPackage: 'com.github.android',
            )
            .map((e) => e.id),
        ['gh'],
      );
      // Reject lookalike phishing / wrong domains
      expect(
        matcher.matchRecordsForAutofill(
          records,
          webDomain: 'https://evil-github.com',
        ),
        isEmpty,
      );
      expect(
        matcher.matchRecordsForAutofill(
          records,
          webDomain: 'https://github.com.phishing.org',
        ),
        isEmpty,
      );
    });
  });

  group('Security Audit & K-Anonymity HIBP Verification', () {
    test('sends ONLY 5-hex SHA-1 prefix and separates local vs external issues',
        () async {
      // SHA-1("123456") = 7C4A8D09CA3762AF61E59520943DC26494F8941B
      const fullSha1 = '7C4A8D09CA3762AF61E59520943DC26494F8941B';
      final expectedPrefix = fullSha1.substring(0, 5); // 7C4A8
      final expectedSuffix = fullSha1.substring(5);

      final requestedUris = <Uri>[];
      final mockClient = MockClient((request) async {
        requestedUris.add(request.url);
        expect(request.headers['Add-Padding'], 'true');
        expect(request.url.toString().contains('123456'), isFalse);
        expect(request.body, isEmpty);
        if (request.url.path.endsWith(expectedPrefix)) {
          return http.Response(
            '00000000000000000000000000000000001:2\n'
            '$expectedSuffix:4812390\n',
            200,
          );
        }
        return http.Response('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:0\n', 200);
      });

      final auditService = SecurityAuditService(httpClient: mockClient);
      final oldDate = DateTime.now().subtract(const Duration(days: 220));
      final records = [
        DecryptedVaultRecord(
          id: 'r1',
          keyVersion: 1,
          createdAt: oldDate,
          updatedAt: oldDate,
          payload: const VaultRecordPayload(
            title: 'Legacy Portal',
            username: 'alice@example.com',
            password: '123456',
          ),
        ),
        DecryptedVaultRecord(
          id: 'r2',
          keyVersion: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          payload: const VaultRecordPayload(
            title: 'Duplicate Portal',
            username: 'bob@example.com',
            password: '123456',
            url: 'https://portal.example.org',
          ),
        ),
      ];

      final breachCounts =
          await auditService.checkPasswordsWithKAnonymity(records);
      expect(requestedUris.length, 1); // Cached per 5-char prefix
      expect(requestedUris.single.toString(), endsWith('/range/$expectedPrefix'));
      expect(breachCounts['r1'], 4812390);
      expect(breachCounts['r2'], 4812390);

      final report = auditService.runAudit(
        records,
        externalBreachCountsByRecordId: breachCounts,
        lastExternalScanAt: DateTime.now(),
      );
      expect(report.externalBreachedPasswords.length, 2);
      expect(
        report.externalBreachedPasswords.first.source,
        BreachCheckSource.hibpKAnonymity,
      );
      expect(report.localCompromisedPasswords.length, 2);
      expect(report.reusedGroups.length, 1);
      expect(report.oldPasswords.length, 1);
      expect(report.missingInfoAccounts.length, 1); // r1 missing URL
    });
  });

  group('Encrypted Backup, Offline Conflicts, Sharing & Compatibility', () {
    final crypto = VaultCryptoService();
    final backupService = BackupService(cryptoService: crypto);
    final sharingService = SharingEmergencyService(cryptoService: crypto);

    test('exports/restores encrypted .vaultx archive without plaintext',
        () async {
      final now = DateTime.utc(2026, 11, 2);
      final records = [
        DecryptedVaultRecord(
          id: 'card_1',
          keyVersion: 1,
          createdAt: now,
          updatedAt: now,
          payload: const VaultRecordPayload(
            title: 'Travel Visa',
            category: 'Finance',
            recordType: VaultRecordType.paymentCard,
            card: PaymentCardDetails(
              cardholderName: 'Synthetic Holder',
              brand: 'Visa',
              cardNumber: '4111111111114242',
              expiryMonth: '12',
              expiryYear: '2029',
              cvv: '999',
            ),
          ),
        ),
      ];

      final exported = await backupService.exportEncryptedBackupJson(
        records: records,
        backupPassphrase: 'Backup-Test-Passphrase#2026',
        useIsolate: false,
      );

      expect(exported.contains('4111111111114242'), isFalse);
      expect(exported.contains('Synthetic Holder'), isFalse);
      expect(exported.contains(VaultConstants.backupFormatVersion), isTrue);

      final restored = await backupService.decryptBackupJson(
        rawJson: exported,
        backupPassphrase: 'Backup-Test-Passphrase#2026',
        useIsolate: false,
      );
      expect(restored.recordCount, 1);
      expect(restored.entries.first.payload.card?.cardNumber, '4111111111114242');

      await expectLater(
        () => backupService.decryptBackupJson(
          rawJson: exported,
          backupPassphrase: 'Wrong-Passphrase-999',
          useIsolate: false,
        ),
        throwsA(isA<InvalidMasterPasswordException>()),
      );
    });

    test('detects offline edit conflicts instead of silently overwriting cloud',
        () async {
      final storage = _InMemoryBlobStorage();
      final offlineStore = OfflineVaultStore(storage);
      final baseTime = DateTime.utc(2026, 11, 1, 10, 0);
      final cloudNewerTime = DateTime.utc(2026, 11, 1, 12, 0);

      final localRec = EncryptedVaultRecord(
        id: 'cred_conflict',
        userId: 'u1',
        ciphertext: 'localCipher',
        iv: 'localIv',
        keyVersion: 1,
        createdAt: baseTime,
        updatedAt: DateTime.utc(2026, 11, 1, 11, 0),
      );
      final remoteRec = EncryptedVaultRecord(
        id: 'cred_conflict',
        userId: 'u1',
        ciphertext: 'remoteCipher',
        iv: 'remoteIv',
        keyVersion: 1,
        createdAt: baseTime,
        updatedAt: cloudNewerTime,
      );

      await offlineStore.saveSnapshot(
        OfflineVaultSnapshot(
          uid: 'u1',
          masterConfig: null,
          encryptedRecords: [localRec],
          pendingMutations: [
            PendingOfflineMutation(
              credentialId: 'cred_conflict',
              type: PendingMutationType.update,
              encryptedRecord: localRec,
              baseRemoteUpdatedAt: baseTime,
              queuedAt: DateTime.utc(2026, 11, 1, 11, 0),
            ),
          ],
          syncedAt: baseTime,
        ),
      );

      final loaded = await offlineStore.loadSnapshot('u1');
      expect(loaded, isNotNull);
      final conflicts = offlineStore.detectConflicts(
        pending: loaded!.pendingMutations,
        remoteRecords: [remoteRec],
      );
      expect(conflicts.length, 1);
      expect(conflicts.first.recordId, 'cred_conflict');
    });

    test('seals/opens E2EE ephemeral share and rejects expired/wrong passcode',
        () async {
      final now = DateTime.utc(2026, 11, 2);
      final rec = DecryptedVaultRecord(
        id: 's1',
        keyVersion: 1,
        createdAt: now,
        updatedAt: now,
        payload: const VaultRecordPayload(
          title: 'Shared Wi-Fi',
          username: 'GuestNet',
          password: 'SharedGuestPassword!23',
        ),
      );

      final sealed = await sharingService.createEphemeralShare(
        record: rec,
        expiresIn: const Duration(hours: 2),
        optionalPasscode: '948271',
        useIsolate: false,
      );
      expect(sealed.encodedEnvelope.contains('SharedGuestPassword!23'), isFalse);

      final opened = await sharingService.openEphemeralShare(
        encodedEnvelope: sealed.encodedEnvelope,
        shareKeyBase64Url: sealed.shareKeyBase64Url,
        passcode: '948271',
        useIsolate: false,
      );
      expect(opened.password, 'SharedGuestPassword!23');

      await expectLater(
        () => sharingService.openEphemeralShare(
          encodedEnvelope: sealed.encodedEnvelope,
          shareKeyBase64Url: sealed.shareKeyBase64Url,
          passcode: '000000',
          useIsolate: false,
        ),
        throwsA(isA<CiphertextTamperedException>()),
      );

      final expired = await sharingService.createEphemeralShare(
        record: rec,
        expiresIn: const Duration(seconds: -10),
        useIsolate: false,
      );
      await expectLater(
        () => sharingService.openEphemeralShare(
          encodedEnvelope: expired.encodedEnvelope,
          shareKeyBase64Url: expired.shareKeyBase64Url,
          useIsolate: false,
        ),
        throwsA(isA<CiphertextTamperedException>()),
      );

      final escrow = await sharingService.generateEmergencyEscrowBundle(
        vaultConfig: const VaultMasterConfig(
          userId: 'u1',
          kdfAlgorithm: VaultConstants.kdfAlgorithm,
          kdfMemoryKiB: 65536,
          kdfIterations: 3,
          kdfParallelism: 1,
          masterSalt: 'AAAAAAAAAAAAAAAAAAAAAA==',
          wrappedVaultKey: 'BBBBBBBBBBBBBBBBBBBBBB==',
          wrappedVaultKeyIv: 'CCCCCCCCCCCCCCCC',
          recoverySalt: 'AAAAAAAAAAAAAAAAAAAAAA==',
          recoveryWrappedVaultKey: 'BBBBBBBBBBBBBBBBBBBBBB==',
          recoveryWrappedVaultKeyIv: 'CCCCCCCCCCCCCCCC',
          recoveryKeyHint: 'VX-TEST',
          keyVersion: 1,
        ),
        contactConfig: const EmergencyContactConfig(
          contactName: 'Trusted Contact',
          contactEmail: 'trusted@vaultx.test',
          waitingPeriodHours: 72,
          status: EmergencyAccessStatus.configured,
        ),
        contactEscrowPassphrase: 'Escrow-Trusted-Passphrase#99',
        currentRecoveryKey: 'VX-AAAA-BBBB-CCCC',
        useIsolate: false,
      );
      expect(escrow.contains('VaultX-EmergencyBundle-v1'), isTrue);
      expect(escrow.contains('VX-AAAA-BBBB-CCCC'), isFalse);
    });

    test('preserves raw DEK Base64 round-trip and Web legacy payload format',
        () async {
      final rawKey = crypto.generateRandomBytes(32);
      final key = crypto.importRawKeyBase64(base64Encode(rawKey));
      expect(
        await crypto.exportRawKeyBase64(key),
        equals(base64Encode(Uint8List.fromList(rawKey))),
      );

      final legacy = VaultRecordPayload.fromJson(const {
        'title': 'Web Record',
        'username': 'web@vaultx.test',
        'password': 'LegacyPassword!1',
        'url': 'https://web.vaultx.test',
        'category': 'Work',
        'notes': 'Saved on Web',
      });
      expect(legacy.recordType, VaultRecordType.login);
      expect(legacy.toJson()['title'], 'Web Record');
      expect(legacy.toJson().containsKey('recordType'), isFalse);
    });
  });
}
