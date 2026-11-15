# VaultX Flutter Android Client (`vaultx_flutter`)

Android-first Flutter client for **VaultX**, engineered for full zero-knowledge cryptographic and Firestore schema interoperability with the existing VaultX React/TypeScript web application.

## Preserved Architecture & Invariants

- **Firebase Project**: `arctic-digit-87cdj`
- **Named Cloud Firestore Database**: `ai-studio-8494ca94-6f4d-44cf-b5ad-d01b20e7a342` (enforced via `FirestoreConfig.db`, never `(default)`)
- **Firestore Security Rules**: Preserved untouched in root `firestore.rules`
- **Web Application**: Preserved untouched in `../src/`
- **Client-Side Cryptography**:
  - **KDF**: Argon2id v1.3 (`65536 KiB` = 64 MiB memory, `3` iterations, `parallelism: 1`, `32`-byte derived key, `16`-byte random salt)
  - **Cipher**: AES-256-GCM (`12`-byte unique CSPRNG nonce per encryption, `16`-byte authentication tag appended as `ciphertext || tag`, standard padded Base64)
  - **Recovery Key Format**: `VX-XXXX-...` (256-bit Base32 recovery key wrapping the 256-bit DEK)

## Implemented Features (`vaultx_flutter/`)

1. **Authentication & Zero-Knowledge Lifecycle**
   - Onboarding, Email/Password sign-in & sign-up, Google Sign-In (`google_sign_in`), Password Reset, Email Verification Gate, Master Password Setup, Recovery Key Ceremony, and Vault Unlock.
2. **Android Keystore + Biometric Unlock**
   - Uses hardware-backed `AndroidKeyStore` (`vaultx_biometric_dek_v1`) requiring `BiometricPrompt.CryptoObject` authentication per unlock (`VaultKeystoreHelper.kt`), without weakening Master Password encryption.
3. **Genuine Android AutofillService (`VaultXAutofillService`)**
   - Native Android `AutofillService` + `VaultXAutofillAuthActivity` (`FLAG_SECURE` + `BiometricPrompt.CryptoObject`), strict domain/package matcher (`AutofillDomainMatcher.kt`), and DEK-encrypted autofill index (`zero plaintext on disk`).
4. **Screen & Clipboard Protection**
   - Window `FLAG_SECURE` blocking screenshots and Android recents thumbnails.
   - Android 13+ `ClipDescription.EXTRA_IS_SENSITIVE` sensitive clipboard marking + automatic timed wipe countdown banner.
5. **Encrypted Offline Cache & Conflict Detection**
   - Keystore-wrapped encrypted offline snapshot (`OfflineVaultStore`) + pending offline mutation queue with timestamp conflict resolution.
6. **RFC 6238 Authenticator (TOTP)**
   - Built-in live 6/8-digit code generator, `otpauth://totp/...` QR scanner (`mobile_scanner`) & URI parser, manual Base32 entry, and local QR view (`qr_flutter`).
7. **Security Center & Privacy-Preserving Breach Audit**
   - Local weak, reused, stale (>180 days), expiring, and missing-metadata checks.
   - Explicit external HaveIBeenPwned k-anonymity check sending **only the first 5 hex characters of local SHA-1 hashes** (`Add-Padding: true`).
8. **Secure Digital Wallet, Generator, Encrypted Backups & E2EE Sharing**
   - Typed records for Logins, App Logins, Secure Notes, Wi-Fi Credentials, Payment Cards, Identities, License Keys, Recovery Codes, and 2FA Tokens.
   - Cryptographically secure Password & Passphrase Generator (`Random.secure()` + rejection sampling).
   - Argon2id + AES-256-GCM `.vaultx` encrypted backup export & restore (`share_plus`, `file_picker`).
   - Client-side `VaultX-Share-v1` ephemeral sharing & `VaultX-EmergencyBundle-v1` escrow bundle foundation.

## Local Development, Android Autofill Setup & Testing

Run these commands on your workstation with Flutter SDK (`>= 3.24`) and Android SDK installed:

```bash
cd vaultx_flutter

# 1. Install Dart & Flutter dependencies
flutter pub get

# 2. Configure native Firebase Android/iOS files using existing project
flutterfire configure --project=arctic-digit-87cdj

# 3. Run static analysis
flutter analyze

# 4. Run full Dart test suite (including Web <-> Flutter crypto interoperability)
flutter test

# 5. Run Android app on connected device or emulator
flutter run
```

### Enabling VaultX Android Autofill on Device
1. Sign into VaultX, unlock your vault, and enable **Biometric Unlock** in **Settings**.
2. Open the **Android Autofill** section under **Tools**.
3. Ensure **Sync Encrypted Autofill Index** is toggled on.
4. Tap **Select VaultX as Autofill Service** (or open Android Settings → *Passwords & accounts* → *Autofill service*) and select **VaultX**.
