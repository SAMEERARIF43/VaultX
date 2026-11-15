import 'package:flutter/material.dart';

enum VaultRecordType {
  login('login', 'Website Login', Icons.language_rounded),
  appLogin('app_login', 'App Login', Icons.smartphone_rounded),
  secureNote('secure_note', 'Secure Note', Icons.description_rounded),
  wifi('wifi', 'Wi-Fi Network', Icons.wifi_rounded),
  paymentCard('payment_card', 'Payment Card', Icons.credit_card_rounded),
  identity('identity', 'Identity', Icons.badge_rounded),
  licenseKey('license_key', 'License Key', Icons.vpn_key_rounded),
  recoveryCodes('recovery_codes', 'Recovery Codes', Icons.shield_outlined),
  totp('totp', 'Authenticator', Icons.qr_code_2_rounded);

  final String wireValue;
  final String label;
  final IconData icon;

  const VaultRecordType(this.wireValue, this.label, this.icon);

  static VaultRecordType fromWire(String? raw) {
    for (final type in VaultRecordType.values) {
      if (type.wireValue == raw) return type;
    }
    return VaultRecordType.login;
  }

  bool get isWalletRecord =>
      this != VaultRecordType.login &&
      this != VaultRecordType.appLogin &&
      this != VaultRecordType.totp;
}
