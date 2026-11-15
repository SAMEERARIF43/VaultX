import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  decryptCredentialPayload,
  encryptCredentialPayload,
  fromBase64,
  InvalidMasterPasswordError,
  InvalidRecoveryKeyError,
  toBase64,
  unlockVaultWithMasterPassword,
  unlockVaultWithRecoveryKey,
} from '../crypto';
import type { CredentialPayload, VaultMasterConfig } from '../../types/vault';

interface InteropVectorFile {
  schemaVersion: number;
  generatedBy: string;
  kdfParams: {
    algorithm: 'Argon2id';
    memoryKiB: number;
    iterations: number;
    parallelism: number;
  };
  masterPassword: string;
  recoveryKey: string;
  configData: VaultMasterConfig;
  credentials: Array<{
    id: string;
    keyVersion: number;
    ciphertext: string;
    iv: string;
    expectedPayload: CredentialPayload;
  }>;
}

const TS_VECTOR_PATH = path.resolve(
  process.cwd(),
  'vaultx_flutter/test/fixtures/ts_interop_vectors.json'
);
const DART_VECTOR_PATH = path.resolve(
  process.cwd(),
  'vaultx_flutter/test/fixtures/dart_interop_vectors.json'
);

function flipByteInBase64(base64: string, byteIndexFromStart: number): string {
  const bytes = fromBase64(base64);
  const idx =
    byteIndexFromStart >= 0
      ? byteIndexFromStart
      : Math.max(0, bytes.length + byteIndexFromStart);
  bytes[idx] ^= 0xff;
  return toBase64(bytes);
}

describe('Cross-Platform Cryptographic Interoperability Vectors', () => {
  const tsVectors = JSON.parse(
    fs.readFileSync(TS_VECTOR_PATH, 'utf8')
  ) as InteropVectorFile;

  it('unlocks production-parameter TS vectors with Master Password and Recovery Key', async () => {
    expect(tsVectors.kdfParams).toEqual({
      algorithm: 'Argon2id',
      memoryKiB: 65536,
      iterations: 3,
      parallelism: 1,
    });

    const keyFromMaster = await unlockVaultWithMasterPassword(
      tsVectors.masterPassword,
      tsVectors.configData
    );
    const keyFromRecovery = await unlockVaultWithRecoveryKey(
      tsVectors.recoveryKey.toLowerCase().replace(/-/g, ' '),
      tsVectors.configData
    );

    for (const item of tsVectors.credentials) {
      expect(fromBase64(item.iv).length).toBe(12);
      expect(fromBase64(item.ciphertext).length).toBeGreaterThan(16);

      const decMaster = await decryptCredentialPayload(
        keyFromMaster,
        item.ciphertext,
        item.iv
      );
      const decRecovery = await decryptCredentialPayload(
        keyFromRecovery,
        item.ciphertext,
        item.iv
      );
      expect(decMaster).toEqual(item.expectedPayload);
      expect(decRecovery).toEqual(item.expectedPayload);
    }
  });

  it('rejects invalid master password, invalid recovery key, and tampered AES-GCM artifacts', async () => {
    await expect(
      unlockVaultWithMasterPassword('Wrong-Master-Passphrase#99', tsVectors.configData)
    ).rejects.toThrow(InvalidMasterPasswordError);

    await expect(
      unlockVaultWithRecoveryKey(
        'VX-AAAA-BBBB-CCCC-DDDD-EEEE-FFFF-2222-3333-4444-5555-6666-7777-8888',
        tsVectors.configData
      )
    ).rejects.toThrow(InvalidRecoveryKeyError);

    // Tampered wrappedVaultKey must fail master-password unlock
    const tamperedConfig: VaultMasterConfig = {
      ...tsVectors.configData,
      wrappedVaultKey: flipByteInBase64(tsVectors.configData.wrappedVaultKey, 0),
    };
    await expect(
      unlockVaultWithMasterPassword(tsVectors.masterPassword, tamperedConfig)
    ).rejects.toThrow(InvalidMasterPasswordError);

    const vaultKey = await unlockVaultWithMasterPassword(
      tsVectors.masterPassword,
      tsVectors.configData
    );
    const target = tsVectors.credentials[0];

    // 1. Tampered ciphertext byte (byte 0)
    await expect(
      decryptCredentialPayload(
        vaultKey,
        flipByteInBase64(target.ciphertext, 0),
        target.iv
      )
    ).rejects.toThrow();

    // 2. Tampered 16-byte authentication tag (last byte)
    await expect(
      decryptCredentialPayload(
        vaultKey,
        flipByteInBase64(target.ciphertext, -1),
        target.iv
      )
    ).rejects.toThrow();

    // 3. Tampered 12-byte nonce/IV
    await expect(
      decryptCredentialPayload(
        vaultKey,
        target.ciphertext,
        flipByteInBase64(target.iv, 0)
      )
    ).rejects.toThrow();
  });

  it('produces unique 12-byte nonces across repeated encryptions of identical payloads', async () => {
    const vaultKey = await unlockVaultWithMasterPassword(
      tsVectors.masterPassword,
      tsVectors.configData
    );
    const payload = tsVectors.credentials[0].expectedPayload;
    const seenIvs = new Set<string>();

    for (let i = 0; i < 25; i++) {
      const enc = await encryptCredentialPayload(vaultKey, payload);
      expect(fromBase64(enc.iv).length).toBe(12);
      expect(seenIvs.has(enc.iv)).toBe(false);
      seenIvs.add(enc.iv);
    }
  });

  it('verifies Dart -> TypeScript decryption when dart_interop_vectors.json is generated locally', async () => {
    if (!fs.existsSync(DART_VECTOR_PATH)) {
      // dart_interop_vectors.json is produced by running:
      //   cd vaultx_flutter && flutter test test/crypto_interoperability_test.dart
      expect(fs.existsSync(TS_VECTOR_PATH)).toBe(true);
      return;
    }

    const dartVectors = JSON.parse(
      fs.readFileSync(DART_VECTOR_PATH, 'utf8')
    ) as InteropVectorFile;

    const keyFromMaster = await unlockVaultWithMasterPassword(
      dartVectors.masterPassword,
      dartVectors.configData
    );
    const keyFromRecovery = await unlockVaultWithRecoveryKey(
      dartVectors.recoveryKey,
      dartVectors.configData
    );

    for (const item of dartVectors.credentials) {
      expect(fromBase64(item.iv).length).toBe(12);
      const decMaster = await decryptCredentialPayload(
        keyFromMaster,
        item.ciphertext,
        item.iv
      );
      const decRecovery = await decryptCredentialPayload(
        keyFromRecovery,
        item.ciphertext,
        item.iv
      );
      expect(decMaster).toEqual(item.expectedPayload);
      expect(decRecovery).toEqual(item.expectedPayload);
    }
  });
});
