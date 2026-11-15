export type VaultCategory =
  | 'Work'
  | 'Finance'
  | 'Social'
  | 'Developer'
  | 'Shopping'
  | 'Entertainment'
  | 'Personal'
  | string;

export const DEFAULT_CATEGORIES: string[] = [
  'Work',
  'Finance',
  'Social',
  'Developer',
  'Shopping',
  'Entertainment',
  'Personal',
];

export interface CredentialPayload {
  title: string;
  username: string;
  password: string;
  url: string;
  category: VaultCategory;
  notes: string;
}

export interface EncryptedCredentialRecord {
  id: string;
  userId: string;
  ciphertext: string;
  iv: string;
  keyVersion: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface DecryptedCredential extends CredentialPayload {
  id: string;
  keyVersion: number;
  createdAt: Date;
  updatedAt: Date;
  decryptionError?: boolean;
}

export interface KdfParams {
  algorithm: 'Argon2id';
  memoryKiB: number;
  iterations: number;
  parallelism: number;
}

export interface VaultMasterConfig {
  userId: string;
  kdfAlgorithm: 'Argon2id';
  kdfMemoryKiB: number;
  kdfIterations: number;
  kdfParallelism: number;
  masterSalt: string;
  wrappedVaultKey: string;
  wrappedVaultKeyIv: string;
  recoverySalt: string;
  recoveryWrappedVaultKey: string;
  recoveryWrappedVaultKeyIv: string;
  recoveryKeyHint: string;
  keyVersion: number;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  vaultInitialized: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface UserSecuritySettings {
  userId: string;
  autoLockMinutes: number;
  clipboardClearSeconds: number;
  requireReauthForReveal: boolean;
  updatedAt?: Date;
}

export interface PasswordGeneratorOptions {
  length: number;
  uppercase: boolean;
  lowercase: boolean;
  numbers: boolean;
  symbols: boolean;
  excludeAmbiguous: boolean;
}

export interface PasswordStrengthResult {
  score: 0 | 1 | 2 | 3 | 4;
  label: 'Critical' | 'Weak' | 'Fair' | 'Strong' | 'Very Strong';
  entropyBits: number;
  crackTimeLabel: string;
  feedback: string[];
}

export interface ReusedGroup {
  credentials: DecryptedCredential[];
  count: number;
}

export interface SecurityIssueItem {
  credential: DecryptedCredential;
  reason: string;
  severity: 'high' | 'medium' | 'low';
}

export interface SecurityAuditReport {
  totalChecked: number;
  weakPasswords: SecurityIssueItem[];
  reusedGroups: ReusedGroup[];
  reusedCount: number;
  compromisedPasswords: SecurityIssueItem[];
  missingInfoAccounts: SecurityIssueItem[];
  healthPercentage: number;
}

export type AppView =
  | 'dashboard'
  | 'vault'
  | 'generator'
  | 'security'
  | 'categories'
  | 'settings'
  | 'recovery';
