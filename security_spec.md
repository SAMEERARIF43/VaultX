# VaultX Firestore Security Specification

## 1. Data Invariants
1. **Strict User Isolation**: Every document under `/users/{userId}` and its subcollections (`vaultConfig`, `settings`, `credentials`) is strictly accessible only when `request.auth != null`, `request.auth.uid == userId`, and `request.auth.token.email_verified == true`.
2. **Zero-Knowledge Storage**: No plaintext passwords, master passwords, or unwrapped encryption keys are permitted in any Firestore schema. `EncryptedCredentialRecord` accepts only `id`, `userId`, `ciphertext`, `iv`, `keyVersion`, `createdAt`, and `updatedAt`.
3. **Immutable Ownership & Creation Timestamps**: `uid` / `userId`, `id`, and `createdAt` can never be mutated after creation. `createdAt == request.time` on creation, `updatedAt == request.time` on creation and update.
4. **Shadow Field Prevention**: Every `create` validates exact required and allowed keys (`hasAll` + `hasOnly`), and every `update` enumerates action-specific `affectedKeys().hasOnly(...)` along with full `isValid[Entity](incoming())` checks.
5. **Path & Size Guards**: Document IDs must match `^[a-zA-Z0-9_\-]+$` with max length 128; all strings enforce strict upper and lower size bounds.

## 2. The "Dirty Dozen" Adversarial Payloads (Must Return PERMISSION_DENIED)
1. **Unauthenticated Read**: `GET /users/alice/credentials/cred1` with `auth = null`.
2. **Cross-User Read**: `GET /users/alice/credentials/cred1` with `auth.uid = 'bob'`, `email_verified = true`.
3. **Unverified Email Write**: `CREATE /users/alice` with `auth.uid = 'alice'`, `email_verified = false`.
4. **Cross-User Credential Injection**: `CREATE /users/alice/credentials/cred1` with `auth.uid = 'bob'` and `userId = 'bob'`.
5. **Owner Spoofing in Payload**: `CREATE /users/alice/credentials/cred1` with `auth.uid = 'alice'` and `userId = 'bob'`.
6. **Shadow / Ghost Field Injection**: `CREATE /users/alice` with extra field `isAdmin: true`.
7. **Plaintext Password Injection**: `CREATE /users/alice/credentials/cred1` with extra field `password: 'secret123'`.
8. **Timestamp Forgery on Create**: `CREATE /users/alice/credentials/cred1` with `createdAt: '2020-01-01T00:00:00Z'` instead of `request.time`.
9. **Immutable `createdAt` Mutation on Update**: `UPDATE /users/alice/credentials/cred1` changing `createdAt` alongside `ciphertext`.
10. **Path Variable ID Poisoning**: `CREATE /users/alice/credentials/invalid$id!with.dots` or >128 char ID.
11. **Denial-of-Wallet Oversized Ciphertext**: `CREATE /users/alice/credentials/cred1` with `ciphertext` > 32,768 chars.
12. **Blanket List Query Scraping**: `LIST /users/alice/credentials` as `auth.uid = 'bob'`.
