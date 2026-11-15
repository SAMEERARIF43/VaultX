import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/vault_constants.dart';
import '../models/security_audit_models.dart';
import '../models/vault_record.dart';
import '../models/vault_record_type.dart';
import 'password_generator_service.dart';

class SecurityAuditService {
  static const Set<String> _knownWeakPasswords = {
    '123456',
    '12345678',
    '123456789',
    '1234567890',
    'password',
    'password1',
    'password123',
    'p@ssword',
    'p@ssw0rd',
    'qwerty',
    'qwerty123',
    'qwertyuiop',
    'admin',
    'admin123',
    'administrator',
    'letmein',
    'welcome',
    'welcome123',
    'monkey',
    'dragon',
    'master',
    'football',
    'baseball',
    'iloveyou',
    'trustno1',
    'sunshine',
    'princess',
    'abc123',
    '111111',
    '000000',
    'passw0rd',
    'changeme',
    'secret',
    'login',
    'default',
    'guest',
    'root',
    'toor',
    'zaq12wsx',
    '1qaz2wsx',
    'test123',
    'vaultx',
    'superman',
    'batman',
  };

  final PasswordGeneratorService _passwordService;
  final http.Client _httpClient;

  SecurityAuditService({
    PasswordGeneratorService? passwordService,
    http.Client? httpClient,
  })  : _passwordService = passwordService ?? PasswordGeneratorService(),
        _httpClient = httpClient ?? http.Client();

  /// Runs a 100% local zero-knowledge security audit across decrypted records.
  /// Optionally merges verified k-anonymity external breach results ([externalBreachCountsByRecordId]).
  SecurityAuditReport runAudit(
    List<DecryptedVaultRecord> records, {
    Map<String, int> externalBreachCountsByRecordId = const {},
    DateTime? lastExternalScanAt,
  }) {
    final validRecords = records.where((r) => !r.decryptionError).toList();
    final passwordAccounts = validRecords
        .where(
          (r) =>
              r.recordType == VaultRecordType.login ||
              r.recordType == VaultRecordType.appLogin ||
              r.password.isNotEmpty,
        )
        .toList();

    final weakPasswords = <SecurityIssueItem>[];
    final localCompromised = <SecurityIssueItem>[];
    final externalBreached = <SecurityIssueItem>[];
    final oldPasswords = <SecurityIssueItem>[];
    final expiringPasswords = <SecurityIssueItem>[];
    final missingInfo = <SecurityIssueItem>[];
    final passwordBuckets = <String, List<DecryptedVaultRecord>>{};

    final now = DateTime.now();
    const staleDuration = Duration(days: VaultConstants.stalePasswordDays);

    for (final rec in passwordAccounts) {
      final pw = rec.password;
      final lowerPw = pw.toLowerCase();

      if (pw.isNotEmpty) {
        passwordBuckets.putIfAbsent(pw, () => []).add(rec);
      }

      // 1. Local compromised dictionary / username inclusion
      final emailPrefix = rec.username.contains('@')
          ? rec.username.split('@').first.toLowerCase()
          : rec.username.toLowerCase();
      final containsUsername =
          emailPrefix.length >= 4 && lowerPw.contains(emailPrefix);

      if (_knownWeakPasswords.contains(lowerPw)) {
        localCompromised.add(
          SecurityIssueItem(
            record: rec,
            reason: 'Matches an offline corpus of commonly breached passwords.',
            recommendation: 'Replace immediately using a 20+ character generated password.',
            severity: IssueSeverity.high,
            source: BreachCheckSource.localHeuristic,
          ),
        );
      } else if (containsUsername) {
        localCompromised.add(
          SecurityIssueItem(
            record: rec,
            reason: 'Password contains your username or email prefix.',
            recommendation: 'Generate a completely unrelated random password.',
            severity: IssueSeverity.high,
            source: BreachCheckSource.localHeuristic,
          ),
        );
      }

      // 2. External k-anonymity verified breaches (explicitly distinguished from local checks)
      final breachCount = externalBreachCountsByRecordId[rec.id];
      if (breachCount != null && breachCount > 0) {
        externalBreached.add(
          SecurityIssueItem(
            record: rec,
            reason:
                'Seen $breachCount time${breachCount == 1 ? '' : 's'} in HaveIBeenPwned breach corpus (verified via k-anonymity SHA-1 prefix).',
            recommendation: 'Rotate this password on the website immediately and enable 2FA.',
            severity: IssueSeverity.high,
            source: BreachCheckSource.hibpKAnonymity,
            externalBreachCount: breachCount,
          ),
        );
      }

      // 3. Strength evaluation
      final strength = _passwordService.evaluateStrength(pw);
      if (strength.score <= 1) {
        weakPasswords.add(
          SecurityIssueItem(
            record: rec,
            reason:
                '${strength.label} (${strength.entropyBits} bits entropy, ${pw.length} chars).',
            recommendation: 'Upgrade to at least 16 random characters.',
            severity: IssueSeverity.high,
          ),
        );
      } else if (strength.score == 2) {
        weakPasswords.add(
          SecurityIssueItem(
            record: rec,
            reason:
                'Fair strength (${strength.entropyBits} bits entropy) — could be stronger.',
            recommendation: 'Increase length or add symbols for high-value accounts.',
            severity: IssueSeverity.medium,
          ),
        );
      }

      // 4. Stale / Old passwords (> 180 days)
      final age = now.difference(rec.updatedAt);
      if (age > staleDuration) {
        oldPasswords.add(
          SecurityIssueItem(
            record: rec,
            reason: 'Last updated ${age.inDays} days ago.',
            recommendation: 'Rotate credentials older than ${VaultConstants.stalePasswordDays} days.',
            severity: IssueSeverity.low,
          ),
        );
      }

      // 5. Configured password expiration reminders
      final expiresAt = rec.payload.expiresAt;
      if (expiresAt != null) {
        final daysUntil = expiresAt.difference(now).inDays;
        if (expiresAt.isBefore(now)) {
          expiringPasswords.add(
            SecurityIssueItem(
              record: rec,
              reason: 'Password rotation reminder expired ${(-daysUntil)} day(s) ago.',
              recommendation: 'Update password now and set next rotation date.',
              severity: IssueSeverity.high,
            ),
          );
        } else if (daysUntil <= 14) {
          expiringPasswords.add(
            SecurityIssueItem(
              record: rec,
              reason: 'Password rotation reminder due in $daysUntil day(s).',
              recommendation: 'Schedule rotation before expiration.',
              severity: IssueSeverity.medium,
            ),
          );
        }
      }

      // 6. Missing security metadata
      final missingReasons = <String>[];
      if (rec.url.trim().isEmpty &&
          (rec.payload.packageName ?? '').trim().isEmpty) {
        missingReasons.add('Missing website URL or app package name');
      }
      if (rec.username.trim().isEmpty) {
        missingReasons.add('Missing username or email');
      }
      if (missingReasons.isNotEmpty) {
        missingInfo.add(
          SecurityIssueItem(
            record: rec,
            reason: missingReasons.join(' · '),
            recommendation: 'Add website domain or package name so Android Autofill can match safely.',
            severity: IssueSeverity.low,
          ),
        );
      }
    }

    final reusedGroups = <ReusedPasswordGroup>[];
    var reusedCount = 0;
    for (final group in passwordBuckets.values) {
      if (group.length > 1) {
        reusedGroups.add(ReusedPasswordGroup(records: group, count: group.length));
        reusedCount += group.length;
      }
    }

    final recentlyUpdated = List<DecryptedVaultRecord>.from(validRecords)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    var healthPercentage = 100;
    if (passwordAccounts.isNotEmpty) {
      final compromisedPenalty =
          (localCompromised.length + externalBreached.length) * 25;
      final weakPenalty = weakPasswords.length * 14;
      final reusedPenalty = max(0, reusedCount - reusedGroups.length) * 12;
      final agePenalty = oldPasswords.length * 4;
      final missingPenalty = missingInfo.length * 3;
      final totalPenalty = compromisedPenalty +
          weakPenalty +
          reusedPenalty +
          agePenalty +
          missingPenalty;
      final divisor =
          passwordAccounts.length / 2 > 1 ? passwordAccounts.length / 2 : 1.0;
      healthPercentage = (100 - totalPenalty / divisor).round().clamp(0, 100);
    }

    return SecurityAuditReport(
      totalVaultRecords: validRecords.length,
      totalPasswordAccounts: passwordAccounts.length,
      weakPasswords: weakPasswords,
      reusedGroups: reusedGroups,
      reusedCount: reusedCount,
      localCompromisedPasswords: localCompromised,
      externalBreachedPasswords: externalBreached,
      oldPasswords: oldPasswords,
      expiringOrExpiredPasswords: expiringPasswords,
      missingInfoAccounts: missingInfo,
      recentlyUpdated: recentlyUpdated.take(8).toList(),
      healthPercentage: healthPercentage,
      lastExternalBreachScanAt: lastExternalScanAt,
    );
  }

