import React, { useState } from 'react';
import { EmailAuthProvider, reauthenticateWithCredential, updatePassword } from 'firebase/auth';
import {
  AlertTriangle,
  Check,
  Copy,
  Download,
  Globe,
  KeyRound,
  Loader2,
  ShieldCheck,
} from 'lucide-react';
import { auth } from '../lib/firebase';
import { useVault } from '../context/VaultContext';
import {
  EXTENSION_MANIFEST_V3_BLUEPRINT,
  findMatchingCredentialsForOrigin,
} from '../lib/browserExtensionProtocol';

interface SettingsAndRecoveryViewProps {
  initialTab?: 'general' | 'recovery' | 'passwords' | 'extension';
}

export const SettingsAndRecoveryView: React.FC<SettingsAndRecoveryViewProps> = ({
  initialTab = 'general',
}) => {
  const {
    authUser,
    userProfile,
    masterConfig,
    securitySettings,
    encryptedRecords,
    decryptedCredentials,
    saveSecuritySettings,
    saveDisplayName,
    changeMasterPassword,
    regenerateRecoveryKey,
    showToast,
  } = useVault();

  const [activeTab, setActiveTab] = useState<'general' | 'recovery' | 'passwords' | 'extension'>(
    initialTab
  );

  // General settings
  const [displayName, setDisplayName] = useState(userProfile?.displayName || '');
  const [autoLockMinutes, setAutoLockMinutes] = useState(securitySettings.autoLockMinutes);
  const [clipboardSeconds, setClipboardSeconds] = useState(securitySettings.clipboardClearSeconds);
  const [requireReauth, setRequireReauth] = useState(securitySettings.requireReauthForReveal);
  const [savingGeneral, setSavingGeneral] = useState(false);

  // Recovery key management
  const [recoveryAuthPassword, setRecoveryAuthPassword] = useState('');
  const [newRecoveryKey, setNewRecoveryKey] = useState<string | null>(null);
  const [copiedNewRecovery, setCopiedNewRecovery] = useState(false);
  const [rotatingRecovery, setRotatingRecovery] = useState(false);

  // Change Master Password
  const [masterAuthMode, setMasterAuthMode] = useState<'master' | 'recovery'>('master');
  const [currentMasterPw, setCurrentMasterPw] = useState('');
  const [currentRecoveryInput, setCurrentRecoveryInput] = useState('');
  const [newMasterPw, setNewMasterPw] = useState('');
  const [confirmNewMasterPw, setConfirmNewMasterPw] = useState('');
  const [changingMaster, setChangingMaster] = useState(false);

  // Change Firebase Account Password
  const [currentAccountPw, setCurrentAccountPw] = useState('');
  const [newAccountPw, setNewAccountPw] = useState('');
  const [changingAccountPw, setChangingAccountPw] = useState(false);

  // Extension domain matcher simulator
  const [testOriginUrl, setTestOriginUrl] = useState('https://github.com/login');

  const isPasswordProvider = authUser?.providerData.some((p) => p.providerId === 'password');

  const handleSaveGeneral = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavingGeneral(true);
    try {
      if (displayName.trim() && displayName.trim() !== userProfile?.displayName) {
        await saveDisplayName(displayName.trim());
      }
      await saveSecuritySettings({
        autoLockMinutes,
        clipboardClearSeconds: clipboardSeconds,
        requireReauthForReveal: requireReauth,
      });
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Unable to save settings.', 'error');
    } finally {
      setSavingGeneral(false);
    }
  };

  const handleExportEncryptedBackup = () => {
    const bundle = {
      format: 'vaultx-encrypted-backup-v1',
      exportedAt: new Date().toISOString(),
      userEmail: authUser?.email,
      kdfConfig: masterConfig
        ? {
            kdfAlgorithm: masterConfig.kdfAlgorithm,
            kdfMemoryKiB: masterConfig.kdfMemoryKiB,
            kdfIterations: masterConfig.kdfIterations,
            kdfParallelism: masterConfig.kdfParallelism,
            masterSalt: masterConfig.masterSalt,
            wrappedVaultKey: masterConfig.wrappedVaultKey,
            wrappedVaultKeyIv: masterConfig.wrappedVaultKeyIv,
            keyVersion: masterConfig.keyVersion,
          }
        : null,
      encryptedRecords: encryptedRecords.map((r) => ({
        id: r.id,
        ciphertext: r.ciphertext,
        iv: r.iv,
        keyVersion: r.keyVersion,
        createdAt: r.createdAt.toISOString(),
        updatedAt: r.updatedAt.toISOString(),
      })),
    };

    const blob = new Blob([JSON.stringify(bundle, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `vaultx-encrypted-backup-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('Encrypted vault backup downloaded (zero plaintext secrets included).', 'success');
  };

  const handleRotateRecoveryKey = async (e: React.FormEvent) => {
    e.preventDefault();
    setRotatingRecovery(true);
    setNewRecoveryKey(null);
    try {
      const key = await regenerateRecoveryKey(recoveryAuthPassword);
      setNewRecoveryKey(key);
      setRecoveryAuthPassword('');
      setCopiedNewRecovery(false);
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Unable to rotate recovery key.', 'error');
    } finally {
      setRotatingRecovery(false);
    }
  };

  const handleChangeMasterPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newMasterPw.length < 10) {
      showToast('New Master Password must be at least 10 characters.', 'error');
      return;
    }
    if (newMasterPw !== confirmNewMasterPw) {
      showToast('New Master Passwords do not match.', 'error');
      return;
    }

    setChangingMaster(true);
    try {
      await changeMasterPassword(
        masterAuthMode === 'master'
          ? { type: 'master', currentMasterPassword: currentMasterPw }
          : { type: 'recovery', recoveryKey: currentRecoveryInput },
        newMasterPw
      );
      setCurrentMasterPw('');
      setCurrentRecoveryInput('');
      setNewMasterPw('');
      setConfirmNewMasterPw('');
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Failed updating Master Password.', 'error');
    } finally {
      setChangingMaster(false);
    }
  };

  const handleChangeAccountPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    const user = auth.currentUser;
    if (!user || !user.email) return;
    if (newAccountPw.length < 8) {
      showToast('New account password must be at least 8 characters.', 'error');
      return;
    }
    setChangingAccountPw(true);
    try {
      const credential = EmailAuthProvider.credential(user.email, currentAccountPw);
      await reauthenticateWithCredential(user, credential);
      await updatePassword(user, newAccountPw);
      setCurrentAccountPw('');
      setNewAccountPw('');
      showToast('Firebase Account Login Password updated.', 'success');
    } catch (err) {
      showToast(
        err instanceof Error ? err.message : 'Re-authentication failed. Check current password.',
        'error'
      );
    } finally {
      setChangingAccountPw(false);
    }
  };

  const matchedExtensionCreds = findMatchingCredentialsForOrigin(
    decryptedCredentials,
    testOriginUrl
  );

  return (
    <div className="max-w-4xl space-y-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-white tracking-tight">
          Settings &amp; Key Management
        </h1>
        <p className="text-sm text-slate-400 mt-1">
          Configure session locking, manage your 256-bit Recovery Key, rotate passwords, and inspect browser extension integration contracts.
        </p>
      </div>

      {/* Sub-navigation tabs */}
      <div className="flex flex-wrap gap-1 p-1 rounded-xl bg-[#0D1220] border border-slate-800 w-fit">
        {[
          { id: 'general', label: 'Account & Security' },
          { id: 'recovery', label: 'Recovery Key' },
          { id: 'passwords', label: 'Change Passwords' },
          { id: 'extension', label: 'Extension Architecture' },
        ].map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setActiveTab(t.id as typeof activeTab)}
            className={`px-4 py-2 rounded-lg text-xs font-medium whitespace-nowrap transition-colors cursor-pointer ${
              activeTab === t.id
                ? 'bg-indigo-600 text-white'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {activeTab === 'general' && (
        <div className="space-y-6">
          <form
            onSubmit={handleSaveGeneral}
            className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-5"
          >
            <h2 className="font-display text-base font-semibold text-white">
              Profile &amp; Session Security
            </h2>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Display Name
                </label>
                <input
                  type="text"
                  maxLength={100}
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Verified Email
                </label>
                <input
                  type="text"
                  disabled
                  value={authUser?.email || ''}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14]/60 border border-slate-800 text-sm text-slate-400"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Auto-Lock After Inactivity
                </label>
                <select
                  value={autoLockMinutes}
                  onChange={(e) => setAutoLockMinutes(Number(e.target.value))}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                >
                  <option value={1}>1 minute</option>
                  <option value={5}>5 minutes</option>
                  <option value={15}>15 minutes</option>
                  <option value={30}>30 minutes</option>
                  <option value={60}>60 minutes</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Clipboard Auto-Clear Timer
                </label>
                <select
                  value={clipboardSeconds}
                  onChange={(e) => setClipboardSeconds(Number(e.target.value))}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                >
                  <option value={10}>10 seconds</option>
                  <option value={30}>30 seconds</option>
                  <option value={60}>60 seconds</option>
                  <option value={120}>120 seconds</option>
                </select>
              </div>
            </div>

            <label className="flex items-start gap-3 p-4 rounded-xl bg-[#080B14] border border-slate-800 cursor-pointer">
              <input
                type="checkbox"
                checked={requireReauth}
                onChange={(e) => setRequireReauth(e.target.checked)}
                className="mt-0.5 rounded border-slate-600 bg-[#0D1220] text-indigo-600 focus:ring-indigo-500"
              />
              <div>
                <div className="text-sm font-medium text-white">
                  Require Master Password before revealing hidden passwords
                </div>
                <div className="text-xs text-slate-400 mt-0.5">
                  Prompts for Master Password re-verification once per unlocked session before unmasking secret values.
                </div>
              </div>
            </label>

            <div className="flex justify-end">
              <button
                type="submit"
                disabled={savingGeneral}
                className="px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white flex items-center gap-2 cursor-pointer"
              >
                {savingGeneral && <Loader2 className="w-4 h-4 animate-spin" />}
                <span>Save Preferences</span>
              </button>
            </div>
          </form>

          {/* Encrypted Export & MFA Info */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 flex flex-col justify-between">
              <div>
                <h3 className="font-display text-base font-semibold text-white">
                  Encrypted Vault Backup
                </h3>
                <p className="text-xs text-slate-400 mt-1.5 leading-relaxed">
                  Download an offline JSON snapshot of your AES-256-GCM ciphertexts, nonces, and Argon2id wrapping metadata. Plaintext passwords are never exported.
                </p>
              </div>
              <button
                type="button"
                onClick={handleExportEncryptedBackup}
                className="mt-5 inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs font-semibold text-slate-200 cursor-pointer"
              >
                <Download className="w-4 h-4" />
                <span>Export Encrypted JSON</span>
              </button>
            </div>

            <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90">
              <div className="flex items-center gap-2 mb-2">
                <ShieldCheck className="w-4 h-4 text-indigo-400" />
                <h3 className="font-display text-base font-semibold text-white">
                  Multi-Factor Authentication (MFA)
                </h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                VaultX enforces two independent authentication barriers by default: verified Firebase Auth identity plus your local Argon2id Master Password. Firebase TOTP/SMS MFA requires upgrading the Firebase project to Identity Platform in Google Cloud Console.
              </p>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'recovery' && (
        <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-6">
          <div className="flex items-start gap-3">
            <KeyRound className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
            <div>
              <h2 className="font-display text-base font-semibold text-white">
                256-Bit Recovery Key Management
              </h2>
              <p className="text-xs text-slate-400 mt-1 leading-relaxed">
                Your Recovery Key independently wraps your Vault Data Encryption Key using Argon2id. Rotating it immediately invalidates any previously issued Recovery Key.
              </p>
            </div>
          </div>

          <div className="p-4 rounded-xl bg-[#080B14] border border-slate-800 flex items-center justify-between text-xs">
            <span className="text-slate-400">Active Recovery Key Identifier</span>
            <span className="font-mono text-slate-200">
              {masterConfig?.recoveryKeyHint || 'Configured'}
            </span>
          </div>

          <form onSubmit={handleRotateRecoveryKey} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Confirm Current Master Password to Rotate Recovery Key
              </label>
              <input
                type="password"
                required
                value={recoveryAuthPassword}
                onChange={(e) => setRecoveryAuthPassword(e.target.value)}
                placeholder="Enter current Master Password"
                className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
              />
            </div>

            <button
              type="submit"
              disabled={rotatingRecovery}
              className="px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white flex items-center gap-2 cursor-pointer"
            >
              {rotatingRecovery && <Loader2 className="w-4 h-4 animate-spin" />}
              <span>Generate New Recovery Key</span>
            </button>
          </form>

          {newRecoveryKey && (
            <div className="p-5 rounded-xl bg-amber-950/25 border border-amber-500/40 space-y-3">
              <div className="flex items-center gap-2 text-xs font-semibold text-amber-200">
                <AlertTriangle className="w-4 h-4 text-amber-400" />
                <span>Store this new Recovery Key offline immediately. It will not be shown again.</span>
              </div>
              <div className="p-3.5 rounded-lg bg-[#080B14] border border-slate-800 font-mono text-xs text-indigo-200 break-all select-all">
                {newRecoveryKey}
              </div>
              <button
                type="button"
                onClick={async () => {
                  await navigator.clipboard.writeText(newRecoveryKey);
                  setCopiedNewRecovery(true);
                }}
                className="inline-flex items-center gap-2 px-3.5 py-2 rounded-lg bg-[#101626] border border-slate-700 text-xs font-medium text-white cursor-pointer"
              >
                {copiedNewRecovery ? (
                  <Check className="w-3.5 h-3.5 text-emerald-400" />
                ) : (
                  <Copy className="w-3.5 h-3.5" />
                )}
                <span>{copiedNewRecovery ? 'Copied' : 'Copy New Recovery Key'}</span>
              </button>
            </div>
          )}
        </div>
      )}

      {activeTab === 'passwords' && (
        <div className="space-y-6">
          {/* Change Master Password */}
          <form
            onSubmit={handleChangeMasterPassword}
            className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-4"
          >
            <h2 className="font-display text-base font-semibold text-white">
              Change Vault Master Password
            </h2>
            <p className="text-xs text-slate-400 leading-relaxed">
              Re-wraps your 256-bit Vault Data Encryption Key using a fresh Argon2id salt without altering your Firebase login password.
            </p>

            <div className="flex gap-2 p-1 rounded-lg bg-[#080B14] border border-slate-800 w-fit">
              <button
                type="button"
                onClick={() => setMasterAuthMode('master')}
                className={`px-3 py-1.5 rounded-md text-xs font-medium cursor-pointer ${
                  masterAuthMode === 'master'
                    ? 'bg-indigo-600 text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Verify Current Master Password
              </button>
              <button
                type="button"
                onClick={() => setMasterAuthMode('recovery')}
                className={`px-3 py-1.5 rounded-md text-xs font-medium cursor-pointer ${
                  masterAuthMode === 'recovery'
                    ? 'bg-indigo-600 text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Verify via Recovery Key
              </button>
            </div>

            {masterAuthMode === 'master' ? (
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Current Master Password
                </label>
                <input
                  type="password"
                  required
                  value={currentMasterPw}
                  onChange={(e) => setCurrentMasterPw(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                />
              </div>
            ) : (
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  256-Bit Recovery Key
                </label>
                <input
                  type="text"
                  required
                  value={currentRecoveryInput}
                  onChange={(e) => setCurrentRecoveryInput(e.target.value)}
                  placeholder="VX-XXXX-XXXX-..."
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 font-mono text-xs text-white focus:outline-none focus:border-indigo-500"
                />
              </div>
            )}

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  New Master Password (min 10 chars)
                </label>
                <input
                  type="password"
                  required
                  minLength={10}
                  value={newMasterPw}
                  onChange={(e) => setNewMasterPw(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Confirm New Master Password
                </label>
                <input
                  type="password"
                  required
                  minLength={10}
                  value={confirmNewMasterPw}
                  onChange={(e) => setConfirmNewMasterPw(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={changingMaster}
              className="px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white flex items-center gap-2 cursor-pointer"
            >
              {changingMaster && <Loader2 className="w-4 h-4 animate-spin" />}
              <span>Update Master Password</span>
            </button>
          </form>

          {/* Change Firebase Account Login Password */}
          <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-4">
            <h2 className="font-display text-base font-semibold text-white">
              Account Login Password
            </h2>
            {!isPasswordProvider ? (
              <p className="text-xs text-slate-400">
                You signed in using an external identity provider (Google). Manage your login password directly through your Google Account settings.
              </p>
            ) : (
              <form onSubmit={handleChangeAccountPassword} className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-slate-300 mb-1.5">
                      Current Account Login Password
                    </label>
                    <input
                      type="password"
                      required
                      value={currentAccountPw}
                      onChange={(e) => setCurrentAccountPw(e.target.value)}
                      className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-slate-300 mb-1.5">
                      New Account Login Password (min 8 chars)
                    </label>
                    <input
                      type="password"
                      required
                      minLength={8}
                      value={newAccountPw}
                      onChange={(e) => setNewAccountPw(e.target.value)}
                      className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
                    />
                  </div>
                </div>
                <button
                  type="submit"
                  disabled={changingAccountPw}
                  className="px-5 py-2.5 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-sm font-semibold text-white flex items-center gap-2 cursor-pointer"
                >
                  {changingAccountPw && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>Update Account Login Password</span>
                </button>
              </form>
            )}
          </div>
        </div>
      )}

      {activeTab === 'extension' && (
        <div className="space-y-6">
          <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-4">
            <div className="flex items-center gap-2.5">
              <Globe className="w-5 h-5 text-indigo-400" />
              <h2 className="font-display text-base font-semibold text-white">
                Future Chrome &amp; Edge Extension Readiness
              </h2>
            </div>
            <p className="text-xs text-slate-300 leading-relaxed">
              Because standard web applications are isolated by the browser Same-Origin Policy, VaultX never claims to read passwords typed into unrelated tabs. Instead, the domain-matching engine and Manifest V3 messaging contracts are built cleanly to power a future companion extension.
            </p>
            <ul className="space-y-2 text-xs text-slate-400 list-disc pl-5">
              {EXTENSION_MANIFEST_V3_BLUEPRINT.architectureNotes.map((note, idx) => (
                <li key={idx}>{note}</li>
              ))}
            </ul>
          </div>

          <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-4">
            <h3 className="font-display text-sm font-semibold text-white">
              Origin &amp; Host Match Tester (Live Vault Query)
            </h3>
            <p className="text-xs text-slate-400">
              Test which credentials from your unlocked vault would be offered by the companion extension on a given website URL.
            </p>
            <input
              type="text"
              value={testOriginUrl}
              onChange={(e) => setTestOriginUrl(e.target.value)}
              placeholder="https://github.com/login"
              className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 font-mono text-xs text-white focus:outline-none focus:border-indigo-500"
            />
            <div className="p-4 rounded-xl bg-[#080B14] border border-slate-800">
              {matchedExtensionCreds.length === 0 ? (
                <p className="text-xs text-slate-400">
                  No saved credentials match the host of <code className="text-indigo-300">{testOriginUrl || '(empty)'}</code>.
                </p>
              ) : (
                <div className="space-y-2">
                  <div className="text-xs font-medium text-emerald-300 tabular-nums">
                    {matchedExtensionCreds.length} authorized match(es) found:
                  </div>
                  {matchedExtensionCreds.map((c) => (
                    <div
                      key={c.id}
                      className="flex items-center justify-between text-xs text-slate-200 py-1.5 border-t border-slate-800/80"
                    >
                      <span className="font-medium">{c.title}</span>
                      <span className="text-slate-400">{c.username}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
