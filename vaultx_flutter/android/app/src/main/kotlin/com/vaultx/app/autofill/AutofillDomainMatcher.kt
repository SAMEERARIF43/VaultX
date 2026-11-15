package com.vaultx.app.autofill

import java.net.URI

object AutofillDomainMatcher {
    fun extractNormalizedHost(rawUrl: String?): String? {
        val trimmed = rawUrl?.trim() ?: return null
        if (trimmed.isEmpty() || trimmed.contains("*")) return null
        if (trimmed.startsWith("androidapp://", ignoreCase = true)) return null

        val withScheme = if (Regex("^https?://", RegexOption.IGNORE_CASE).containsMatchIn(trimmed)) {
            trimmed
        } else {
            "https://$trimmed"
        }

        return try {
            val host = URI(withScheme).host?.lowercase()?.removePrefix("www.") ?: return null
            if (host.isEmpty() || (!host.contains('.') && host != "localhost")) null else host
        } catch (_: Exception) {
            null
        }
    }

    fun extractAndroidPackage(rawValue: String?): String? {
        val trimmed = rawValue?.trim() ?: return null
        if (trimmed.isEmpty()) return null
        val pkg = if (trimmed.startsWith("androidapp://", ignoreCase = true)) {
            trimmed.substring("androidapp://".length).substringBefore('/').trim()
        } else {
            trimmed
        }
        val valid = Regex("^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+$").matches(pkg)
        return if (valid) pkg.lowercase() else null
    }

    fun matches(
        recordUrl: String?,
        recordPackageName: String?,
        targetWebDomain: String?,
        targetAndroidPackage: String?
    ): Boolean {
        val normalizedTargetPkg = extractAndroidPackage(targetAndroidPackage)
        if (normalizedTargetPkg != null) {
            val recPkg = extractAndroidPackage(recordPackageName) ?: extractAndroidPackage(recordUrl)
            if (recPkg != null && recPkg == normalizedTargetPkg) {
                return true
            }
        }

        val targetHost = extractNormalizedHost(targetWebDomain)
        if (targetHost != null) {
            val recHost = extractNormalizedHost(recordUrl)
            if (recHost != null && (recHost == targetHost || targetHost.endsWith(".$recHost"))) {
                return true
            }
        }
        return false
    }
}
