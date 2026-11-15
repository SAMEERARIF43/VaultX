package com.vaultx.app.autofill

import android.app.Activity
import android.app.assist.AssistStructure
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RemoteViews
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.vaultx.app.R
import com.vaultx.app.security.VaultKeystoreHelper
import org.json.JSONArray
import java.util.Arrays

@RequiresApi(Build.VERSION_CODES.O)
class VaultXAutofillAuthActivity : FragmentActivity() {

    private data class AutofillCandidate(
        val id: String,
        val title: String,
        val username: String,
        val password: String,
        val url: String,
        val packageName: String
    )

    private var matchedCandidates: List<AutofillCandidate> = emptyList()
    private var parsedFields: ParsedAutofillFields? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val structure: AssistStructure? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(AutofillManager.EXTRA_ASSIST_STRUCTURE, AssistStructure::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(AutofillManager.EXTRA_ASSIST_STRUCTURE)
        }

        if (structure == null) {
            cancelWithToast("Autofill request context unavailable.")
            return
        }

        val fields = AutofillFieldParser.parse(structure)
        parsedFields = fields
        if (!fields.hasSupportedFields) {
            cancelWithToast("No compatible login fields detected.")
            return
        }

        authenticateAndDecrypt(fields)
    }

    private fun authenticateAndDecrypt(fields: ParsedAutofillFields) {
        val biometricManager = BiometricManager.from(this)
        if (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) !=
            BiometricManager.BIOMETRIC_SUCCESS
        ) {
            cancelWithToast("Strong biometric authentication is required for Autofill.")
            return
        }

        val decryptCipher = try {
            VaultKeystoreHelper.createBiometricDecryptCipher(this)
        } catch (_: Exception) {
            cancelWithToast("Biometric key invalidated. Unlock VaultX with your Master Password.")
            return
        }

        if (decryptCipher == null) {
            cancelWithToast("Enable Biometric Unlock in VaultX first.")
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    val cipher = result.cryptoObject?.cipher
                    if (cipher == null) {
                        cancelWithToast("Biometric cryptographic verification failed.")
                        return
                    }
                    handleAuthenticatedCipher(cipher, fields)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    setResult(Activity.RESULT_CANCELED)
                    finish()
                }

                override fun onAuthenticationFailed() {
                    // Wait for retry or user cancellation
                }
            }
        )

        val targetLabel = fields.webDomain ?: fields.packageName ?: "application"
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("VaultX Autofill")
            .setSubtitle("Verify identity to fill credentials for $targetLabel")
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(decryptCipher))
    }

    private fun handleAuthenticatedCipher(cipher: javax.crypto.Cipher, fields: ParsedAutofillFields) {
        var dekBytes: ByteArray? = null
        try {
            dekBytes = VaultKeystoreHelper.unwrapBiometricDekBytes(this, cipher)
            if (dekBytes == null) {
                cancelWithToast("Vault key unavailable. Unlock VaultX app first.")
                return
            }

            val decryptedJson = VaultKeystoreHelper.decryptAutofillIndexWithDek(this, dekBytes)
            if (decryptedJson == null) {
                cancelWithToast("No synced autofill records found.")
                return
            }

            val root = org.json.JSONObject(decryptedJson)
            val entries = root.optJSONArray("entries") ?: JSONArray()
            val matches = mutableListOf<AutofillCandidate>()

            for (i in 0 until entries.length()) {
                val obj = entries.getJSONObject(i)
                val url = obj.optString("url", "")
                val pkg = obj.optString("packageName", "")
                if (AutofillDomainMatcher.matches(
                        recordUrl = url,
                        recordPackageName = pkg,
                        targetWebDomain = fields.webDomain,
                        targetAndroidPackage = fields.packageName
                    )
                ) {
                    matches.add(
                        AutofillCandidate(
                            id = obj.optString("id", ""),
                            title = obj.optString("title", "Account"),
                            username = obj.optString("username", ""),
                            password = obj.optString("password", ""),
                            url = url,
                            packageName = pkg
                        )
                    )
                }
            }

            if (matches.isEmpty()) {
                val target = fields.webDomain ?: fields.packageName ?: "this destination"
                cancelWithToast("No VaultX logins match $target.")
                return
            }

            matchedCandidates = matches
            if (matches.size == 1) {
                returnDatasetForCandidate(matches.first(), fields)
            } else {
                renderMultiAccountPicker(matches, fields)
            }
        } catch (_: Exception) {
            cancelWithToast("Failed to decrypt VaultX autofill records.")
        } finally {
            if (dekBytes != null) {
                Arrays.fill(dekBytes, 0.toByte())
            }
        }
    }

    private fun returnDatasetForCandidate(candidate: AutofillCandidate, fields: ParsedAutofillFields) {
        val datasetBuilder = Dataset.Builder()
        val presentation = RemoteViews(packageName, R.layout.vaultx_autofill_suggestion).apply {
            setTextViewText(R.id.autofill_title, candidate.title)
            setTextViewText(
                R.id.autofill_subtitle,
                candidate.username.ifEmpty { "Saved VaultX account" }
            )
        }

        var attachedAny = false
        for (id in fields.usernameIds) {
            if (candidate.username.isNotEmpty()) {
                datasetBuilder.setValue(id, AutofillValue.forText(candidate.username), presentation)
                attachedAny = true
            }
        }
        for (id in fields.passwordIds) {
            if (candidate.password.isNotEmpty()) {
                datasetBuilder.setValue(id, AutofillValue.forText(candidate.password), presentation)
                attachedAny = true
            }
        }

        if (!attachedAny) {
            cancelWithToast("Selected entry has no fillable username or password.")
            return
        }

        val reply = Intent().apply {
            putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, datasetBuilder.build())
        }
        setResult(Activity.RESULT_OK, reply)
        finish()
    }

    private fun renderMultiAccountPicker(
        candidates: List<AutofillCandidate>,
        fields: ParsedAutofillFields
    ) {
        val cardBg = GradientDrawable().apply {
            setColor(Color.parseColor("#FF0F172A"))
            cornerRadius = 36f
            setStroke(2, Color.parseColor("#FF1E293B"))
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = cardBg
            setPadding(44, 40, 44, 36)
        }

        val target = fields.webDomain ?: fields.packageName ?: "Account"
        root.addView(TextView(this).apply {
            text = "Choose VaultX Account"
            setTextColor(Color.parseColor("#FFF8FAFC"))
            textSize = 18f
            setPadding(0, 0, 0, 8)
        })
        root.addView(TextView(this).apply {
            text = "Verified match for $target"
            setTextColor(Color.parseColor("#FF94A3B8"))
            textSize = 13f
            setPadding(0, 0, 0, 28)
        })

        val scroll = ScrollView(this)
        val listLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        for (candidate in candidates) {
            val rowBg = GradientDrawable().apply {
                setColor(Color.parseColor("#FF1E293B"))
                cornerRadius = 24f
            }
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                background = rowBg
                setPadding(32, 24, 32, 24)
                isClickable = true
                setOnClickListener { returnDatasetForCandidate(candidate, fields) }
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 18 }

            row.addView(TextView(this).apply {
                text = candidate.title
                setTextColor(Color.parseColor("#FFF8FAFC"))
                textSize = 15f
            })
            row.addView(TextView(this).apply {
                text = candidate.username.ifEmpty { "Tap to fill password" }
                setTextColor(Color.parseColor("#FF10B981"))
                textSize = 13f
            })
            listLayout.addView(row, lp)
        }

        scroll.addView(listLayout)
        root.addView(
            scroll,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        )

        root.addView(Button(this).apply {
            text = "Cancel"
            setTextColor(Color.parseColor("#FFCBD5E1"))
            setBackgroundColor(Color.TRANSPARENT)
            gravity = Gravity.CENTER
            setOnClickListener {
                setResult(Activity.RESULT_CANCELED)
                finish()
            }
        })

        setContentView(
            root,
            ViewGroup.LayoutParams(
                (resources.displayMetrics.widthPixels * 0.90).toInt(),
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
    }

    private fun cancelWithToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    override fun onDestroy() {
        matchedCandidates = emptyList()
        parsedFields = null
        super.onDestroy()
    }
}
