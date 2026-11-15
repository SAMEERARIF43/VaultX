import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/constants/vault_constants.dart';
import '../../../domain/models/security_audit_models.dart';
import '../../../domain/models/vault_record.dart';
import '../../../domain/models/vault_record_type.dart';
import '../../../domain/models/wallet_details.dart';
import '../../widgets/vaultx_widgets.dart';

Future<void> showRecordEditorSheet(
  BuildContext context, {
  DecryptedVaultRecord? existing,
  VaultRecordType initialType = VaultRecordType.login,
  String? prefilledPassword,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => RecordEditorSheet(
      existing: existing,
      initialType: initialType,
      prefilledPassword: prefilledPassword,
    ),
  );
}

class RecordEditorSheet extends ConsumerStatefulWidget {
  final DecryptedVaultRecord? existing;
  final VaultRecordType initialType;
  final String? prefilledPassword;

  const RecordEditorSheet({
    super.key,
    this.existing,
    this.initialType = VaultRecordType.login,
    this.prefilledPassword,
  });

  @override
  ConsumerState<RecordEditorSheet> createState() => _RecordEditorSheetState();
}

class _RecordEditorSheetState extends ConsumerState<RecordEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late VaultRecordType _recordType;
  late TextEditingController _titleCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _packageCtrl;
  late TextEditingController _folderCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _notesCtrl;

  // Wallet-specific controllers
  late TextEditingController _wifiSsidCtrl;
  late TextEditingController _wifiSecurityCtrl;
  late TextEditingController _cardHolderCtrl;
  late TextEditingController _cardBrandCtrl;
  late TextEditingController _cardNumberCtrl;
  late TextEditingController _cardExpMonthCtrl;
  late TextEditingController _cardExpYearCtrl;
  late TextEditingController _cardCvvCtrl;
  late TextEditingController _idFullNameCtrl;
  late TextEditingController _idDocTypeCtrl;
  late TextEditingController _idDocNumberCtrl;
  late TextEditingController _idCountryCtrl;
  late TextEditingController _licenseKeyCtrl;
  late TextEditingController _licenseOwnerCtrl;
  late TextEditingController _recoveryCodesCtrl;
  late TextEditingController _totpIssuerCtrl;
  late TextEditingController _totpAccountCtrl;
  late TextEditingController _totpSecretCtrl;

  String _category = 'Personal';
  bool _isFavorite = false;
  DateTime? _expiresAt;
  bool _obscureSecret = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing?.payload;
    _recordType = p?.recordType ?? widget.initialType;
    _category = p?.category ?? 'Personal';
    _isFavorite = p?.isFavorite ?? false;
    _expiresAt = p?.expiresAt;

    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _usernameCtrl = TextEditingController(text: p?.username ?? '');
    _passwordCtrl = TextEditingController(
      text: widget.prefilledPassword ?? p?.password ?? '',
    );
    _urlCtrl = TextEditingController(text: p?.url ?? '');
    _packageCtrl = TextEditingController(text: p?.packageName ?? '');
    _folderCtrl = TextEditingController(text: p?.folder ?? '');
    _tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    _notesCtrl = TextEditingController(
      text: p?.secureNote?.content ?? p?.notes ?? '',
    );

    _wifiSsidCtrl = TextEditingController(text: p?.wifi?.ssid ?? '');
    _wifiSecurityCtrl =
        TextEditingController(text: p?.wifi?.securityType ?? 'WPA2');
    _cardHolderCtrl =
        TextEditingController(text: p?.card?.cardholderName ?? '');
    _cardBrandCtrl = TextEditingController(text: p?.card?.brand ?? 'Visa');
    _cardNumberCtrl = TextEditingController(text: p?.card?.cardNumber ?? '');
    _cardExpMonthCtrl = TextEditingController(text: p?.card?.expiryMonth ?? '');
    _cardExpYearCtrl = TextEditingController(text: p?.card?.expiryYear ?? '');
    _cardCvvCtrl = TextEditingController(text: p?.card?.cvv ?? '');
    _idFullNameCtrl = TextEditingController(text: p?.identity?.fullName ?? '');
    _idDocTypeCtrl =
        TextEditingController(text: p?.identity?.documentType ?? 'Passport');
    _idDocNumberCtrl =
        TextEditingController(text: p?.identity?.documentNumber ?? '');
    _idCountryCtrl =
        TextEditingController(text: p?.identity?.issuingCountry ?? '');
    _licenseKeyCtrl =
        TextEditingController(text: p?.license?.licenseKey ?? '');
    _licenseOwnerCtrl =
        TextEditingController(text: p?.license?.registeredTo ?? '');
    _recoveryCodesCtrl = TextEditingController(
      text: p?.recoveryCodes?.codes.join('\n') ?? '',
    );
    _totpIssuerCtrl = TextEditingController(text: p?.totp?.issuer ?? '');
    _totpAccountCtrl = TextEditingController(text: p?.totp?.accountName ?? '');
    _totpSecretCtrl = TextEditingController(text: p?.totp?.secretBase32 ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _usernameCtrl,
      _passwordCtrl,
      _urlCtrl,
      _packageCtrl,
      _folderCtrl,
      _tagsCtrl,
      _notesCtrl,
      _wifiSsidCtrl,
      _wifiSecurityCtrl,
      _cardHolderCtrl,
      _cardBrandCtrl,
      _cardNumberCtrl,
      _cardExpMonthCtrl,
      _cardExpYearCtrl,
      _cardCvvCtrl,
      _idFullNameCtrl,
      _idDocTypeCtrl,
      _idDocNumberCtrl,
      _idCountryCtrl,
      _licenseKeyCtrl,
      _licenseOwnerCtrl,
      _recoveryCodesCtrl,
      _totpIssuerCtrl,
      _totpAccountCtrl,
      _totpSecretCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate TOTP secret if supplied
    final totpSecret = _totpSecretCtrl.text.trim();
    if (_recordType == VaultRecordType.totp || totpSecret.isNotEmpty) {
      try {
        ref.read(totpServiceProvider).decodeBase32(totpSecret);
      } catch (e) {
        showVaultSnackBar(context, e.toString(), isError: true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final existingPayload = widget.existing?.payload;

      final payload = VaultRecordPayload(
        title: _titleCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _recordType == VaultRecordType.wifi
            ? _passwordCtrl.text
            : _passwordCtrl.text,
        url: _urlCtrl.text.trim(),
        category: _category,
        notes: _notesCtrl.text.trim(),
        recordType: _recordType,
        packageName: _packageCtrl.text.trim().isEmpty
            ? null
            : _packageCtrl.text.trim(),
        folder: _folderCtrl.text.trim().isEmpty
            ? null
            : _folderCtrl.text.trim(),
        tags: tags,
        isFavorite: _isFavorite,
        passwordHistory: existingPayload?.passwordHistory ?? const [],
        expiresAtIso: _expiresAt?.toUtc().toIso8601String(),
        lastAccessedAtIso: existingPayload?.lastAccessedAtIso,
        totp: totpSecret.isNotEmpty
            ? TotpDetails(
                issuer: _totpIssuerCtrl.text.trim().isEmpty
                    ? _titleCtrl.text.trim()
                    : _totpIssuerCtrl.text.trim(),
                accountName: _totpAccountCtrl.text.trim().isEmpty
                    ? _usernameCtrl.text.trim()
                    : _totpAccountCtrl.text.trim(),
                secretBase32: totpSecret.toUpperCase().replaceAll(' ', ''),
              )
            : null,
        secureNote: _recordType == VaultRecordType.secureNote
            ? SecureNoteDetails(content: _notesCtrl.text.trim())
            : null,
        wifi: _recordType == VaultRecordType.wifi
            ? WifiDetails(
                ssid: _wifiSsidCtrl.text.trim().isEmpty
                    ? _titleCtrl.text.trim()
                    : _wifiSsidCtrl.text.trim(),
                securityType: _wifiSecurityCtrl.text.trim(),
                password: _passwordCtrl.text,
              )
            : null,
        card: _recordType == VaultRecordType.paymentCard
            ? PaymentCardDetails(
                cardholderName: _cardHolderCtrl.text.trim(),
                brand: _cardBrandCtrl.text.trim(),
                cardNumber: _cardNumberCtrl.text.trim(),
                expiryMonth: _cardExpMonthCtrl.text.trim(),
                expiryYear: _cardExpYearCtrl.text.trim(),
                cvv: _cardCvvCtrl.text.trim(),
              )
            : null,
        identity: _recordType == VaultRecordType.identity
            ? IdentityDetails(
                fullName: _idFullNameCtrl.text.trim(),
                email: _usernameCtrl.text.trim(),
                documentType: _idDocTypeCtrl.text.trim(),
                documentNumber: _idDocNumberCtrl.text.trim(),
                issuingCountry: _idCountryCtrl.text.trim(),
              )
            : null,
        license: _recordType == VaultRecordType.licenseKey
            ? LicenseKeyDetails(
                productName: _titleCtrl.text.trim(),
                licenseKey: _licenseKeyCtrl.text.trim(),
                registeredTo: _licenseOwnerCtrl.text.trim(),
              )
            : null,
        recoveryCodes: _recordType == VaultRecordType.recoveryCodes
            ? RecoveryCodesDetails(
                serviceName: _titleCtrl.text.trim(),
                codes: _recoveryCodesCtrl.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              )
            : null,
      );

      await ref.read(vaultSessionProvider.notifier).saveRecord(
            payload,
            existingId: widget.existing?.id,
          );

      if (mounted) {
        Navigator.of(context).pop();
        showVaultSnackBar(
          context,
          widget.existing == null
              ? 'Encrypted & saved "${payload.title}".'
              : 'Updated "${payload.title}".',
        );
      }
    } catch (e) {
      if (mounted) showVaultSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _generateInlinePassword() {
    final generated = ref.read(passwordGeneratorServiceProvider).generate(
          const PasswordGeneratorOptions(length: 20),
        );
    setState(() {
      _passwordCtrl.text = generated;
      _obscureSecret = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final pwService = ref.read(passwordGeneratorServiceProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Encrypted Record' : 'New Encrypted Record',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: _isFavorite ? Colors.amber : null,
                      ),
                      onPressed: () => setState(() => _isFavorite = !_isFavorite),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<VaultRecordType>(
                  value: _recordType,
                  decoration: const InputDecoration(labelText: 'Record Type'),
                  items: VaultRecordType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Icon(t.icon, size: 18),
                              const SizedBox(width: 10),
                              Text(t.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _recordType = val);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title / Service Name *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 14),

                if (_recordType == VaultRecordType.login ||
                    _recordType == VaultRecordType.appLogin) ...[
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username or Email',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscureSecret,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Generate Strong Password',
                            icon: const Icon(Icons.auto_fix_high_rounded),
                            onPressed: _generateInlinePassword,
                          ),
                          IconButton(
                            icon: Icon(
                              _obscureSecret
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureSecret = !_obscureSecret),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_passwordCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    PasswordStrengthMeter(
                      result: pwService.evaluateStrength(_passwordCtrl.text),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Website URL (used for Android Autofill)',
                      hintText: 'https://github.com',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _packageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Android App Package (optional)',
                      hintText: 'com.github.android',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _totpSecretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Attached 2FA Base32 Secret (optional)',
                      hintText: 'JBSWY3DPEHPK3PXP',
                    ),
                  ),
                ],

                if (_recordType == VaultRecordType.totp) ...[
                  TextFormField(
                    controller: _totpIssuerCtrl,
                    decoration: const InputDecoration(labelText: 'Issuer'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _totpAccountCtrl,
                    decoration: const InputDecoration(labelText: 'Account Label'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _totpSecretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Base32 Secret Key *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Secret required' : null,
                  ),
                ],

                if (_recordType == VaultRecordType.wifi) ...[
                  TextFormField(
                    controller: _wifiSsidCtrl,
                    decoration: const InputDecoration(labelText: 'Wi-Fi SSID'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _wifiSecurityCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Security (WPA3/WPA2)'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscureSecret,
                    decoration: InputDecoration(
                      labelText: 'Wi-Fi Passphrase',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSecret
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureSecret = !_obscureSecret),
                      ),
                    ),
                  ),
                ],

                if (_recordType == VaultRecordType.paymentCard) ...[
                  TextFormField(
                    controller: _cardHolderCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cardholder Name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cardBrandCtrl,
                    decoration: const InputDecoration(labelText: 'Card Brand'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cardNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Card Number'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cardExpMonthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'MM'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _cardExpYearCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'YYYY'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _cardCvvCtrl,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'CVV'),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_recordType == VaultRecordType.identity) ...[
                  TextFormField(
                    controller: _idFullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Legal Full Name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Email'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _idDocTypeCtrl,
                    decoration: const InputDecoration(labelText: 'Document Type'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _idDocNumberCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Document Number'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _idCountryCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Issuing Country'),
                  ),
                ],

                if (_recordType == VaultRecordType.licenseKey) ...[
                  TextFormField(
                    controller: _licenseKeyCtrl,
                    decoration: const InputDecoration(labelText: 'License Key'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _licenseOwnerCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Registered Email/Owner'),
                  ),
                ],

                if (_recordType == VaultRecordType.recoveryCodes) ...[
                  TextFormField(
                    controller: _recoveryCodesCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Recovery Codes (one per line)',
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: VaultConstants.defaultCategories.contains(_category)
                            ? _category
                            : 'Personal',
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: VaultConstants.defaultCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _folderCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Custom Folder'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'banking, 2fa, work',
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Password Expiration Reminder'),
                  subtitle: Text(
                    _expiresAt == null
                        ? 'None configured'
                        : 'Remind on ${_expiresAt!.toLocal().toString().split(' ').first}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _expiresAt = null),
                        ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expiresAt ??
                                DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 1825)),
                          );
                          if (picked != null) setState(() => _expiresAt = picked);
                        },
                        child: const Text('Set Date'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: _recordType == VaultRecordType.secureNote ? 7 : 3,
                  decoration: InputDecoration(
                    labelText: _recordType == VaultRecordType.secureNote
                        ? 'Encrypted Note Content'
                        : 'Notes (Encrypted)',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Encrypt & Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
