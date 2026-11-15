import 'vault_record.dart';

enum IssueSeverity { high, medium, low }

enum BreachCheckSource { localHeuristic, hibpKAnonymity }

class PasswordGeneratorOptions {
  final int length;
  final bool uppercase;
  final bool lowercase;
  final bool numbers;
  final bool symbols;
  final bool excludeAmbiguous;
  final bool passphraseMode;
  final int wordCount;
  final String wordSeparator;
  final bool capitalizeWords;
  final bool includeNumberInPassphrase;

  const PasswordGeneratorOptions({
    this.length = 20,
    this.uppercase = true,
    this.lowercase = true,
    this.numbers = true,
    this.symbols = true,
    this.excludeAmbiguous = true,
    this.passphraseMode = false,
    this.wordCount = 5,
    this.wordSeparator = '-',
    this.capitalizeWords = true,
    this.includeNumberInPassphrase = true,
  });

  PasswordGeneratorOptions copyWith({
    int? length,
    bool? uppercase,
    bool? lowercase,
    bool? numbers,
    bool? symbols,
    bool? excludeAmbiguous,
    bool? passphraseMode,
    int? wordCount,
    String? wordSeparator,
    bool? capitalizeWords,
    bool? includeNumberInPassphrase,
  }) {
    return PasswordGeneratorOptions(
      length: length ?? this.length,
      uppercase: uppercase ?? this.uppercase,
      lowercase: lowercase ?? this.lowercase,
      numbers: numbers ?? this.numbers,
      symbols: symbols ?? this.symbols,
      excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
      passphraseMode: passphraseMode ?? this.passphraseMode,
      wordCount: wordCount ?? this.wordCount,
      wordSeparator: wordSeparator ?? this.wordSeparator,
      capitalizeWords: capitalizeWords ?? this.capitalizeWords,
      includeNumberInPassphrase:
          includeNumberInPassphrase ?? this.includeNumberInPassphrase,
    );
  }
}

class PasswordStrengthResult {
  final int score; // 0..4
  final String label;
  final int entropyBits;
  final String crackTimeLabel;
  final List<String> feedback;

  const PasswordStrengthResult({
    required this.score,
    required this.label,
    required this.entropyBits,
    required this.crackTimeLabel,
    required this.feedback,
  });
}

class SecurityIssueItem {
  final DecryptedVaultRecord record;
  final String reason;
  final String recommendation;
  final IssueSeverity severity;
  final BreachCheckSource source;
  final int? externalBreachCount;

  const SecurityIssueItem({
    required this.record,
    required this.reason,
    required this.recommendation,
    required this.severity,
    this.source = BreachCheckSource.localHeuristic,
    this.externalBreachCount,
  });
}

class ReusedPasswordGroup {
  final List<DecryptedVaultRecord> records;
  final int count;

  const ReusedPasswordGroup({
    required this.records,
    required this.count,
  });
}

class SecurityAuditReport {
  final int totalVaultRecords;
  final int totalPasswordAccounts;
  final List<SecurityIssueItem> weakPasswords;
  final List<ReusedPasswordGroup> reusedGroups;
  final int reusedCount;
  final List<SecurityIssueItem> localCompromisedPasswords;
  final List<SecurityIssueItem> externalBreachedPasswords;
  final List<SecurityIssueItem> oldPasswords;
  final List<SecurityIssueItem> expiringOrExpiredPasswords;
  final List<SecurityIssueItem> missingInfoAccounts;
  final List<DecryptedVaultRecord> recentlyUpdated;
  final int healthPercentage;
  final DateTime? lastExternalBreachScanAt;

  const SecurityAuditReport({
    required this.totalVaultRecords,
    required this.totalPasswordAccounts,
    required this.weakPasswords,
    required this.reusedGroups,
    required this.reusedCount,
    required this.localCompromisedPasswords,
    required this.externalBreachedPasswords,
    required this.oldPasswords,
    required this.expiringOrExpiredPasswords,
    required this.missingInfoAccounts,
    required this.recentlyUpdated,
    required this.healthPercentage,
    this.lastExternalBreachScanAt,
  });
}
