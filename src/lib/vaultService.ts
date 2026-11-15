import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
  type Unsubscribe,
} from 'firebase/firestore';
import { db, handleFirestoreError, OperationType } from './firebase';
import { encryptCredentialPayload, generateRandomBytes } from './crypto';
import type {
  CredentialPayload,
  EncryptedCredentialRecord,
  UserProfile,
  UserSecuritySettings,
  VaultMasterConfig,
} from '../types/vault';

function toDateValue(val: unknown): Date {
  if (val instanceof Timestamp) return val.toDate();
  if (val instanceof Date) return val;
  return new Date();
}

function generateCredentialId(): string {
  const bytes = generateRandomBytes(16);
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `cred_${hex}`;
}

export async function fetchUserVaultState(uid: string): Promise<{
  profile: UserProfile | null;
  masterConfig: VaultMasterConfig | null;
  settings: UserSecuritySettings | null;
}> {
  const userPath = `users/${uid}`;
  const masterPath = `users/${uid}/vaultConfig/master`;
  const settingsPath = `users/${uid}/settings/preferences`;

  let profile: UserProfile | null = null;
  let masterConfig: VaultMasterConfig | null = null;
  let settings: UserSecuritySettings | null = null;

  try {
    const userSnap = await getDoc(doc(db, 'users', uid));
    if (userSnap.exists()) {
      const data = userSnap.data();
      profile = {
        uid: String(data.uid),
        email: String(data.email),
        displayName: String(data.displayName),
        vaultInitialized: Boolean(data.vaultInitialized),
        createdAt: toDateValue(data.createdAt),
        updatedAt: toDateValue(data.updatedAt),
      };
    }
  } catch (error) {
    handleFirestoreError(error, OperationType.GET, userPath);
  }

  try {
    const masterSnap = await getDoc(doc(db, 'users', uid, 'vaultConfig', 'master'));
    if (masterSnap.exists()) {
      const d = masterSnap.data();
      masterConfig = {
        userId: String(d.userId),
        kdfAlgorithm: 'Argon2id',
        kdfMemoryKiB: Number(d.kdfMemoryKiB),
        kdfIterations: Number(d.kdfIterations),
        kdfParallelism: Number(d.kdfParallelism),
        masterSalt: String(d.masterSalt),
        wrappedVaultKey: String(d.wrappedVaultKey),
        wrappedVaultKeyIv: String(d.wrappedVaultKeyIv),
        recoverySalt: String(d.recoverySalt),
        recoveryWrappedVaultKey: String(d.recoveryWrappedVaultKey),
        recoveryWrappedVaultKeyIv: String(d.recoveryWrappedVaultKeyIv),
        recoveryKeyHint: String(d.recoveryKeyHint),
        keyVersion: Number(d.keyVersion),
        createdAt: toDateValue(d.createdAt),
        updatedAt: toDateValue(d.updatedAt),
      };
    }
  } catch (error) {
    handleFirestoreError(error, OperationType.GET, masterPath);
  }

  try {
    const settingsSnap = await getDoc(doc(db, 'users', uid, 'settings', 'preferences'));
    if (settingsSnap.exists()) {
      const s = settingsSnap.data();
      settings = {
        userId: String(s.userId),
        autoLockMinutes: Number(s.autoLockMinutes),
        clipboardClearSeconds: Number(s.clipboardClearSeconds),
        requireReauthForReveal: Boolean(s.requireReauthForReveal),
        updatedAt: toDateValue(s.updatedAt),
      };
    }
  } catch (error) {
    handleFirestoreError(error, OperationType.GET, settingsPath);
  }

  return { profile, masterConfig, settings };
}

