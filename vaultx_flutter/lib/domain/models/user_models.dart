import 'package:flutter/material.dart';
import '../../core/constants/vault_constants.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final bool vaultInitialized;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.vaultInitialized,
    this.createdAt,
    this.updatedAt,
  });

  UserProfile copyWith({
    String? displayName,
    bool? vaultInitialized,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      vaultInitialized: vaultInitialized ?? this.vaultInitialized,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserSecuritySettings {
  final String userId;
  final int autoLockMinutes;
  final int clipboardClearSeconds;
  final bool requireReauthForReveal;
  final DateTime? updatedAt;

  const UserSecuritySettings({
    this.userId = '',
    this.autoLockMinutes = VaultConstants.defaultAutoLockMinutes,
    this.clipboardClearSeconds = VaultConstants.defaultClipboardClearSeconds,
    this.requireReauthForReveal = false,
    this.updatedAt,
  });

  UserSecuritySettings copyWith({
    String? userId,
    int? autoLockMinutes,
    int? clipboardClearSeconds,
    bool? requireReauthForReveal,
    DateTime? updatedAt,
  }) {
    return UserSecuritySettings(
      userId: userId ?? this.userId,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      clipboardClearSeconds:
          clipboardClearSeconds ?? this.clipboardClearSeconds,
      requireReauthForReveal:
          requireReauthForReveal ?? this.requireReauthForReveal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LocalDevicePreferences {
  final ThemeMode themeMode;
  final bool biometricUnlockEnabled;
  final bool screenshotProtectionEnabled;
  final bool lockOnBackground;
  final bool autofillIndexSyncEnabled;

  const LocalDevicePreferences({
    this.themeMode = ThemeMode.dark,
    this.biometricUnlockEnabled = false,
    this.screenshotProtectionEnabled = true,
    this.lockOnBackground = true,
    this.autofillIndexSyncEnabled = true,
  });

  factory LocalDevicePreferences.fromJson(Map<String, dynamic> json) {
    final themeStr = json['themeMode'] as String? ?? 'dark';
    final themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    return LocalDevicePreferences(
      themeMode: themeMode,
      biometricUnlockEnabled: json['biometricUnlockEnabled'] as bool? ?? false,
      screenshotProtectionEnabled:
          json['screenshotProtectionEnabled'] as bool? ?? true,
      lockOnBackground: json['lockOnBackground'] as bool? ?? true,
      autofillIndexSyncEnabled:
          json['autofillIndexSyncEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'biometricUnlockEnabled': biometricUnlockEnabled,
        'screenshotProtectionEnabled': screenshotProtectionEnabled,
        'lockOnBackground': lockOnBackground,
        'autofillIndexSyncEnabled': autofillIndexSyncEnabled,
      };

  LocalDevicePreferences copyWith({
    ThemeMode? themeMode,
    bool? biometricUnlockEnabled,
    bool? screenshotProtectionEnabled,
    bool? lockOnBackground,
    bool? autofillIndexSyncEnabled,
  }) {
    return LocalDevicePreferences(
      themeMode: themeMode ?? this.themeMode,
      biometricUnlockEnabled:
          biometricUnlockEnabled ?? this.biometricUnlockEnabled,
      screenshotProtectionEnabled:
          screenshotProtectionEnabled ?? this.screenshotProtectionEnabled,
      lockOnBackground: lockOnBackground ?? this.lockOnBackground,
      autofillIndexSyncEnabled:
          autofillIndexSyncEnabled ?? this.autofillIndexSyncEnabled,
    );
  }
}
