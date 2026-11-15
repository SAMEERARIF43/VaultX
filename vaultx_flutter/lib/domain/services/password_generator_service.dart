import 'dart:math';

import '../models/security_audit_models.dart';

class PasswordGeneratorService {
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _numbers = '0123456789';
  static const String _symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';
  static const Set<String> _ambiguous = {'0', 'O', 'o', '1', 'l', 'I', '|'};

  // Curated 128-word memorable passphrase wordlist (~7 bits of entropy per word).
  static const List<String> _passphraseWords = [
    'acorn', 'almond', 'amber', 'anchor', 'anvil', 'apricot', 'arctic', 'aspen',
    'atlas', 'aurora', 'badge', 'bamboo', 'banner', 'beacon', 'bison', 'blizzard',
    'blossom', 'boulder', 'breeze', 'bridge', 'bronze', 'canyon', 'cascade', 'cedar',
    'chalk', 'cherry', 'cinder', 'cipher', 'citadel', 'clover', 'cobalt', 'comet',
    'compass', 'copper', 'coral', 'cosmos', 'crater', 'crimson', 'crystal', 'cypress',
    'dagger', 'dawn', 'delta', 'desert', 'diamond', 'dolphin', 'dragon', 'drift',
    'dynamo', 'eclipse', 'elder', 'emerald', 'engine', 'equinox', 'falcon', 'fathom',
    'feather', 'fennel', 'fern', 'fjord', 'flint', 'forest', 'fortress', 'fossil',
    'frost', 'galaxy', 'garden', 'garnet', 'geyser', 'glacier', 'granite', 'gravel',
    'griffin', 'harbor', 'harvest', 'haven', 'hawk', 'hazel', 'helium', 'horizon',
    'indigo', 'island', 'ivory', 'jacket', 'jaguar', 'jasper', 'juniper', 'kayak',
    'kestrel', 'kettle', 'kingdom', 'lagoon', 'lantern', 'larch', 'laurel', 'legend',
    'lichen', 'linen', 'lotus', 'lunar', 'magnet', 'maple', 'marble', 'meadow',
    'mercury', 'meteor', 'mirror', 'monarch', 'monsoon', 'mosaic', 'mountain', 'nebula',
    'nectar', 'nickel', 'nomad', 'nordic', 'oak', 'obsidian', 'ocean', 'onyx',
    'orchid', 'osprey', 'otter', 'paladin', 'panther', 'paradox', 'pebble', 'summit',
  ];

  final Random _secureRandom;

  PasswordGeneratorService({Random? random})
      : _secureRandom = random ?? Random.secure();

  String _filterAmbiguous(String chars, bool exclude) {
    if (!exclude) return chars;
    return chars.split('').where((c) => !_ambiguous.contains(c)).join();
  }

  /// Cryptographically uniform random integer in [0, maxExclusive) using
  /// rejection sampling to eliminate modulo bias.
  int secureRandomInt(int maxExclusive) {
    if (maxExclusive <= 0) {
      throw ArgumentError.value(maxExclusive, 'maxExclusive', 'Must be > 0');
    }
    const range = 0x100000000; // 2^32
    final limit = (range ~/ maxExclusive) * maxExclusive;
    while (true) {
      final value = (_secureRandom.nextInt(1 << 16) << 16) |
          _secureRandom.nextInt(1 << 16);
      if (value < limit) {
        return value % maxExclusive;
      }
    }
  }

