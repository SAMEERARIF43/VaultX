import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/constants/vault_constants.dart';
import '../models/wallet_details.dart';

class TotpException implements Exception {
  final String message;
  const TotpException(this.message);

  @override
  String toString() => 'TotpException: $message';
}

/// Pure-Dart RFC 6238 / RFC 4226 Time-based One-Time Password engine + RFC 4648 Base32 decoder.
class TotpService {
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes a Base32 secret string (ignoring whitespace, hyphens, and trailing padding `=`).
  Uint8List decodeBase32(String rawSecret) {
    final cleaned = rawSecret
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-=]'), '');

    if (cleaned.isEmpty) {
      throw const TotpException('TOTP secret key cannot be empty.');
    }

    var buffer = 0;
    var bitsLeft = 0;
    final output = <int>[];

    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      final value = _base32Alphabet.indexOf(char);
      if (value < 0) {
        throw TotpException(
          'Invalid Base32 character "$char" in TOTP secret key.',
        );
      }
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }

    if (output.isEmpty) {
      throw const TotpException('Decoded TOTP secret key is too short.');
    }

    return Uint8List.fromList(output);
  }

  /// Parses an `otpauth://totp/...` provisioning URI safely.
  TotpDetails parseOtpAuthUri(String rawUri) {
    final trimmed = rawUri.trim();
    final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException {
      throw const TotpException('Invalid otpauth provisioning URI format.');
    }

    if (uri.scheme.toLowerCase() != 'otpauth') {
      throw const TotpException(
        'Provisioning URI must start with otpauth://',
      );
    }
    if (uri.host.toLowerCase() != 'totp') {
      throw const TotpException(
        'Only time-based (totp) authenticator URIs are supported.',
      );
    }

    final secret = uri.queryParameters['secret'] ?? '';
    // Validate Base32 secret immediately
    decodeBase32(secret);

    final rawLabel = Uri.decodeComponent(uri.path.replaceFirst(RegExp(r'^/'), ''));
    var issuerFromLabel = '';
    var accountName = rawLabel;

    if (rawLabel.contains(':')) {
      final splitIdx = rawLabel.indexOf(':');
      issuerFromLabel = rawLabel.substring(0, splitIdx).trim();
      accountName = rawLabel.substring(splitIdx + 1).trim();
    }

    final queryIssuer = (uri.queryParameters['issuer'] ?? '').trim();
    final issuer = queryIssuer.isNotEmpty
        ? queryIssuer
        : (issuerFromLabel.isNotEmpty ? issuerFromLabel : 'Authenticator');

    final digitsRaw = uri.queryParameters['digits'];
    final digits = int.tryParse(digitsRaw ?? '') ?? VaultConstants.defaultTotpDigits;
    if (digits != 6 && digits != 8) {
      throw const TotpException('TOTP digits must be 6 or 8.');
    }

    final periodRaw = uri.queryParameters['period'];
    final period =
        int.tryParse(periodRaw ?? '') ?? VaultConstants.defaultTotpPeriodSeconds;
    if (period < 10 || period > 120) {
      throw const TotpException('TOTP period must be between 10 and 120 seconds.');
    }

    final algorithm = TotpAlgorithm.fromWire(uri.queryParameters['algorithm']);

    return TotpDetails(
      issuer: issuer,
      accountName: accountName,
      secretBase32: secret.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), ''),
      algorithm: algorithm,
      digits: digits,
      periodSeconds: period,
    );
  }

  String buildOtpAuthUri(TotpDetails details) {
    final label = details.accountName.isNotEmpty
        ? '${Uri.encodeComponent(details.issuer)}:${Uri.encodeComponent(details.accountName)}'
        : Uri.encodeComponent(details.issuer);
    return Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/$label',
      queryParameters: {
        'secret': details.secretBase32,
        'issuer': details.issuer,
        'algorithm': details.algorithm.wireValue,
        'digits': details.digits.toString(),
        'period': details.periodSeconds.toString(),
      },
    ).toString();
  }

  /// Generates the current RFC 6238 TOTP code for [details] at [timestamp].
  Future<String> generateCode(
    TotpDetails details, {
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now().toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final period = details.periodSeconds <= 0
        ? VaultConstants.defaultTotpPeriodSeconds
        : details.periodSeconds;
    final counter = epochSeconds ~/ period;

    final counterBytes = Uint8List(8);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = value & 0xff;
      value >>= 8;
    }

    final keyBytes = decodeBase32(details.secretBase32);
    final Hmac hmac = switch (details.algorithm) {
      TotpAlgorithm.sha1 => Hmac.sha1(),
      TotpAlgorithm.sha256 => Hmac.sha256(),
      TotpAlgorithm.sha512 => Hmac.sha512(),
    };

    final mac = await hmac.calculateMac(
      counterBytes,
      secretKey: SecretKey(keyBytes),
    );
    final hash = mac.bytes;
    final offset = hash.last & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);

    var mod = 1;
    for (var i = 0; i < details.digits; i++) {
      mod *= 10;
    }

    final otp = binary % mod;
    return otp.toString().padLeft(details.digits, '0');
  }

  int secondsRemaining(TotpDetails details, {DateTime? timestamp}) {
    final period = details.periodSeconds <= 0
        ? VaultConstants.defaultTotpPeriodSeconds
        : details.periodSeconds;
    final nowSeconds =
        (timestamp ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final elapsed = nowSeconds % period;
    return period - elapsed;
  }

  double progressRemaining(TotpDetails details, {DateTime? timestamp}) {
    final period = details.periodSeconds <= 0
        ? VaultConstants.defaultTotpPeriodSeconds
        : details.periodSeconds;
    return secondsRemaining(details, timestamp: timestamp) / period;
  }
}