  /// Privacy-preserving HaveIBeenPwned k-anonymity check.
  ///
  /// Computes SHA-1 locally, sends ONLY the 5-character hex prefix to HIBP Range API
  /// with `Add-Padding: true`, and matches the remaining 35-character suffix locally.
  /// Plaintext passwords NEVER leave the device.
  Future<Map<String, int>> checkPasswordsWithKAnonymity(
    List<DecryptedVaultRecord> records,
  ) async {
    final prefixCache = <String, Map<String, int>>{};
    final results = <String, int>{};

    for (final rec in records) {
      if (rec.decryptionError || rec.password.isEmpty) continue;

      final sha1Digest = await Sha1().hash(utf8.encode(rec.password));
      final hex = sha1Digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      final prefix = hex.substring(0, 5);
      final suffix = hex.substring(5);

      Map<String, int> suffixMap;
      if (prefixCache.containsKey(prefix)) {
        suffixMap = prefixCache[prefix]!;
      } else {
        final uri = Uri.parse('${VaultConstants.hibpRangeApiBase}$prefix');
        final response = await _httpClient.get(
          uri,
          headers: const {
            'Add-Padding': 'true',
            'User-Agent': 'VaultX-Android-SecurityAudit',
          },
        );
        if (response.statusCode != 200) {
          throw Exception(
            'Breach range lookup failed with status ${response.statusCode}.',
          );
        }
        suffixMap = _parseHibpRangeResponse(response.body);
        prefixCache[prefix] = suffixMap;
      }

      final count = suffixMap[suffix] ?? 0;
      if (count > 0) {
        results[rec.id] = count;
      }
    }

    return results;
  }

  Map<String, int> _parseHibpRangeResponse(String body) {
    final map = <String, int>{};
    for (final line in LineSplitter.split(body)) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final suffix = line.substring(0, idx).trim().toUpperCase();
      final count = int.tryParse(line.substring(idx + 1).trim()) ?? 0;
      if (count > 0) {
        map[suffix] = count;
      }
    }
    return map;
  }

  int max(int a, int b) => a > b ? a : b;
}
