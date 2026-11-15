import '../models/vault_record.dart';
import '../models/vault_record_type.dart';

/// Strict domain & Android package matcher for Android Autofill and companion protocols.
/// Mirrors `src/lib/browserExtensionProtocol.ts` domain rules so credentials never
/// match unrelated domains, wildcard entries, or empty URLs.
class DomainMatchingService {
  /// Extracts normalized lowercase host without `www.` prefix, or null if invalid/empty.
  String? extractNormalizedHost(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('*')) return null;

    // Ignore androidapp:// scheme when extracting web hosts
    if (trimmed.toLowerCase().startsWith('androidapp://')) {
      return null;
    }

    final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
        ? trimmed
        : 'https://$trimmed';

    final Uri? parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) return null;

    final host = parsed.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host.isEmpty || !host.contains('.') && host != 'localhost') {
      return null;
    }
    return host;
  }

  String? extractAndroidPackage(String rawUrlOrPackage) {
    final trimmed = rawUrlOrPackage.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase().startsWith('androidapp://')) {
      final pkg = trimmed.substring('androidapp://'.length).split('/').first.trim();
      return _isValidAndroidPackage(pkg) ? pkg.toLowerCase() : null;
    }
    return _isValidAndroidPackage(trimmed) ? trimmed.toLowerCase() : null;
  }

  bool _isValidAndroidPackage(String pkg) {
    return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$').hasMatch(pkg);
  }

  /// Returns matching login records for a verified [webDomain] and/or [androidPackage].
  /// Exact matches rank ahead of parent/subdomain matches.
  List<DecryptedVaultRecord> matchRecordsForAutofill(
    List<DecryptedVaultRecord> records, {
    String? webDomain,
    String? androidPackage,
  }) {
    final targetHost =
        webDomain != null ? extractNormalizedHost(webDomain) : null;
    final targetPackage = androidPackage != null
        ? extractAndroidPackage(androidPackage)
        : null;

    if (targetHost == null && targetPackage == null) {
      return const [];
    }

    final exactMatches = <DecryptedVaultRecord>[];
    final subdomainMatches = <DecryptedVaultRecord>[];

    for (final rec in records) {
      if (rec.decryptionError) continue;
      if (rec.recordType != VaultRecordType.login &&
          rec.recordType != VaultRecordType.appLogin) {
        continue;
      }

      var isExact = false;
      var isSubdomain = false;

      // 1. Package name match (strict exact package equality)
      if (targetPackage != null) {
        final recordPkg = rec.payload.packageName != null
            ? extractAndroidPackage(rec.payload.packageName!)
            : extractAndroidPackage(rec.url);
        if (recordPkg != null && recordPkg == targetPackage) {
          isExact = true;
        }
      }

      // 2. Web domain match (exact host or true subdomain `.host`)
      if (!isExact && targetHost != null && rec.url.isNotEmpty) {
        final credHost = extractNormalizedHost(rec.url);
        if (credHost != null) {
          if (credHost == targetHost) {
            isExact = true;
          } else if (targetHost.endsWith('.$credHost')) {
            isSubdomain = true;
          }
        }
      }

      if (isExact) {
        exactMatches.add(rec);
      } else if (isSubdomain) {
        subdomainMatches.add(rec);
      }
    }

    return [...exactMatches, ...subdomainMatches];
  }
}
