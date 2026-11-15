import '../../core/constants/vault_constants.dart';

enum TotpAlgorithm {
  sha1('SHA1'),
  sha256('SHA256'),
  sha512('SHA512');

  final String wireValue;
  const TotpAlgorithm(this.wireValue);

  static TotpAlgorithm fromWire(String? raw) {
    final normalized = (raw ?? 'SHA1').toUpperCase().replaceAll('-', '');
    for (final alg in TotpAlgorithm.values) {
      if (alg.wireValue == normalized) return alg;
    }
    return TotpAlgorithm.sha1;
  }
}

class TotpDetails {
  final String issuer;
  final String accountName;
  final String secretBase32;
  final TotpAlgorithm algorithm;
  final int digits;
  final int periodSeconds;

  const TotpDetails({
    required this.issuer,
    required this.accountName,
    required this.secretBase32,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = VaultConstants.defaultTotpDigits,
    this.periodSeconds = VaultConstants.defaultTotpPeriodSeconds,
  });

  factory TotpDetails.fromJson(Map<String, dynamic> json) {
    return TotpDetails(
      issuer: json['issuer'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      secretBase32: json['secretBase32'] as String? ?? '',
      algorithm: TotpAlgorithm.fromWire(json['algorithm'] as String?),
      digits: (json['digits'] as num?)?.toInt() ?? VaultConstants.defaultTotpDigits,
      periodSeconds: (json['periodSeconds'] as num?)?.toInt() ??
          VaultConstants.defaultTotpPeriodSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'issuer': issuer,
        'accountName': accountName,
        'secretBase32': secretBase32,
        'algorithm': algorithm.wireValue,
        'digits': digits,
        'periodSeconds': periodSeconds,
      };
}

class SecureNoteDetails {
  final String content;
  final bool isPinned;

  const SecureNoteDetails({
    required this.content,
    this.isPinned = false,
  });

  factory SecureNoteDetails.fromJson(Map<String, dynamic> json) =>
      SecureNoteDetails(
        content: json['content'] as String? ?? '',
        isPinned: json['isPinned'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'isPinned': isPinned,
      };
}

class WifiDetails {
  final String ssid;
  final String securityType; // WPA3, WPA2, WEP, Open
  final String password;
  final bool isHidden;

  const WifiDetails({
    required this.ssid,
    required this.securityType,
    required this.password,
    this.isHidden = false,
  });

  factory WifiDetails.fromJson(Map<String, dynamic> json) => WifiDetails(
        ssid: json['ssid'] as String? ?? '',
        securityType: json['securityType'] as String? ?? 'WPA2',
        password: json['password'] as String? ?? '',
        isHidden: json['isHidden'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'securityType': securityType,
        'password': password,
        'isHidden': isHidden,
      };
}

class PaymentCardDetails {
  final String cardholderName;
  final String brand;
  final String cardNumber;
  final String expiryMonth;
  final String expiryYear;
  final String cvv;
  final String billingZip;

  const PaymentCardDetails({
    required this.cardholderName,
    required this.brand,
    required this.cardNumber,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cvv,
    this.billingZip = '',
  });

  String get maskedLast4 {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••';
    return '•••• ${digits.substring(digits.length - 4)}';
  }

  factory PaymentCardDetails.fromJson(Map<String, dynamic> json) =>
      PaymentCardDetails(
        cardholderName: json['cardholderName'] as String? ?? '',
        brand: json['brand'] as String? ?? 'Card',
        cardNumber: json['cardNumber'] as String? ?? '',
        expiryMonth: json['expiryMonth'] as String? ?? '',
        expiryYear: json['expiryYear'] as String? ?? '',
        cvv: json['cvv'] as String? ?? '',
        billingZip: json['billingZip'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'cardholderName': cardholderName,
        'brand': brand,
        'cardNumber': cardNumber,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'cvv': cvv,
        'billingZip': billingZip,
      };
}

class IdentityDetails {
  final String fullName;
  final String email;
  final String phone;
  final String documentType; // Passport, National ID, Driver License
  final String documentNumber;
  final String issuingCountry;
  final String address;
  final String expiryDate;

  const IdentityDetails({
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.documentType = 'National ID',
    this.documentNumber = '',
    this.issuingCountry = '',
    this.address = '',
    this.expiryDate = '',
  });

  factory IdentityDetails.fromJson(Map<String, dynamic> json) =>
      IdentityDetails(
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        documentType: json['documentType'] as String? ?? 'National ID',
        documentNumber: json['documentNumber'] as String? ?? '',
        issuingCountry: json['issuingCountry'] as String? ?? '',
        address: json['address'] as String? ?? '',
        expiryDate: json['expiryDate'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'documentType': documentType,
        'documentNumber': documentNumber,
        'issuingCountry': issuingCountry,
        'address': address,
        'expiryDate': expiryDate,
      };
}

class LicenseKeyDetails {
  final String productName;
  final String licenseKey;
  final String registeredTo;
  final String purchaseDate;
  final String expiryDate;

  const LicenseKeyDetails({
    required this.productName,
    required this.licenseKey,
    this.registeredTo = '',
    this.purchaseDate = '',
    this.expiryDate = '',
  });

  factory LicenseKeyDetails.fromJson(Map<String, dynamic> json) =>
      LicenseKeyDetails(
        productName: json['productName'] as String? ?? '',
        licenseKey: json['licenseKey'] as String? ?? '',
        registeredTo: json['registeredTo'] as String? ?? '',
        purchaseDate: json['purchaseDate'] as String? ?? '',
        expiryDate: json['expiryDate'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'licenseKey': licenseKey,
        'registeredTo': registeredTo,
        'purchaseDate': purchaseDate,
        'expiryDate': expiryDate,
      };
}

class RecoveryCodesDetails {
  final String serviceName;
  final List<String> codes;
  final List<String> usedCodes;

  const RecoveryCodesDetails({
    required this.serviceName,
    required this.codes,
    this.usedCodes = const [],
  });

  factory RecoveryCodesDetails.fromJson(Map<String, dynamic> json) =>
      RecoveryCodesDetails(
        serviceName: json['serviceName'] as String? ?? '',
        codes: (json['codes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        usedCodes: (json['usedCodes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'serviceName': serviceName,
        'codes': codes,
        'usedCodes': usedCodes,
      };
}

class PasswordHistoryEntry {
  final String password;
  final String changedAtIso;

  const PasswordHistoryEntry({
    required this.password,
    required this.changedAtIso,
  });

  DateTime? get changedAt => DateTime.tryParse(changedAtIso);

  factory PasswordHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PasswordHistoryEntry(
        password: json['password'] as String? ?? '',
        changedAtIso: json['changedAtIso'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'password': password,
        'changedAtIso': changedAtIso,
      };
}
