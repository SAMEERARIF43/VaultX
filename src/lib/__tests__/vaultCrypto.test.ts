import { describe, expect, it } from 'vitest';
import {
  decryptCredentialPayload,
  encryptCredentialPayload,
  initializeVaultKeys,
  InvalidMasterPasswordError,
  InvalidRecoveryKeyError,
  rotateMasterPasswordWrapper,
  rotateRecoveryKeyWrapper,
  unlockVaultWithMasterPassword,
  unlockVaultWithRecoveryKey,
} from '../crypto';
import { evaluatePasswordStrength, generateSecurePassword } from '../passwordGenerator';
import { runSecurityAudit } from '../securityAudit';
import { extractNormalizedHost, findMatchingCredentialsForOrigin } from '../browserExtensionProtocol';
import type { CredentialPayload, DecryptedCredential, VaultMasterConfig } from '../../types/vault';

const TEST_KDF = {
  algorithm: 'Argon2id' as const,
  memoryKiB: 16384, // 16 MiB for fast unit test execution while keeping real Argon2id
  iterations: 2,
  parallelism: 1,
};

describe('VaultX Client-Side Cryptographic Engine', () => {
  it('initializes vault with Argon2id + AES-256-GCM and unlocks with correct master password', async () => {
    const masterPw = 'Correct-Horse-Battery-Staple-2026!';
    const { vaultKey, recoveryKey, configData } = await initializeVaultKeys(masterPw, TEST_KDF);

    expect(recoveryKey.startsWith('VX-')).toBe(true);
    expect(configData.kdfAlgorithm).toBe('Argon2id');
    expect(configData.wrappedVaultKey).toBeTruthy();

    const fullConfig: VaultMasterConfig = { userId: 'user_1', ...configData };
    const unlockedKey = await unlockVaultWithMasterPassword(masterPw, fullConfig);

    const payload: CredentialPayload = {
      title: 'GitHub',
      username: 'alex@vaultx.test',
      password: 'UltraSecurePassword#99',
      url: 'https://github.com',
      category: 'Developer',
      notes: 'Hardware 2FA enabled',
    };

    const encrypted = await encryptCredentialPayload(vaultKey, payload);
    const decrypted = await decryptCredentialPayload(unlockedKey, encrypted.ciphertext, encrypted.iv);
    expect(decrypted).toEqual(payload);
  });

  it('rejects invalid master password with InvalidMasterPasswordError', async () => {
    const { configData } = await initializeVaultKeys('MyRealMasterPassphrase#1', TEST_KDF);
    const fullConfig: VaultMasterConfig = { userId: 'user_1', ...configData };

    await expect(
      unlockVaultWithMasterPassword('WrongMasterPassphrase#2', fullConfig)
    ).rejects.toThrow(InvalidMasterPasswordError);
  });

  it('generates a unique 96-bit IV/nonce for every encryption operation', async () => {
    const { vaultKey } = await initializeVaultKeys('NonceTestMasterPassphrase#9', TEST_KDF);
    const payload: CredentialPayload = {
      title: 'AWS',
      username: 'ops@company.com',
      password: 'SamePasswordValue!123',
      url: 'https://aws.amazon.com',
      category: 'Work',
      notes: '',
    };

    const enc1 = await encryptCredentialPayload(vaultKey, payload);
    const enc2 = await encryptCredentialPayload(vaultKey, payload);

    expect(enc1.iv).not.toBe(enc2.iv);
    expect(enc1.ciphertext).not.toBe(enc2.ciphertext);
  });

  it('supports recovery key unlock, master password rotation, and recovery key rotation', async () => {
    const oldMaster = 'InitialMasterPassphrase#10';
    const { recoveryKey, configData } = await initializeVaultKeys(oldMaster, TEST_KDF);
    let config: VaultMasterConfig = { userId: 'user_1', ...configData };

    // Unlock via recovery key
    const recoveredKey = await unlockVaultWithRecoveryKey(recoveryKey, config);
    const sample: CredentialPayload = {
      title: 'Stripe',
      username: 'billing@acme.io',
      password: 'StripeSecretPassword#77',
      url: 'https://dashboard.stripe.com',
      category: 'Finance',
      notes: '',
    };
    const enc = await encryptCredentialPayload(recoveredKey, sample);

    // Rotate master password using recovery key
    const newMaster = 'RotatedMasterPassphrase#20';
    const masterRotated = await rotateMasterPasswordWrapper(
      { type: 'recovery', recoveryKey },
      newMaster,
      config
    );
    config = {
      ...config,
      kdfAlgorithm: masterRotated.kdfAlgorithm,
      kdfMemoryKiB: masterRotated.kdfMemoryKiB,
      kdfIterations: masterRotated.kdfIterations,
      kdfParallelism: masterRotated.kdfParallelism,
      masterSalt: masterRotated.masterSalt,
      wrappedVaultKey: masterRotated.wrappedVaultKey,
      wrappedVaultKeyIv: masterRotated.wrappedVaultKeyIv,
      keyVersion: masterRotated.keyVersion,
    };

    // Old master fails, new master decrypts original record
    await expect(unlockVaultWithMasterPassword(oldMaster, config)).rejects.toThrow(
      InvalidMasterPasswordError
    );
    const unlockedNew = await unlockVaultWithMasterPassword(newMaster, config);
    const dec = await decryptCredentialPayload(unlockedNew, enc.ciphertext, enc.iv);
    expect(dec).toEqual(sample);

    // Rotate recovery key and confirm old recovery key is invalidated
    const rotRecovery = await rotateRecoveryKeyWrapper(newMaster, config);
    config = {
      ...config,
      recoverySalt: rotRecovery.recoverySalt,
      recoveryWrappedVaultKey: rotRecovery.recoveryWrappedVaultKey,
      recoveryWrappedVaultKeyIv: rotRecovery.recoveryWrappedVaultKeyIv,
      recoveryKeyHint: rotRecovery.recoveryKeyHint,
    };

    await expect(unlockVaultWithRecoveryKey(recoveryKey, config)).rejects.toThrow(
      InvalidRecoveryKeyError
    );
    const unlockedByNewRec = await unlockVaultWithRecoveryKey(rotRecovery.recoveryKey, config);
    expect(await decryptCredentialPayload(unlockedByNewRec, enc.ciphertext, enc.iv)).toEqual(sample);
  });
});

