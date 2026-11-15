import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/errors/vault_exceptions.dart';

class AutofillServiceStatus {
  final bool supported;
  final bool isDefaultProvider;

  const AutofillServiceStatus({
    required this.supported,
    required this.isDefaultProvider,
  });
}

class BiometricCapability {
  final bool available;
  final String status;

  const BiometricCapability({
    required this.available,
    required this.status,
  });
}

/// Bridge to native Android security primitives:
/// - `FLAG_SECURE` screenshot & app-switcher preview blocking
/// - Android 13+ `EXTRA_IS_SENSITIVE` clipboard & auto-clear
/// - Android Keystore + `BiometricPrompt.CryptoObject` hardware DEK wrapping
/// - Android Keystore-wrapped offline storage & Android AutofillService index
class AndroidSecurityChannel {
  static const MethodChannel _channel = MethodChannel('com.vaultx.app/security');

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> setScreenshotProtection(bool enabled) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setScreenshotProtection', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Safe fallback in unit tests
    }
  }

  Future<void> copySensitiveText({
    required String text,
    required bool isSensitive,
    required int clearAfterSeconds,
  }) async {
    if (!_isAndroid) {
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }
    try {
      await _channel.invokeMethod<void>('copySensitiveText', {
        'text': text,
        'isSensitive': isSensitive,
        'clearAfterSeconds': clearAfterSeconds,
      });
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<void> clearClipboardNow() async {
    if (!_isAndroid) {
      await Clipboard.setData(const ClipboardData(text: ''));
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearClipboardNow');
    } on MissingPluginException {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  Future<BiometricCapability> canAuthenticateBiometrics() async {
    if (!_isAndroid) {
      return const BiometricCapability(available: false, status: 'unsupported');
    }
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('canAuthenticateBiometrics');
      return BiometricCapability(
        available: res?['available'] as bool? ?? false,
        status: res?['status'] as String? ?? 'unknown',
      );
    } on MissingPluginException {
      return const BiometricCapability(available: false, status: 'unavailable');
    }
  }

  Future<void> enrollBiometricVaultKey(String dekBase64) async {
    if (!_isAndroid) {
      throw const BiometricAuthException(
        'UNSUPPORTED',
        'Android Keystore biometrics are only available on Android.',
      );
    }
    try {
      await _channel.invokeMethod<void>('enrollBiometricVaultKey', {
        'dekBase64': dekBase64,
      });
    } on PlatformException catch (e) {
      throw BiometricAuthException(e.code, e.message ?? 'Biometric enrollment failed.');
    }
  }

  Future<String> unlockBiometricVaultKey() async {
    if (!_isAndroid) {
      throw const BiometricAuthException(
        'UNSUPPORTED',
        'Android Keystore biometrics are only available on Android.',
      );
    }
    try {
      final result = await _channel.invokeMethod<String>('unlockBiometricVaultKey');
      if (result == null || result.isEmpty) {
        throw const BiometricAuthException(
          'EMPTY_KEY',
          'No wrapped biometric key returned.',
        );
      }
      return result;
    } on PlatformException catch (e) {
      throw BiometricAuthException(
        e.code,
        e.message ?? 'Biometric authentication failed.',
      );
    }
  }

  Future<bool> hasBiometricVaultKey() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasBiometricVaultKey') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> clearBiometricVaultKey() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearBiometricVaultKey');
    } on MissingPluginException {
      // No-op in tests
    }
  }

  Future<void> protectOfflineBlob(String fileKey, String jsonPayload) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('protectOfflineBlob', {
      'fileKey': fileKey,
      'payload': jsonPayload,
    });
  }

  Future<String?> unprotectOfflineBlob(String fileKey) async {
    if (!_isAndroid) return null;
    return _channel.invokeMethod<String>('unprotectOfflineBlob', {
      'fileKey': fileKey,
    });
  }

  Future<void> clearOfflineBlob(String fileKey) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearOfflineBlob', {
        'fileKey': fileKey,
      });
    } on MissingPluginException {
      // No-op in tests
    }
  }

  /// Syncs minimal domain-matched autofill credential index encrypted under
  /// the user's Vault DEK (AES-256-GCM) so zero plaintext ever touches disk.
  Future<void> syncAutofillIndex({
    required String ciphertextBase64,
    required String ivBase64,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('syncAutofillIndex', {
        'payloadJson': jsonEncode({
          'ciphertext': ciphertextBase64,
          'iv': ivBase64,
        }),
      });
    } on MissingPluginException {
      // Safe fallback in tests
    }
  }

  Future<void> clearAutofillIndex() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearAutofillIndex');
    } on MissingPluginException {
      // Safe fallback in tests
    }
  }

  Future<AutofillServiceStatus> getAutofillStatus() async {
    if (!_isAndroid) {
      return const AutofillServiceStatus(
        supported: false,
        isDefaultProvider: false,
      );
    }
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('getAutofillStatus');
      return AutofillServiceStatus(
        supported: res?['supported'] as bool? ?? false,
        isDefaultProvider: res?['isDefaultProvider'] as bool? ?? false,
      );
    } on MissingPluginException {
      return const AutofillServiceStatus(
        supported: false,
        isDefaultProvider: false,
      );
    }
  }

  Future<bool> openAutofillSystemSettings() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openAutofillSystemSettings') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
