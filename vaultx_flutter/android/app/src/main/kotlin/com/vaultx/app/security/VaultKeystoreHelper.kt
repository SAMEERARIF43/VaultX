package com.vaultx.app.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.util.Arrays
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object VaultKeystoreHelper {
    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    private const val BIOMETRIC_KEY_ALIAS = "vaultx_biometric_dek_v1"
    private const val STORAGE_KEY_ALIAS = "vaultx_storage_wrap_v1"

    private const val BIO_KEY_FILE = "vaultx_bio_key.json"
    private const val AUTOFILL_INDEX_FILE = "vaultx_autofill_index.enc"

    private fun keyStore(): KeyStore =
        KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    @Synchronized
    private fun getOrCreateBiometricKey(forceRecreate: Boolean = false): SecretKey {
        val ks = keyStore()
        if (forceRecreate && ks.containsAlias(BIOMETRIC_KEY_ALIAS)) {
            ks.deleteEntry(BIOMETRIC_KEY_ALIAS)
        }
        val existing = ks.getKey(BIOMETRIC_KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER
        )
        val builder = KeyGenParameterSpec.Builder(
            BIOMETRIC_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setInvalidatedByBiometricEnrollment(true)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG
            )
        }

        generator.init(builder.build())
        return generator.generateKey()
    }

    @Synchronized
    private fun getOrCreateStorageKey(): SecretKey {
        val ks = keyStore()
        val existing = ks.getKey(STORAGE_KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER
        )
        val builder = KeyGenParameterSpec.Builder(
            STORAGE_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)

        generator.init(builder.build())
        return generator.generateKey()
    }

    fun createBiometricEncryptCipher(): Cipher {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        return try {
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateBiometricKey(forceRecreate = false))
            cipher
        } catch (_: KeyPermanentlyInvalidatedException) {
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateBiometricKey(forceRecreate = true))
            cipher
        }
    }

    fun createBiometricDecryptCipher(context: Context): Cipher? {
        val file = File(context.noBackupFilesDir, BIO_KEY_FILE)
        if (!file.exists()) return null
        val json = JSONObject(file.readText(Charsets.UTF_8))
        val iv = Base64.decode(json.getString("iv"), Base64.DEFAULT)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val key = keyStore().getKey(BIOMETRIC_KEY_ALIAS, null) as? SecretKey ?: return null
        return try {
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
            cipher
        } catch (_: KeyPermanentlyInvalidatedException) {
            clearBiometricKey(context)
            throw KeyPermanentlyInvalidatedException("Biometrics changed on device.")
        }
    }

    fun hasBiometricKey(context: Context): Boolean {
        val file = File(context.noBackupFilesDir, BIO_KEY_FILE)
        return file.exists() && keyStore().containsAlias(BIOMETRIC_KEY_ALIAS)
    }

    fun saveBiometricWrappedDek(context: Context, cipher: Cipher, dekBase64: String) {
        val dekBytes = Base64.decode(dekBase64, Base64.DEFAULT)
        try {
            val wrapped = cipher.doFinal(dekBytes)
            val iv = cipher.iv
            val payload = JSONObject().apply {
                put("wrapped", Base64.encodeToString(wrapped, Base64.NO_WRAP))
                put("iv", Base64.encodeToString(iv, Base64.NO_WRAP))
            }
            File(context.noBackupFilesDir, BIO_KEY_FILE).writeText(
                payload.toString(),
                Charsets.UTF_8
            )
        } finally {
            Arrays.fill(dekBytes, 0.toByte())
        }
    }

    fun unwrapBiometricDekBytes(context: Context, cipher: Cipher): ByteArray? {
        val file = File(context.noBackupFilesDir, BIO_KEY_FILE)
        if (!file.exists()) return null
        val json = JSONObject(file.readText(Charsets.UTF_8))
        val wrapped = Base64.decode(json.getString("wrapped"), Base64.DEFAULT)
        return cipher.doFinal(wrapped)
    }

    fun clearBiometricKey(context: Context) {
        File(context.noBackupFilesDir, BIO_KEY_FILE).delete()
        val ks = keyStore()
        if (ks.containsAlias(BIOMETRIC_KEY_ALIAS)) {
            ks.deleteEntry(BIOMETRIC_KEY_ALIAS)
        }
    }

    private fun safeBlobFile(context: Context, key: String): File {
        val sanitized = key.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        return File(context.noBackupFilesDir, "vaultx_blob_$sanitized.enc")
    }

    fun protectBlob(context: Context, fileKey: String, plaintextJson: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateStorageKey())
        val ciphertext = cipher.doFinal(plaintextJson.toByteArray(Charsets.UTF_8))
        val envelope = JSONObject().apply {
            put("c", Base64.encodeToString(ciphertext, Base64.NO_WRAP))
            put("i", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
        }
        safeBlobFile(context, fileKey).writeText(envelope.toString(), Charsets.UTF_8)
    }

    fun unprotectBlob(context: Context, fileKey: String): String? {
        val file = safeBlobFile(context, fileKey)
        if (!file.exists()) return null
        val envelope = JSONObject(file.readText(Charsets.UTF_8))
        val ciphertext = Base64.decode(envelope.getString("c"), Base64.DEFAULT)
        val iv = Base64.decode(envelope.getString("i"), Base64.DEFAULT)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateStorageKey(), GCMParameterSpec(128, iv))
        val plaintext = cipher.doFinal(ciphertext)
        return String(plaintext, Charsets.UTF_8)
    }

    fun deleteBlob(context: Context, fileKey: String) {
        safeBlobFile(context, fileKey).delete()
    }

    fun saveAutofillIndex(context: Context, wrappedIndexJson: String) {
        // Wrap the DEK-encrypted autofill JSON once more with AndroidKeyStore storage key
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateStorageKey())
        val encrypted = cipher.doFinal(wrappedIndexJson.toByteArray(Charsets.UTF_8))
        val envelope = JSONObject().apply {
            put("c", Base64.encodeToString(encrypted, Base64.NO_WRAP))
            put("i", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
        }
        File(context.noBackupFilesDir, AUTOFILL_INDEX_FILE).writeText(
            envelope.toString(),
            Charsets.UTF_8
        )
    }

    fun hasAutofillIndex(context: Context): Boolean =
        File(context.noBackupFilesDir, AUTOFILL_INDEX_FILE).exists()

    fun clearAutofillIndex(context: Context) {
        File(context.noBackupFilesDir, AUTOFILL_INDEX_FILE).delete()
    }

    /**
     * Decrypts the autofill index using BOTH:
     * 1. AndroidKeyStore storage wrapper key, and
     * 2. User's 32-byte Vault DEK (which itself was unwrapped only via BiometricPrompt.CryptoObject).
     */
    fun decryptAutofillIndexWithDek(context: Context, dekBytes: ByteArray): String? {
        val file = File(context.noBackupFilesDir, AUTOFILL_INDEX_FILE)
        if (!file.exists()) return null

        val storageEnvelope = JSONObject(file.readText(Charsets.UTF_8))
        val storageCipher = Cipher.getInstance("AES/GCM/NoPadding")
        storageCipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateStorageKey(),
            GCMParameterSpec(128, Base64.decode(storageEnvelope.getString("i"), Base64.DEFAULT))
        )
        val innerJsonStr = String(
            storageCipher.doFinal(Base64.decode(storageEnvelope.getString("c"), Base64.DEFAULT)),
            Charsets.UTF_8
        )

        val innerEnvelope = JSONObject(innerJsonStr)
        val dekCiphertext = Base64.decode(innerEnvelope.getString("ciphertext"), Base64.DEFAULT)
        val dekIv = Base64.decode(innerEnvelope.getString("iv"), Base64.DEFAULT)

        val aesCipher = Cipher.getInstance("AES/GCM/NoPadding")
        val dekSpec = SecretKeySpec(dekBytes, "AES")
        aesCipher.init(Cipher.DECRYPT_MODE, dekSpec, GCMParameterSpec(128, dekIv))
        val plaintextBytes = aesCipher.doFinal(dekCiphertext)
        return String(plaintextBytes, Charsets.UTF_8)
    }
}
