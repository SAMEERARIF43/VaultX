import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import {
  onAuthStateChanged,
  signOut,
  type User,
} from 'firebase/auth';
import { auth } from '../lib/firebase';
import {
  decryptCredentialPayload,
  initializeVaultKeys,
  rotateMasterPasswordWrapper,
  rotateRecoveryKeyWrapper,
  unlockVaultWithMasterPassword,
  unlockVaultWithRecoveryKey,
} from '../lib/crypto';
import {
  createEncryptedCredential,
  deleteEncryptedCredential,
  fetchUserVaultState,
  initializeVaultInFirestore,
  subscribeToEncryptedCredentials,
  updateEncryptedCredential,
  updateMasterWrapperInFirestore,
  updateProfileDisplayName,
  updateRecoveryWrapperInFirestore,
  updateSecuritySettingsInFirestore,
} from '../lib/vaultService';
import type {
  CredentialPayload,
  DecryptedCredential,
  EncryptedCredentialRecord,
  UserProfile,
  UserSecuritySettings,
  VaultMasterConfig,
} from '../types/vault';

export interface ToastMessage {
  id: string;
  type: 'success' | 'error' | 'info';
  text: string;
}

interface VaultContextValue {
  authUser: User | null;
  authReady: boolean;
  vaultDataLoading: boolean;
  userProfile: UserProfile | null;
  masterConfig: VaultMasterConfig | null;
  securitySettings: UserSecuritySettings;
  isVaultInitialized: boolean;
  isVaultUnlocked: boolean;
  pendingRecoveryCeremonyKey: string | null;
  acknowledgeRecoveryCeremony: () => void;
  encryptedRecords: EncryptedCredentialRecord[];
  decryptedCredentials: DecryptedCredential[];
  clipboardSecondsLeft: number;
  lastCopiedLabel: string | null;
  toasts: ToastMessage[];
  showToast: (text: string, type?: ToastMessage['type']) => void;
  dismissToast: (id: string) => void;
  refreshUserState: () => Promise<void>;
  setupMasterPassword: (masterPassword: string, displayName?: string) => Promise<string>;
  unlockVault: (masterPassword: string) => Promise<void>;
  recoverVaultWithKey: (recoveryKey: string) => Promise<void>;
  lockVault: (reason?: string) => void;
  verifyMasterPassword: (masterPassword: string) => Promise<boolean>;
  addCredential: (payload: CredentialPayload) => Promise<void>;
  editCredential: (credentialId: string, payload: CredentialPayload) => Promise<void>;
  removeCredential: (credentialId: string) => Promise<void>;
  copySensitiveValue: (value: string, label: string, isSecret?: boolean) => Promise<void>;
  saveSecuritySettings: (updates: {
    autoLockMinutes: number;
    clipboardClearSeconds: number;
    requireReauthForReveal: boolean;
  }) => Promise<void>;
  saveDisplayName: (displayName: string) => Promise<void>;
  changeMasterPassword: (
    authMethod: { type: 'master'; currentMasterPassword: string } | { type: 'recovery'; recoveryKey: string },
    newMasterPassword: string
  ) => Promise<void>;
  regenerateRecoveryKey: (currentMasterPassword: string) => Promise<string>;
  logout: () => Promise<void>;
}

const DEFAULT_SETTINGS: UserSecuritySettings = {
  userId: '',
  autoLockMinutes: 15,
  clipboardClearSeconds: 30,
  requireReauthForReveal: false,
};

const VaultContext = createContext<VaultContextValue | null>(null);

