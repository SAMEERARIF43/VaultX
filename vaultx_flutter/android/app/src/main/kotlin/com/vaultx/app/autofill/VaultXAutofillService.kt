package com.vaultx.app.autofill

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import com.vaultx.app.R
import com.vaultx.app.security.VaultKeystoreHelper

@RequiresApi(Build.VERSION_CODES.O)
class VaultXAutofillService : AutofillService() {

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        val contexts = request.fillContexts
        if (contexts.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val structure = contexts.last().structure
        val parsed = AutofillFieldParser.parse(structure)
        if (!parsed.hasSupportedFields) {
            callback.onSuccess(null)
            return
        }

        // Ignore VaultX's own windows to avoid self-autofill loops
        if (parsed.packageName == packageName) {
            callback.onSuccess(null)
            return
        }

        // Require encrypted autofill index + biometric key enrollment before offering VaultX unlock
        if (!VaultKeystoreHelper.hasAutofillIndex(this) || !VaultKeystoreHelper.hasBiometricKey(this)) {
            callback.onSuccess(null)
            return
        }

        val authIntent = Intent(this, VaultXAutofillAuthActivity::class.java)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val sender = PendingIntent.getActivity(this, 4011, authIntent, pendingFlags).intentSender

        val presentation = RemoteViews(packageName, R.layout.vaultx_autofill_suggestion).apply {
            val targetLabel = parsed.webDomain ?: parsed.packageName ?: "this app"
            setTextViewText(R.id.autofill_title, "Unlock VaultX")
            setTextViewText(
                R.id.autofill_subtitle,
                "Authenticate to fill credentials for $targetLabel"
            )
        }

        val response = FillResponse.Builder()
            .setAuthentication(parsed.allIds.toTypedArray(), sender, presentation)
            .build()

        callback.onSuccess(response)
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // VaultX requires unlocking with the Master Password / biometric VaultKey before encrypting
        // new credentials into Firestore; never persist plaintext save payloads unauthenticated.
        callback.onSuccess()
    }
}