  List<T> secureShuffle<T>(List<T> items) {
    final copy = List<T>.from(items);
    for (var i = copy.length - 1; i > 0; i--) {
      final j = secureRandomInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  String generate(PasswordGeneratorOptions options) {
    if (options.passphraseMode) {
      return generatePassphrase(
        wordCount: options.wordCount,
        separator: options.wordSeparator,
        capitalizeWords: options.capitalizeWords,
        includeNumber: options.includeNumberInPassphrase,
      );
    }

    final pools = <String>[];
    if (options.uppercase) {
      pools.add(_filterAmbiguous(_uppercase, options.excludeAmbiguous));
    }
    if (options.lowercase) {
      pools.add(_filterAmbiguous(_lowercase, options.excludeAmbiguous));
    }
    if (options.numbers) {
      pools.add(_filterAmbiguous(_numbers, options.excludeAmbiguous));
    }
    if (options.symbols) {
      pools.add(_filterAmbiguous(_symbols, options.excludeAmbiguous));
    }

    final activePools = pools.where((p) => p.isNotEmpty).toList();
    if (activePools.isEmpty) {
      throw ArgumentError('Select at least one character type.');
    }

    final length = options.length.clamp(8, 128);
    final combined = activePools.join();
    final chars = <String>[];

    for (final pool in activePools) {
      if (chars.length < length) {
        chars.add(pool[secureRandomInt(pool.length)]);
      }
    }

    while (chars.length < length) {
      chars.add(combined[secureRandomInt(combined.length)]);
    }

    return secureShuffle(chars).join();
  }

  String generatePassphrase({
    int wordCount = 5,
    String separator = '-',
    bool capitalizeWords = true,
    bool includeNumber = true,
  }) {
    final count = wordCount.clamp(3, 10);
    final chosen = <String>[];
    final numberSlot = includeNumber ? secureRandomInt(count) : -1;

    for (var i = 0; i < count; i++) {
      var word = _passphraseWords[secureRandomInt(_passphraseWords.length)];
      if (capitalizeWords) {
        word = '${word[0].toUpperCase()}${word.substring(1)}';
      }
      if (i == numberSlot) {
        word = '$word${secureRandomInt(90) + 10}';
      }
      chosen.add(word);
    }

    return chosen.join(separator);
  }

  PasswordStrengthResult evaluateStrength(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        score: 0,
        label: 'Critical',
        entropyBits: 0,
        crackTimeLabel: 'Instant',
        feedback: ['Enter a password to evaluate strength.'],
      );
    }

    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasDigits = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbols = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);

    var poolSize = 0;
    if (hasLower) poolSize += 26;
    if (hasUpper) poolSize += 26;
    if (hasDigits) poolSize += 10;
    if (hasSymbols) poolSize += 32;
    if (poolSize == 0) poolSize = 26;

    final uniqueChars = password.split('').toSet().length;
    final uniquenessRatio = uniqueChars / password.length;
    final hasSequential = RegExp(
      r'(0123|1234|2345|3456|4567|5678|6789|abcd|bcde|qwer|asdf|password|admin)',
      caseSensitive: false,
    ).hasMatch(password);

    var entropy = password.length * (log(poolSize) / ln2);
    if (uniquenessRatio < 0.5) entropy *= 0.65;
    if (hasSequential) entropy *= 0.7;
    final entropyBits = entropy.round();

    final combinations = pow(2, min(entropyBits, 128)).toDouble();
    final secondsToCrack = combinations / (2e10);
    final crackTimeLabel = _formatCrackTime(secondsToCrack);

    final feedback = <String>[];
    if (password.length < 12) {
      feedback.add('Use at least 12 characters (16+ recommended).');
    }
    if (!hasUpper) feedback.add('Add uppercase letters.');
    if (!hasLower) feedback.add('Add lowercase letters.');
    if (!hasDigits) feedback.add('Add numeric digits.');
    if (!hasSymbols) feedback.add('Add special symbols.');
    if (hasSequential) {
      feedback.add('Avoid dictionary words or keyboard sequences.');
    }

    var score = 0;
    var label = 'Critical';
    if (entropyBits >= 90 && password.length >= 14 && !hasSequential) {
      score = 4;
      label = 'Very Strong';
    } else if (entropyBits >= 68 && password.length >= 12) {
      score = 3;
      label = 'Strong';
    } else if (entropyBits >= 48 && password.length >= 8) {
      score = 2;
      label = 'Fair';
    } else if (entropyBits >= 28) {
      score = 1;
      label = 'Weak';
    }

    return PasswordStrengthResult(
      score: score,
      label: label,
      entropyBits: entropyBits,
      crackTimeLabel: crackTimeLabel,
      feedback: feedback,
    );
  }

  String _formatCrackTime(double seconds) {
    if (seconds < 1) return 'Instant';
    if (seconds < 60) return '${seconds.round()} seconds';
    if (seconds < 3600) return '${(seconds / 60).round()} minutes';
    if (seconds < 86400) return '${(seconds / 3600).round()} hours';
    if (seconds < 86400 * 365) return '${(seconds / 86400).round()} days';
    final years = seconds / (86400 * 365.25);
    if (years < 1000) return '${years.round()} years';
    if (years < 1000000) return '${(years / 1000).round()}k years';
    if (years < 1000000000) return '${(years / 1000000).round()}M years';
    return 'Centuries+';
  }
}
