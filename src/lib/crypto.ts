import { argon2id } from 'hash-wasm';
import type { CredentialPayload, KdfParams, VaultMasterConfig } from '../types/vault';

export const DEFAULT_KDF_PARAMS: KdfParams = {
  algorithm: 'Argon2id',
  memoryKiB: 65536, // 64 MiB
  iterations: 3,
  parallelism: 1,
};

export class InvalidMasterPasswordError extends Error {
  constructor(message = 'Incorrect master password or corrupted vault key.') {
    super(message);
    this.name = 'InvalidMasterPasswordError';
  }
}

export class InvalidRecoveryKeyError extends Error {
  constructor(message = 'Invalid recovery key. Please verify all characters.') {
    super(message);
    this.name = 'InvalidRecoveryKeyError';
  }
}

export function generateRandomBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
}

export function toBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

export function fromBase64(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export function wipeBytes(bytes: Uint8Array | null | undefined): void {
  if (bytes) {
    bytes.fill(0);
  }
}

/**
 * Derives a 256-bit AES-GCM Key Encryption Key (KEK) from a secret and salt using Argon2id.
 */
export async function deriveArgon2idKey(
  secret: string,
  salt: Uint8Array,
  params: KdfParams = DEFAULT_KDF_PARAMS
): Promise<CryptoKey> {
  const rawHash = await argon2id({
    password: secret,
    salt,
    parallelism: params.parallelism,
    iterations: params.iterations,
    memorySize: params.memoryKiB,
    hashLength: 32,
    outputType: 'binary',
  });

  try {
    return await crypto.subtle.importKey(
      'raw',
      new Uint8Array(rawHash),
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt']
    );
  } finally {
    wipeBytes(rawHash);
  }
}

/**
 * Generates a high-entropy 256-bit (32-byte) recovery key formatted for human transcription.
 * Uses unambiguous Crockford-style Base32 characters grouped in 4-character blocks.
 */
export function generateRecoveryKey(): string {
  const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // 32 unambiguous chars (5 bits/char)
  // 52 chars * 5 bits = 260 bits (>= 256 bits)
  const randomBytes = generateRandomBytes(52);
  let raw = '';
  for (let i = 0; i < 52; i++) {
    raw += alphabet[randomBytes[i] & 31];
  }
  wipeBytes(randomBytes);

  const groups: string[] = [];
  for (let i = 0; i < raw.length; i += 4) {
    groups.push(raw.slice(i, i + 4));
  }
  return `VX-${groups.join('-')}`;
}

export function normalizeRecoveryKey(input: string): string {
  return input.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function getRecoveryKeyHint(recoveryKey: string): string {
  const normalized = normalizeRecoveryKey(recoveryKey);
  return `••••-${normalized.slice(-4)}`;
}

async function wrapVaultKeyBytes(
  vaultKeyBytes: Uint8Array,
  kek: CryptoKey
): Promise<{ ciphertext: string; iv: string }> {
  const iv = generateRandomBytes(12);
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: new Uint8Array(iv) },
    kek,
    new Uint8Array(vaultKeyBytes)
  );
  return {
    ciphertext: toBase64(new Uint8Array(encrypted)),
    iv: toBase64(iv),
  };
}

async function unwrapVaultKeyBytes(
  wrappedBase64: string,
  ivBase64: string,
  kek: CryptoKey
): Promise<Uint8Array> {
  const wrapped = fromBase64(wrappedBase64);
  const iv = fromBase64(ivBase64);
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: new Uint8Array(iv) },
    kek,
    new Uint8Array(wrapped)
  );
  return new Uint8Array(decrypted);
}

