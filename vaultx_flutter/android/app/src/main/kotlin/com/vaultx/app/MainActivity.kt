package com.vaultx.app

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.provider.Settings
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.util.Base64
import android.view.WindowManager
import android.view.autofill.AutofillManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.vaultx.app.security.VaultKeystoreHelper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Arrays

class MainActivity : FlutterFragmentActivity() {
    private val securityChannel = "com.vaultx.app/security"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var clipboardClearRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable FLAG_SECURE by default to block screenshots and app-switcher thumbnails
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setScreenshotProtection" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }

                    "copySensitiveText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val isSensitive = call.argument<Boolean>("isSensitive") ?: false
                        val clearAfterSeconds = call.argument<Int>("clearAfterSeconds") ?: 30
                        copyTextSafely(text, isSensitive, clearAfterSeconds)
                        result.success(null)
                    }

                    "clearClipboardNow" -> {
                        clearClipboard()
                        result.success(null)
                    }

                    "canAuthenticateBiometrics" -> {
                        val mgr = BiometricManager.from(this)
                        val code = mgr.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                        val status = when (code) {
                            BiometricManager.BIOMETRIC_SUCCESS -> "available"
                            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "none_enrolled"
                            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "no_hardware"
                            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "hw_unavailable"
                            else -> "unavailable"
                        }
                        result.success(
                            mapOf(
                                "available" to (code == BiometricManager.BIOMETRIC_SUCCESS),
                                "status" to status
                            )
                        )
                    }

                    "hasBiometricVaultKey" -> {
                        result.success(VaultKeystoreHelper.hasBiometricKey(this))
                    }

                    "enrollBiometricVaultKey" -> {
                        val dekBase64 = call.argument<String>("dekBase64")
                        if (dekBase64.isNullOrEmpty()) {
                            result.error("INVALID_ARG", "Missing vault key bytes.", null)
                        } else {
                            enrollBiometricDek(dekBase64, result)
                        }
                    }

                    "unlockBiometricVaultKey" -> {
                        unlockBiometricDek(result)
                    }

                    "clearBiometricVaultKey" -> {
                        VaultKeystoreHelper.clearBiometricKey(this)
                        result.success(null)
                    }

                    "protectOfflineBlob" -> {
                        val fileKey = call.argument<String>("fileKey") ?: ""
                        val payload = call.argument<String>("payload") ?: ""
                        VaultKeystoreHelper.protectBlob(this, fileKey, payload)
                        result.success(null)
                    }

                    "unprotectOfflineBlob" -> {
                        val fileKey = call.argument<String>("fileKey") ?: ""
                        result.success(VaultKeystoreHelper.unprotectBlob(this, fileKey))
                    }

                    "clearOfflineBlob" -> {
                        val fileKey = call.argument<String>("fileKey") ?: ""
                        VaultKeystoreHelper.deleteBlob(this, fileKey)
                        result.success(null)
                    }

                    "syncAutofillIndex" -> {
                        val payloadJson = call.argument<String>("payloadJson") ?: ""
                        if (payloadJson.isNotEmpty()) {
                            VaultKeystoreHelper.saveAutofillIndex(this, payloadJson)
                        }
                        result.success(null)
                    }

                    "clearAutofillIndex" -> {
                        VaultKeystoreHelper.clearAutofillIndex(this)
                        result.success(null)
                    }

                    "getAutofillStatus" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val afm = getSystemService(AutofillManager::class.java)
                            result.success(
                                mapOf(
                                    "supported" to (afm != null && afm.isAutofillSupported),
                                    "isDefaultProvider" to (afm != null && afm.hasEnabledAutofillServices())
                                )
                            )
                        } else {
                            result.success(mapOf("supported" to false, "isDefaultProvider" to false))
                        }
                    }

                    "openAutofillSystemSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_REQUEST_SET_DEFAULT_AUTOFILL_SERVICE).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun copyTextSafely(text: String, isSensitive: Boolean, clearAfterSeconds: Int) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("VaultX", text)
        if (isSensitive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        clipboard.setPrimaryClip(clip)

        clipboardClearRunnable?.let { mainHandler.removeCallbacks(it) }
        if (isSensitive && clearAfterSeconds > 0) {
            val runnable = Runnable {
                val currentText = clipboard.primaryClip?.getItemAt(0)?.text?.toString()
                if (currentText == text) {
                    clearClipboard()
                }
            }
            clipboardClearRunnable = runnable
            mainHandler.postDelayed(runnable, clearAfterSeconds * 1000L)
        }
    }

    private fun clearClipboard() {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    private fun enrollBiometricDek(dekBase64: String, result: MethodChannel.Result) {
        val cipher = try {
            VaultKeystoreHelper.createBiometricEncryptCipher()
        } catch (e: Exception) {
            result.error("KEYSTORE_ERROR", e.message ?: "Unable to initialize Keystore cipher.", null)
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    val authedCipher = authResult.cryptoObject?.cipher
                    if (authedCipher == null) {
                        result.error("BIOMETRIC_ERROR", "Missing authenticated cipher.", null)
                        return
                    }
                    try {
                        VaultKeystoreHelper.saveBiometricWrappedDek(
                            this@MainActivity,
                            authedCipher,
                            dekBase64
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WRAP_ERROR", e.message ?: "Failed to wrap vault key.", null)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    result.error("BIOMETRIC_CANCELLED", errString.toString(), null)
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Enable Biometric Unlock")
            .setSubtitle("Protect your locally cached VaultX encryption key")
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    }

    private fun unlockBiometricDek(result: MethodChannel.Result) {
        val cipher = try {
            VaultKeystoreHelper.createBiometricDecryptCipher(this)
        } catch (_: KeyPermanentlyInvalidatedException) {
            result.error(
                "BIOMETRIC_INVALIDATED",
                "Device biometrics changed. Unlock once with your Master Password to re-enable biometrics.",
                null
            )
            return
        } catch (e: Exception) {
            result.error("KEYSTORE_ERROR", e.message ?: "Unable to read biometric key.", null)
            return
        }

        if (cipher == null) {
            result.error("NO_BIOMETRIC_KEY", "Biometric unlock is not enrolled.", null)
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    val authedCipher = authResult.cryptoObject?.cipher
                    if (authedCipher == null) {
                        result.error("BIOMETRIC_ERROR", "Missing authenticated cipher.", null)
                        return
                    }
                    var dekBytes: ByteArray? = null
                    try {
                        dekBytes = VaultKeystoreHelper.unwrapBiometricDekBytes(
                            this@MainActivity,
                            authedCipher
                        )
                        if (dekBytes == null) {
                            result.error("NO_BIOMETRIC_KEY", "Wrapped key missing.", null)
                            return
                        }
                        val encoded = Base64.encodeToString(dekBytes, Base64.NO_WRAP)
                        result.success(encoded)
                    } catch (e: Exception) {
                        result.error("UNWRAP_ERROR", e.message ?: "Failed to unwrap vault key.", null)
                    } finally {
                        if (dekBytes != null) {
                            Arrays.fill(dekBytes, 0.toByte())
                        }
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    result.error("BIOMETRIC_CANCELLED", errString.toString(), null)
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock VaultX")
            .setSubtitle("Verify your identity to decrypt your vault")
            .setNegativeButtonText("Use Master Password")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    }
}
