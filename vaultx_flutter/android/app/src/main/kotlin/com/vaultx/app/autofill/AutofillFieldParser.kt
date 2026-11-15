package com.vaultx.app.autofill

import android.app.assist.AssistStructure
import android.os.Build
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId
import androidx.annotation.RequiresApi

data class ParsedAutofillFields(
    val usernameIds: List<AutofillId>,
    val passwordIds: List<AutofillId>,
    val webDomain: String?,
    val packageName: String?
) {
    val allIds: List<AutofillId> get() = (usernameIds + passwordIds).distinct()
    val hasSupportedFields: Boolean get() = usernameIds.isNotEmpty() || passwordIds.isNotEmpty()
}

@RequiresApi(Build.VERSION_CODES.O)
object AutofillFieldParser {
    fun parse(structure: AssistStructure): ParsedAutofillFields {
        val usernameIds = mutableListOf<AutofillId>()
        val passwordIds = mutableListOf<AutofillId>()
        var detectedWebDomain: String? = null
        val packageName = structure.activityComponent?.packageName

        for (i in 0 until structure.windowNodeCount) {
            val rootNode = structure.getWindowNodeAt(i).rootViewNode
            detectedWebDomain = traverseNode(
                node = rootNode,
                usernameIds = usernameIds,
                passwordIds = passwordIds,
                currentWebDomain = detectedWebDomain
            )
        }

        return ParsedAutofillFields(
            usernameIds = usernameIds.distinct(),
            passwordIds = passwordIds.distinct(),
            webDomain = detectedWebDomain,
            packageName = packageName
        )
    }

    private fun traverseNode(
        node: AssistStructure.ViewNode,
        usernameIds: MutableList<AutofillId>,
        passwordIds: MutableList<AutofillId>,
        currentWebDomain: String?
    ): String? {
        var webDomain = currentWebDomain ?: node.webDomain
        val autofillId = node.autofillId

        if (autofillId != null && node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            val hints = node.autofillHints?.map { it.lowercase() }.orEmpty()
            val htmlType = node.htmlInfo?.attributes
                ?.firstOrNull { it.first.equals("type", ignoreCase = true) }
                ?.second
                ?.lowercase()
            val htmlName = node.htmlInfo?.attributes
                ?.firstOrNull {
                    it.first.equals("name", ignoreCase = true) ||
                        it.first.equals("autocomplete", ignoreCase = true)
                }
                ?.second
                ?.lowercase()

            val inputType = node.inputType
            val variation = inputType and InputType.TYPE_MASK_VARIATION
            val isPasswordInput = (inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_TEXT &&
                (variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                    variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                    variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD)
            val isEmailInput = (inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_TEXT &&
                (variation == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                    variation == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS)

            val isPasswordHint = hints.any {
                it.contains("password") || it == View.AUTOFILL_HINT_PASSWORD
            } || htmlType == "password" || (htmlName?.contains("password") == true)

            val isUsernameHint = hints.any {
                it == View.AUTOFILL_HINT_USERNAME ||
                    it == View.AUTOFILL_HINT_EMAIL_ADDRESS ||
                    it.contains("user") ||
                    it.contains("email")
            } || htmlType == "email" || isEmailInput ||
                (htmlName != null && (htmlName.contains("user") || htmlName.contains("email") || htmlName.contains("login")))

            if (isPasswordHint || isPasswordInput) {
                passwordIds.add(autofillId)
            } else if (isUsernameHint) {
                usernameIds.add(autofillId)
            }
        }

        for (i in 0 until node.childCount) {
            webDomain = traverseNode(
                node = node.getChildAt(i),
                usernameIds = usernameIds,
                passwordIds = passwordIds,
                currentWebDomain = webDomain
            )
        }

        return webDomain
    }
}