export const VaultProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [authUser, setAuthUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [vaultDataLoading, setVaultDataLoading] = useState(false);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [masterConfig, setMasterConfig] = useState<VaultMasterConfig | null>(null);
  const [securitySettings, setSecuritySettings] = useState<UserSecuritySettings>(DEFAULT_SETTINGS);

  // In-memory only: never persisted to localStorage/sessionStorage
  const [vaultKey, setVaultKey] = useState<CryptoKey | null>(null);
  const [pendingRecoveryCeremonyKey, setPendingRecoveryCeremonyKey] = useState<string | null>(null);
  const [encryptedRecords, setEncryptedRecords] = useState<EncryptedCredentialRecord[]>([]);
  const [decryptedCredentials, setDecryptedCredentials] = useState<DecryptedCredential[]>([]);

  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const [clipboardSecondsLeft, setClipboardSecondsLeft] = useState(0);
  const [lastCopiedLabel, setLastCopiedLabel] = useState<string | null>(null);

  const lastCopiedSecretRef = useRef<string | null>(null);
  const inactivityTimerRef = useRef<number | null>(null);

  const showToast = useCallback((text: string, type: ToastMessage['type'] = 'info') => {
    const id = `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    setToasts((prev) => [...prev, { id, type, text }]);
    window.setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4500);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const lockVault = useCallback(
    (reason?: string) => {
      setVaultKey(null);
      setPendingRecoveryCeremonyKey(null);
      setDecryptedCredentials([]);
      lastCopiedSecretRef.current = null;
      if (reason) {
        showToast(reason, 'info');
      }
    },
    [showToast]
  );

  const acknowledgeRecoveryCeremony = useCallback(() => {
    setPendingRecoveryCeremonyKey(null);
  }, []);

  const loadUserMetadata = useCallback(async (user: User) => {
    if (!user.emailVerified) {
      setUserProfile(null);
      setMasterConfig(null);
      setSecuritySettings({ ...DEFAULT_SETTINGS, userId: user.uid });
      return;
    }

    setVaultDataLoading(true);
    try {
      const { profile, masterConfig: mc, settings } = await fetchUserVaultState(user.uid);
      setUserProfile(profile);
      setMasterConfig(mc);
      setSecuritySettings(settings || { ...DEFAULT_SETTINGS, userId: user.uid });
    } finally {
      setVaultDataLoading(false);
    }
  }, []);

  const refreshUserState = useCallback(async () => {
    const current = auth.currentUser;
    if (!current) return;
    await current.reload();
    const updatedUser = auth.currentUser;
    setAuthUser(updatedUser ? { ...updatedUser } as User : null);
    if (updatedUser) {
      await loadUserMetadata(updatedUser);
    }
  }, [loadUserMetadata]);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setAuthUser(user);
      setAuthReady(true);
      if (!user) {
        setVaultKey(null);
        setDecryptedCredentials([]);
        setEncryptedRecords([]);
        setUserProfile(null);
        setMasterConfig(null);
        setSecuritySettings(DEFAULT_SETTINGS);
        return;
      }
      if (user.emailVerified) {
        try {
          await loadUserMetadata(user);
        } catch (err) {
          console.error('Failed loading vault metadata:', err);
        }
      } else {
        setUserProfile(null);
        setMasterConfig(null);
      }
    });
    return () => unsubscribe();
  }, [loadUserMetadata]);

  // Subscribe to encrypted credentials when verified & initialized
  useEffect(() => {
    if (!authUser || !authUser.emailVerified || !masterConfig) {
      setEncryptedRecords([]);
      return;
    }

    const unsubscribe = subscribeToEncryptedCredentials(
      authUser.uid,
      (records) => {
        setEncryptedRecords(records);
      },
      () => {
        showToast('Unable to synchronize encrypted vault records.', 'error');
      }
    );

    return () => unsubscribe();
  }, [authUser, masterConfig, showToast]);

  // Decrypt records locally whenever vaultKey or encryptedRecords change
  useEffect(() => {
    let cancelled = false;
    if (!vaultKey) {
      setDecryptedCredentials([]);
      return;
    }

    async function decryptAll() {
      const key = vaultKey;
      if (!key) return;
      const results: DecryptedCredential[] = await Promise.all(
        encryptedRecords.map(async (rec) => {
          try {
            const payload = await decryptCredentialPayload(key, rec.ciphertext, rec.iv);
            return {
              id: rec.id,
              keyVersion: rec.keyVersion,
              createdAt: rec.createdAt,
              updatedAt: rec.updatedAt,
              ...payload,
            };
          } catch {
            return {
              id: rec.id,
              keyVersion: rec.keyVersion,
              createdAt: rec.createdAt,
              updatedAt: rec.updatedAt,
              title: 'Unreadable Record',
              username: '',
              password: '',
              url: '',
              category: 'Personal',
              notes: 'Decryption failed with current vault key.',
              decryptionError: true,
            };
          }
        })
      );
      if (!cancelled) {
        setDecryptedCredentials(results);
      }
    }

    void decryptAll();
    return () => {
      cancelled = true;
    };
  }, [vaultKey, encryptedRecords]);

  // Automatic inactivity vault locking
  useEffect(() => {
    if (!vaultKey) {
      if (inactivityTimerRef.current) {
        window.clearTimeout(inactivityTimerRef.current);
      }
      return;
    }

    const timeoutMs = (securitySettings.autoLockMinutes || 15) * 60 * 1000;

    const resetTimer = () => {
      if (inactivityTimerRef.current) {
        window.clearTimeout(inactivityTimerRef.current);
      }
      inactivityTimerRef.current = window.setTimeout(() => {
        lockVault('Vault automatically locked after inactivity.');
      }, timeoutMs);
    };

    const events = ['mousedown', 'keydown', 'scroll', 'touchstart'] as const;
    events.forEach((ev) => window.addEventListener(ev, resetTimer, { passive: true }));
    resetTimer();

    return () => {
      events.forEach((ev) => window.removeEventListener(ev, resetTimer));
      if (inactivityTimerRef.current) {
        window.clearTimeout(inactivityTimerRef.current);
      }
    };
  }, [vaultKey, securitySettings.autoLockMinutes, lockVault]);

  // Clipboard countdown & automatic wipe
  useEffect(() => {
    if (clipboardSecondsLeft <= 0) return;

    const timer = window.setInterval(() => {
      setClipboardSecondsLeft((prev) => {
        if (prev <= 1) {
          if (lastCopiedSecretRef.current && navigator.clipboard?.writeText) {
            navigator.clipboard.writeText('').catch(() => {});
          }
          lastCopiedSecretRef.current = null;
          setLastCopiedLabel(null);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => window.clearInterval(timer);
  }, [clipboardSecondsLeft]);

  const setupMasterPassword = useCallback(
    async (masterPassword: string, displayName?: string): Promise<string> => {
      const user = auth.currentUser;
      if (!user || !user.email) {
        throw new Error('You must be signed in with a verified account.');
      }
      const { vaultKey: newKey, recoveryKey, configData } = await initializeVaultKeys(masterPassword);
      await initializeVaultInFirestore({
        uid: user.uid,
        email: user.email,
        displayName: displayName || user.displayName || user.email.split('@')[0],
        profileExists: Boolean(userProfile),
        configData,
      });
      await loadUserMetadata(user);
      setVaultKey(newKey);
      setPendingRecoveryCeremonyKey(recoveryKey);
      showToast('Vault initialized with Argon2id + AES-256-GCM.', 'success');
      return recoveryKey;
    },
    [userProfile, loadUserMetadata, showToast]
  );

  const unlockVault = useCallback(
    async (masterPassword: string) => {
      if (!masterConfig) {
        throw new Error('Vault configuration has not been initialized.');
      }
      const key = await unlockVaultWithMasterPassword(masterPassword, masterConfig);
      setVaultKey(key);
    },
    [masterConfig]
  );

  const recoverVaultWithKey = useCallback(
    async (recoveryKey: string) => {
      if (!masterConfig) {
        throw new Error('Vault configuration has not been initialized.');
      }
      const key = await unlockVaultWithRecoveryKey(recoveryKey, masterConfig);
      setVaultKey(key);
      showToast('Vault unlocked via Recovery Key. Consider rotating your Master Password.', 'info');
    },
    [masterConfig, showToast]
  );

  const verifyMasterPassword = useCallback(
    async (masterPassword: string): Promise<boolean> => {
      if (!masterConfig) return false;
      try {
        await unlockVaultWithMasterPassword(masterPassword, masterConfig);
        return true;
      } catch {
        return false;
      }
    },
    [masterConfig]
  );

  const addCredential = useCallback(
    async (payload: CredentialPayload) => {
      if (!authUser || !vaultKey || !masterConfig) {
        throw new Error('Unlock your vault before saving credentials.');
      }
      await createEncryptedCredential(authUser.uid, vaultKey, masterConfig.keyVersion, payload);
      showToast(`Saved "${payload.title}" to encrypted vault.`, 'success');
    },
    [authUser, vaultKey, masterConfig, showToast]
  );

  const editCredential = useCallback(
    async (credentialId: string, payload: CredentialPayload) => {
      if (!authUser || !vaultKey || !masterConfig) {
        throw new Error('Unlock your vault before editing credentials.');
      }
      await updateEncryptedCredential(
        authUser.uid,
        credentialId,
        vaultKey,
        masterConfig.keyVersion,
        payload
      );
      showToast(`Updated "${payload.title}".`, 'success');
    },
    [authUser, vaultKey, masterConfig, showToast]
  );

  const removeCredential = useCallback(
    async (credentialId: string) => {
      if (!authUser) throw new Error('Authentication required.');
      await deleteEncryptedCredential(authUser.uid, credentialId);
      showToast('Credential permanently deleted.', 'info');
    },
    [authUser, showToast]
  );

  const copySensitiveValue = useCallback(
    async (value: string, label: string, isSecret = false) => {
      await navigator.clipboard.writeText(value);
      if (isSecret) {
        lastCopiedSecretRef.current = value;
        setLastCopiedLabel(label);
        setClipboardSecondsLeft(securitySettings.clipboardClearSeconds || 30);
        showToast(`${label} copied. Clipboard auto-clears in ${securitySettings.clipboardClearSeconds || 30}s.`, 'success');
      } else {
        showToast(`${label} copied to clipboard.`, 'success');
      }
    },
    [securitySettings.clipboardClearSeconds, showToast]
  );

  const saveSecuritySettings = useCallback(
    async (updates: {
      autoLockMinutes: number;
      clipboardClearSeconds: number;
      requireReauthForReveal: boolean;
    }) => {
      if (!authUser) throw new Error('Authentication required.');
      await updateSecuritySettingsInFirestore(authUser.uid, updates);
      setSecuritySettings((prev) => ({ ...prev, ...updates }));
      showToast('Security preferences saved.', 'success');
    },
    [authUser, showToast]
  );

  const saveDisplayName = useCallback(
    async (displayName: string) => {
      if (!authUser) throw new Error('Authentication required.');
      await updateProfileDisplayName(authUser.uid, displayName);
      setUserProfile((prev) => (prev ? { ...prev, displayName: displayName.trim() } : prev));
      showToast('Profile updated.', 'success');
    },
    [authUser, showToast]
  );

  const changeMasterPassword = useCallback(
    async (
      authMethod:
        | { type: 'master'; currentMasterPassword: string }
        | { type: 'recovery'; recoveryKey: string },
      newMasterPassword: string
    ) => {
      if (!authUser || !masterConfig) {
        throw new Error('Vault configuration unavailable.');
      }
      const rotated = await rotateMasterPasswordWrapper(authMethod, newMasterPassword, masterConfig);
      await updateMasterWrapperInFirestore(authUser.uid, {
        kdfAlgorithm: rotated.kdfAlgorithm,
        kdfMemoryKiB: rotated.kdfMemoryKiB,
        kdfIterations: rotated.kdfIterations,
        kdfParallelism: rotated.kdfParallelism,
        masterSalt: rotated.masterSalt,
        wrappedVaultKey: rotated.wrappedVaultKey,
        wrappedVaultKeyIv: rotated.wrappedVaultKeyIv,
        keyVersion: rotated.keyVersion,
      });
      setVaultKey(rotated.vaultKey);
      setMasterConfig((prev) =>
        prev
          ? {
              ...prev,
              kdfAlgorithm: rotated.kdfAlgorithm,
              kdfMemoryKiB: rotated.kdfMemoryKiB,
              kdfIterations: rotated.kdfIterations,
              kdfParallelism: rotated.kdfParallelism,
              masterSalt: rotated.masterSalt,
              wrappedVaultKey: rotated.wrappedVaultKey,
              wrappedVaultKeyIv: rotated.wrappedVaultKeyIv,
              keyVersion: rotated.keyVersion,
            }
          : prev
      );
      showToast('Master Password updated successfully.', 'success');
    },
    [authUser, masterConfig, showToast]
  );

  const regenerateRecoveryKey = useCallback(
    async (currentMasterPassword: string): Promise<string> => {
      if (!authUser || !masterConfig) {
        throw new Error('Vault configuration unavailable.');
      }
      const rotated = await rotateRecoveryKeyWrapper(currentMasterPassword, masterConfig);
      await updateRecoveryWrapperInFirestore(authUser.uid, {
        recoverySalt: rotated.recoverySalt,
        recoveryWrappedVaultKey: rotated.recoveryWrappedVaultKey,
        recoveryWrappedVaultKeyIv: rotated.recoveryWrappedVaultKeyIv,
        recoveryKeyHint: rotated.recoveryKeyHint,
      });
      setMasterConfig((prev) =>
        prev
          ? {
              ...prev,
              recoverySalt: rotated.recoverySalt,
              recoveryWrappedVaultKey: rotated.recoveryWrappedVaultKey,
              recoveryWrappedVaultKeyIv: rotated.recoveryWrappedVaultKeyIv,
              recoveryKeyHint: rotated.recoveryKeyHint,
            }
          : prev
      );
      showToast('New Recovery Key generated and synced.', 'success');
      return rotated.recoveryKey;
    },
    [authUser, masterConfig, showToast]
  );

  const logout = useCallback(async () => {
    lockVault();
    await signOut(auth);
  }, [lockVault]);

  const value = useMemo<VaultContextValue>(
    () => ({
      authUser,
      authReady,
      vaultDataLoading,
      userProfile,
      masterConfig,
      securitySettings,
      isVaultInitialized: Boolean(masterConfig && userProfile?.vaultInitialized),
      isVaultUnlocked: Boolean(vaultKey),
      pendingRecoveryCeremonyKey,
      acknowledgeRecoveryCeremony,
      encryptedRecords,
      decryptedCredentials,
      clipboardSecondsLeft,
      lastCopiedLabel,
      toasts,
      showToast,
      dismissToast,
      refreshUserState,
      setupMasterPassword,
      unlockVault,
      recoverVaultWithKey,
      lockVault,
      verifyMasterPassword,
      addCredential,
      editCredential,
      removeCredential,
      copySensitiveValue,
      saveSecuritySettings,
      saveDisplayName,
      changeMasterPassword,
      regenerateRecoveryKey,
      logout,
    }),
    [
      authUser,
      authReady,
      vaultDataLoading,
      userProfile,
      masterConfig,
      securitySettings,
      vaultKey,
      pendingRecoveryCeremonyKey,
      acknowledgeRecoveryCeremony,
      encryptedRecords,
      decryptedCredentials,
      clipboardSecondsLeft,
      lastCopiedLabel,
      toasts,
      showToast,
      dismissToast,
      refreshUserState,
      setupMasterPassword,
      unlockVault,
      recoverVaultWithKey,
      lockVault,
      verifyMasterPassword,
      addCredential,
      editCredential,
      removeCredential,
      copySensitiveValue,
      saveSecuritySettings,
      saveDisplayName,
      changeMasterPassword,
      regenerateRecoveryKey,
      logout,
    ]
  );

  return <VaultContext.Provider value={value}>{children}</VaultContext.Provider>;
};

export function useVault(): VaultContextValue {
  const ctx = useContext(VaultContext);
  if (!ctx) throw new Error('useVault must be used within VaultProvider');
  return ctx;
}