export async function initializeVaultInFirestore(params: {
  uid: string;
  email: string;
  displayName: string;
  profileExists: boolean;
  configData: Omit<VaultMasterConfig, 'userId' | 'createdAt' | 'updatedAt'>;
}): Promise<void> {
  const { uid, email, displayName, profileExists, configData } = params;
  const cleanName = (displayName || email.split('@')[0] || 'Vault User').trim().slice(0, 100);
  const cleanEmail = email.trim().toLowerCase().slice(0, 254);

  const batch = writeBatch(db);
  const userRef = doc(db, 'users', uid);
  const masterRef = doc(db, 'users', uid, 'vaultConfig', 'master');
  const settingsRef = doc(db, 'users', uid, 'settings', 'preferences');

  if (profileExists) {
    batch.update(userRef, {
      displayName: cleanName,
      vaultInitialized: true,
      updatedAt: serverTimestamp(),
    });
  } else {
    batch.set(userRef, {
      uid,
      email: cleanEmail,
      displayName: cleanName,
      vaultInitialized: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  batch.set(masterRef, {
    userId: uid,
    ...configData,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  batch.set(settingsRef, {
    userId: uid,
    autoLockMinutes: 15,
    clipboardClearSeconds: 30,
    requireReauthForReveal: false,
    updatedAt: serverTimestamp(),
  });

  try {
    await batch.commit();
  } catch (error) {
    handleFirestoreError(error, OperationType.WRITE, `users/${uid}/vaultConfig/master`);
  }
}

export function subscribeToEncryptedCredentials(
  uid: string,
  onRecords: (records: EncryptedCredentialRecord[]) => void,
  onError?: (err: Error) => void
): Unsubscribe {
  const path = `users/${uid}/credentials`;
  const q = query(collection(db, 'users', uid, 'credentials'), where('userId', '==', uid));

  return onSnapshot(
    q,
    (snapshot) => {
      const records: EncryptedCredentialRecord[] = snapshot.docs.map((docSnap) => {
        const d = docSnap.data();
        return {
          id: String(d.id),
          userId: String(d.userId),
          ciphertext: String(d.ciphertext),
          iv: String(d.iv),
          keyVersion: Number(d.keyVersion),
          createdAt: toDateValue(d.createdAt),
          updatedAt: toDateValue(d.updatedAt),
        };
      });
      records.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
      onRecords(records);
    },
    (error) => {
      if (onError) {
        onError(error);
      }
      handleFirestoreError(error, OperationType.LIST, path);
    }
  );
}

export async function createEncryptedCredential(
  uid: string,
  vaultKey: CryptoKey,
  keyVersion: number,
  payload: CredentialPayload
): Promise<string> {
  const credentialId = generateCredentialId();
  const path = `users/${uid}/credentials/${credentialId}`;
  const { ciphertext, iv } = await encryptCredentialPayload(vaultKey, payload);

  if (ciphertext.length > 32768) {
    throw new Error('Encrypted credential exceeds maximum allowed record size (32 KB).');
  }

  try {
    await setDoc(doc(db, 'users', uid, 'credentials', credentialId), {
      id: credentialId,
      userId: uid,
      ciphertext,
      iv,
      keyVersion,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    return credentialId;
  } catch (error) {
    handleFirestoreError(error, OperationType.CREATE, path);
  }
}

export async function updateEncryptedCredential(
  uid: string,
  credentialId: string,
  vaultKey: CryptoKey,
  keyVersion: number,
  payload: CredentialPayload
): Promise<void> {
  const path = `users/${uid}/credentials/${credentialId}`;
  const { ciphertext, iv } = await encryptCredentialPayload(vaultKey, payload);

  if (ciphertext.length > 32768) {
    throw new Error('Encrypted credential exceeds maximum allowed record size (32 KB).');
  }

  try {
    await updateDoc(doc(db, 'users', uid, 'credentials', credentialId), {
      ciphertext,
      iv,
      keyVersion,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, path);
  }
}

export async function deleteEncryptedCredential(
  uid: string,
  credentialId: string
): Promise<void> {
  const path = `users/${uid}/credentials/${credentialId}`;
  try {
    await deleteDoc(doc(db, 'users', uid, 'credentials', credentialId));
  } catch (error) {
    handleFirestoreError(error, OperationType.DELETE, path);
  }
}

export async function updateSecuritySettingsInFirestore(
  uid: string,
  updates: {
    autoLockMinutes: number;
    clipboardClearSeconds: number;
    requireReauthForReveal: boolean;
  }
): Promise<void> {
  const path = `users/${uid}/settings/preferences`;
  try {
    await updateDoc(doc(db, 'users', uid, 'settings', 'preferences'), {
      autoLockMinutes: Math.max(1, Math.min(120, Math.round(updates.autoLockMinutes))),
      clipboardClearSeconds: Math.max(10, Math.min(300, Math.round(updates.clipboardClearSeconds))),
      requireReauthForReveal: Boolean(updates.requireReauthForReveal),
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, path);
  }
}

export async function updateProfileDisplayName(uid: string, displayName: string): Promise<void> {
  const path = `users/${uid}`;
  const cleanName = displayName.trim().slice(0, 100);
  if (!cleanName) throw new Error('Display name cannot be empty.');
  try {
    await updateDoc(doc(db, 'users', uid), {
      displayName: cleanName,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, path);
  }
}

export async function updateMasterWrapperInFirestore(
  uid: string,
  data: {
    kdfAlgorithm: 'Argon2id';
    kdfMemoryKiB: number;
    kdfIterations: number;
    kdfParallelism: number;
    masterSalt: string;
    wrappedVaultKey: string;
    wrappedVaultKeyIv: string;
    keyVersion: number;
  }
): Promise<void> {
  const path = `users/${uid}/vaultConfig/master`;
  try {
    await updateDoc(doc(db, 'users', uid, 'vaultConfig', 'master'), {
      ...data,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, path);
  }
}

export async function updateRecoveryWrapperInFirestore(
  uid: string,
  data: {
    recoverySalt: string;
    recoveryWrappedVaultKey: string;
    recoveryWrappedVaultKeyIv: string;
    recoveryKeyHint: string;
  }
): Promise<void> {
  const path = `users/${uid}/vaultConfig/master`;
  try {
    await updateDoc(doc(db, 'users', uid, 'vaultConfig', 'master'), {
      ...data,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, path);
  }
}