describe('VaultX Password Generator & Local Security Audit', () => {
  it('generates passwords meeting requested length and character pools', () => {
    const pw = generateSecurePassword({
      length: 24,
      uppercase: true,
      lowercase: true,
      numbers: true,
      symbols: true,
      excludeAmbiguous: true,
    });

    expect(pw.length).toBe(24);
    expect(/[A-Z]/.test(pw)).toBe(true);
    expect(/[a-z]/.test(pw)).toBe(true);
    expect(/[0-9]/.test(pw)).toBe(true);
    expect(/[^A-Za-z0-9]/.test(pw)).toBe(true);
    expect(/[0O1lI]/.test(pw)).toBe(false);

    const strength = evaluatePasswordStrength(pw);
    expect(strength.score).toBeGreaterThanOrEqual(3);
  });

  it('detects weak, reused, compromised, and missing-URL credentials locally', () => {
    const now = new Date();
    const creds: DecryptedCredential[] = [
      {
        id: '1',
        keyVersion: 1,
        title: 'Legacy Forum',
        username: 'user1',
        password: 'password123',
        url: '',
        category: 'Social',
        notes: '',
        createdAt: now,
        updatedAt: now,
      },
      {
        id: '2',
        keyVersion: 1,
        title: 'Bank A',
        username: 'user1@mail.com',
        password: 'ReusedStrongPassword!9876',
        url: 'https://bank-a.example',
        category: 'Finance',
        notes: '',
        createdAt: now,
        updatedAt: now,
      },
      {
        id: '3',
        keyVersion: 1,
        title: 'Bank B',
        username: 'user1@mail.com',
        password: 'ReusedStrongPassword!9876',
        url: 'https://bank-b.example',
        category: 'Finance',
        notes: '',
        createdAt: now,
        updatedAt: now,
      },
    ];

    const report = runSecurityAudit(creds);
    expect(report.compromisedPasswords.length).toBe(1);
    expect(report.weakPasswords.length).toBe(1);
    expect(report.reusedGroups.length).toBe(1);
    expect(report.reusedCount).toBe(2);
    expect(report.missingInfoAccounts.length).toBe(1);
  });

  it('matches browser origins accurately for future companion extension integration', () => {
    expect(extractNormalizedHost('https://www.github.com/login')).toBe('github.com');
    const now = new Date();
    const creds: DecryptedCredential[] = [
      {
        id: 'gh',
        keyVersion: 1,
        title: 'GitHub',
        username: 'dev',
        password: 'StrongPassword#1234',
        url: 'https://github.com',
        category: 'Developer',
        notes: '',
        createdAt: now,
        updatedAt: now,
      },
      {
        id: 'gl',
        keyVersion: 1,
        title: 'GitLab',
        username: 'dev',
        password: 'StrongPassword#5678',
        url: 'https://gitlab.com',
        category: 'Developer',
        notes: '',
        createdAt: now,
        updatedAt: now,
      },
    ];

    const matches = findMatchingCredentialsForOrigin(creds, 'https://gist.github.com/auth');
    expect(matches.map((m) => m.id)).toEqual(['gh']);
  });
});