export async function importNonExtractableVaultKey(rawBytes: Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    new Uint8Array(rawBytes),
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export interface VaultInitializationResult {
  vaultKey: CryptoKey;
  recoveryKey: string;
  configData: Omit<VaultMasterConfig, 'userId' | 'createdAt' | 'updatedAt'>;
}

/**
 * Creates a brand-new 256-bit Vault Data Encryption Key (DEK), derives KEKs with Argon2id
 * for both the Master Password and a generated 256-bit Recovery Key, and wraps the DEK.
 */
export async function initializeVaultKeys(
  masterPassword: string,
  kdfParams: KdfParams = DEFAULT_KDF_PARAMS
): Promise<VaultInitializationResult> {
  const vaultKeyBytes = generateRandomBytes(32);
  const masterSalt = generateRandomBytes(16);
  const recoverySalt = generateRandomBytes(16);
  const recoveryKey = generateRecoveryKey();

  try {
    const masterKek = await deriveArgon2idKey(masterPassword, masterSalt, kdfParams);
    const wrappedMaster = await wrapVaultKeyBytes(vaultKeyBytes, masterKek);

    const recoveryKek = await deriveArgon2idKey(
      normalizeRecoveryKey(recoveryKey),
      recoverySalt,
      kdfParams
    );
    const wrappedRecovery = await wrapVaultKeyBytes(vaultKeyBytes, recoveryKek);

    const vaultKey = await importNonExtractableVaultKey(vaultKeyBytes);

    return {
      vaultKey,
      recoveryKey,
      configData: {
        kdfAlgorithm: 'Argon2id',
        kdfMemoryKiB: kdfParams.memoryKiB,
        kdfIterations: kdfParams.iterations,
        kdfParallelism: kdfParams.parallelism,
        masterSalt: toBase64(masterSalt),
        wrappedVaultKey: wrappedMaster.ciphertext,
        wrappedVaultKeyIv: wrappedMaster.iv,
        recoverySalt: toBase64(recoverySalt),
        recoveryWrappedVaultKey: wrappedRecovery.ciphertext,
        recoveryWrappedVaultKeyIv: wrappedRecovery.iv,
        recoveryKeyHint: getRecoveryKeyHint(recoveryKey),
        keyVersion: 1,
      },
    };
  } finally {
    wipeBytes(vaultKeyBytes);
  }
}

/**
 * Unlocks the vault using the user's Master Password and stored Argon2id metadata.
 */
export async function unlockVaultWithMasterPassword(
  masterPassword: string,
  config: VaultMasterConfig
): Promise<CryptoKey> {
  const salt = fromBase64(config.masterSalt);
  const kek = await deriveArgon2idKey(masterPassword, salt, {
    algorithm: config.kdfAlgorithm,
    memoryKiB: config.kdfMemoryKiB,
    iterations: config.kdfIterations,
    parallelism: config.kdfParallelism,
  });

  let rawVaultKey: Uint8Array | null = null;
  try {
    rawVaultKey = await unwrapVaultKeyBytes(
      config.wrappedVaultKey,
      config.wrappedVaultKeyIv,
      kek
    );
    return await importNonExtractableVaultKey(rawVaultKey);
  } catch {
    throw new InvalidMasterPasswordError();
  } finally {
    wipeBytes(rawVaultKey);
  }
}

/**
 * Recovers vault access using the 256-bit Recovery Key.
 */
export async function unlockVaultWithRecoveryKey(
  recoveryKeyInput: string,
  config: VaultMasterConfig
): Promise<CryptoKey> {
  const normalized = normalizeRecoveryKey(recoveryKeyInput);
  if (normalized.length < 32) {
    throw new InvalidRecoveryKeyError();
  }

  const salt = fromBase64(config.recoverySalt);
  const kek = await deriveArgon2idKey(normalized, salt, {
    algorithm: config.kdfAlgorithm,
    memoryKiB: config.kdfMemoryKiB,
    iterations: config.kdfIterations,
    parallelism: config.kdfParallelism,
  });

  let rawVaultKey: Uint8Array | null = null;
  try {
    rawVaultKey = await unwrapVaultKeyBytes(
      config.recoveryWrappedVaultKey,
      config.recoveryWrappedVaultKeyIv,
      kek
    );
    return await importNonExtractableVaultKey(rawVaultKey);
  } catch {
    throw new InvalidRecoveryKeyError();
  } finally {
    wipeBytes(rawVaultKey);
  }
}

/**
 * Re-wraps the Vault DEK with a new Master Password (verifies current Master Password or Recovery Key first).
 */
export async function rotateMasterPasswordWrapper(
  authMethod: { type: 'master'; currentMasterPassword: string } | { type: 'recovery'; recoveryKey: string },
  newMasterPassword: string,
  config: VaultMasterConfig
): Promise<{
  kdfAlgorithm: 'Argon2id';
  kdfMemoryKiB: number;
  kdfIterations: number;
  kdfParallelism: number;
  masterSalt: string;
  wrappedVaultKey: string;
  wrappedVaultKeyIv: string;
  keyVersion: number;
  vaultKey: CryptoKey;
}> {
  const params: KdfParams = {
    algorithm: 'Argon2id',
    memoryKiB: config.kdfMemoryKiB,
    iterations: config.kdfIterations,
    parallelism: config.kdfParallelism,
  };

  let rawVaultKey: Uint8Array | null = null;
  try {
    if (authMethod.type === 'master') {
      const oldKek = await deriveArgon2idKey(
        authMethod.currentMasterPassword,
        fromBase64(config.masterSalt),
        params
      );
      try {
        rawVaultKey = await unwrapVaultKeyBytes(config.wrappedVaultKey, config.wrappedVaultKeyIv, oldKek);
      } catch {
        throw new InvalidMasterPasswordError('Current master password is incorrect.');
      }
    } else {
      const recoveryKek = await deriveArgon2idKey(
        normalizeRecoveryKey(authMethod.recoveryKey),
        fromBase64(config.recoverySalt),
        params
      );
      try {
        rawVaultKey = await unwrapVaultKeyBytes(
          config.recoveryWrappedVaultKey,
          config.recoveryWrappedVaultKeyIv,
          recoveryKek
        );
      } catch {
        throw new InvalidRecoveryKeyError();
      }
    }

    const newSalt = generateRandomBytes(16);
    const newKek = await deriveArgon2idKey(newMasterPassword, newSalt, params);
    const wrapped = await wrapVaultKeyBytes(rawVaultKey, newKek);
    const vaultKey = await importNonExtractableVaultKey(rawVaultKey);

    return {
      kdfAlgorithm: 'Argon2id',
      kdfMemoryKiB: params.memoryKiB,
      kdfIterations: params.iterations,
      kdfParallelism: params.parallelism,
      masterSalt: toBase64(newSalt),
      wrappedVaultKey: wrapped.ciphertext,
      wrappedVaultKeyIv: wrapped.iv,
      keyVersion: config.keyVersion + 1,
      vaultKey,
    };
  } finally {
    wipeBytes(rawVaultKey);
  }
}

/**
 * Generates a fresh Recovery Key and re-wraps the existing Vault DEK (requires current Master Password).
 */
export async function rotateRecoveryKeyWrapper(
  currentMasterPassword: string,
  config: VaultMasterConfig
): Promise<{
  recoveryKey: string;
  recoverySalt: string;
  recoveryWrappedVaultKey: string;
  recoveryWrappedVaultKeyIv: string;
  recoveryKeyHint: string;
}> {
  const params: KdfParams = {
    algorithm: config.kdfAlgorithm,
    memoryKiB: config.kdfMemoryKiB,
    iterations: config.kdfIterations,
    parallelism: config.kdfParallelism,
  };

  const masterKek = await deriveArgon2idKey(
    currentMasterPassword,
    fromBase64(config.masterSalt),
    params
  );

  let rawVaultKey: Uint8Array | null = null;
  try {
    try {
      rawVaultKey = await unwrapVaultKeyBytes(config.wrappedVaultKey, config.wrappedVaultKeyIv, masterKek);
    } catch {
      throw new InvalidMasterPasswordError('Master password verification failed.');
    }

    const newRecoveryKey = generateRecoveryKey();
    const newRecoverySalt = generateRandomBytes(16);
    const recoveryKek = await deriveArgon2idKey(
      normalizeRecoveryKey(newRecoveryKey),
      newRecoverySalt,
      params
    );
    const wrapped = await wrapVaultKeyBytes(rawVaultKey, recoveryKek);

    return {
      recoveryKey: newRecoveryKey,
      recoverySalt: toBase64(newRecoverySalt),
      recoveryWrappedVaultKey: wrapped.ciphertext,
      recoveryWrappedVaultKeyIv: wrapped.iv,
      recoveryKeyHint: getRecoveryKeyHint(newRecoveryKey),
    };
  } finally {
    wipeBytes(rawVaultKey);
  }
}

/**
 * Encrypts a credential payload with AES-256-GCM using a fresh 96-bit nonce per operation.
 */
export async function encryptCredentialPayload(
  vaultKey: CryptoKey,
  payload: CredentialPayload
): Promise<{ ciphertext: string; iv: string }> {
  const iv = generateRandomBytes(12);
  const encoder = new TextEncoder();
  const plaintextBytes = encoder.encode(JSON.stringify(payload));

  try {
    const encryptedBuffer = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: new Uint8Array(iv) },
      vaultKey,
      plaintextBytes
    );
    return {
      ciphertext: toBase64(new Uint8Array(encryptedBuffer)),
      iv: toBase64(iv),
    };
  } finally {
    wipeBytes(plaintextBytes);
  }
}

/**
 * Decrypts an AES-256-GCM credential record back into its structured payload.
 */
export async function decryptCredentialPayload(
  vaultKey: CryptoKey,
  ciphertextBase64: string,
  ivBase64: string
): Promise<CredentialPayload> {
  const ciphertext = fromBase64(ciphertextBase64);
  const iv = fromBase64(ivBase64);
  const decryptedBuffer = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: new Uint8Array(iv) },
    vaultKey,
    new Uint8Array(ciphertext)
  );
  const decoder = new TextDecoder();
  const json = decoder.decode(decryptedBuffer);
  return JSON.parse(json) as CredentialPayload;
}
