import React, { useEffect, useState } from 'react';
import {
  AlertTriangle,
  Check,
  Copy,
  Download,
  Eye,
  EyeOff,
  KeyRound,
  Loader2,
  ShieldAlert,
  ShieldCheck,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';
import { evaluatePasswordStrength } from '../lib/passwordGenerator';

export const RecoveryKeyCeremonyPage: React.FC = () => {
  const {
    authUser,
    pendingRecoveryCeremonyKey,
    acknowledgeRecoveryCeremony,
    showToast,
  } = useVault();
  const [copiedRecovery, setCopiedRecovery] = useState(false);
  const [savedRecoveryConfirmed, setSavedRecoveryConfirmed] = useState(false);

  if (!pendingRecoveryCeremonyKey) return null;

  const handleCopyRecovery = async () => {
    await navigator.clipboard.writeText(pendingRecoveryCeremonyKey);
    setCopiedRecovery(true);
    showToast('Recovery Key copied. Store it offline in a safe place.', 'success');
  };

  const handleDownloadRecovery = () => {
    const content = [
      'VaultX Zero-Knowledge Recovery Key',
      `Account: ${authUser?.email || ''}`,
      `Generated: ${new Date().toISOString()}`,
      '',
      'RECOVERY KEY (Keep offline and confidential):',
      pendingRecoveryCeremonyKey,
      '',
      'WARNING: Anyone with this key can decrypt your vault. VaultX servers never store this key.',
    ].join('\n');

    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `vaultx-recovery-key-${new Date().toISOString().slice(0, 10)}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex items-center justify-center px-4 py-12">
      <div className="max-w-lg w-full bg-[#0D1220] border border-slate-800/90 rounded-2xl p-8">
        <div className="w-12 h-12 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center mb-5">
          <KeyRound className="w-6 h-6 text-amber-400" />
        </div>

        <h1 className="font-display text-2xl font-bold text-white tracking-tight">
          Save your 256-bit Recovery Key
        </h1>
        <p className="text-sm text-slate-300 mt-2 leading-relaxed">
          This is the only time your Recovery Key will be displayed in plaintext. If you ever forget your Master Password, this key is the sole way to recover your encrypted vault.
        </p>

        <div className="mt-6 p-4 rounded-xl bg-[#080B14] border border-slate-700/80 font-mono text-sm text-indigo-200 break-all leading-relaxed select-all">
          {pendingRecoveryCeremonyKey}
        </div>

        <div className="mt-4 flex flex-wrap gap-3">
          <button
            type="button"
            onClick={handleCopyRecovery}
            className="flex-1 min-w-[140px] py-2.5 px-4 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-sm font-medium text-slate-200 transition-colors flex items-center justify-center gap-2 cursor-pointer"
          >
            {copiedRecovery ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
            <span>{copiedRecovery ? 'Copied' : 'Copy Key'}</span>
          </button>
          <button
            type="button"
            onClick={handleDownloadRecovery}
            className="flex-1 min-w-[140px] py-2.5 px-4 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-sm font-medium text-slate-200 transition-colors flex items-center justify-center gap-2 cursor-pointer"
          >
            <Download className="w-4 h-4" />
            <span>Download .txt</span>
          </button>
        </div>

        <label className="mt-6 flex items-start gap-3 text-xs text-slate-300 cursor-pointer">
          <input
            type="checkbox"
            checked={savedRecoveryConfirmed}
            onChange={(e) => setSavedRecoveryConfirmed(e.target.checked)}
            className="mt-0.5 rounded border-slate-600 bg-[#080B14] text-indigo-600 focus:ring-indigo-500"
          />
          <span>
            I have saved my 256-bit Recovery Key in a secure offline location and understand it will not be shown again.
          </span>
        </label>

        <button
          type="button"
          disabled={!savedRecoveryConfirmed}
          onClick={acknowledgeRecoveryCeremony}
          className="mt-6 w-full py-2.5 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-sm font-semibold text-white transition-colors cursor-pointer"
        >
          Enter My Encrypted Vault
        </button>
      </div>
    </div>
  );
};

export const MasterPasswordSetupPage: React.FC = () => {
  const { authUser, setupMasterPassword, logout } = useVault();
  const [displayName, setDisplayName] = useState(
    authUser?.displayName || authUser?.email?.split('@')[0] || ''
  );
  const [masterPassword, setMasterPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [ackZeroKnowledge, setAckZeroKnowledge] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    if (!displayName && authUser) {
      setDisplayName(authUser.displayName || authUser.email?.split('@')[0] || '');
    }
  }, [authUser, displayName]);

  const strength = evaluatePasswordStrength(masterPassword);

  const handleCreateVault = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (masterPassword.length < 10) {
      setErrorMsg('Master Password must be at least 10 characters for strong Argon2id protection.');
      return;
    }
    if (masterPassword !== confirmPassword) {
      setErrorMsg('Master Passwords do not match.');
      return;
    }
    if (!ackZeroKnowledge) {
      setErrorMsg('Please acknowledge the zero-knowledge master password policy.');
      return;
    }

    setSubmitting(true);
    try {
      await setupMasterPassword(masterPassword, displayName);
      setMasterPassword('');
      setConfirmPassword('');
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Failed to initialize encrypted vault.');
    } finally {
      setSubmitting(false);
    }
  };

  const barColors = [
    'bg-rose-500',
    'bg-rose-500',
    'bg-amber-500',
    'bg-sky-500',
    'bg-emerald-500',
  ];

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex items-center justify-center px-4 py-12">
      <div className="max-w-lg w-full bg-[#0D1220] border border-slate-800/90 rounded-2xl p-8">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2.5">
            <ShieldCheck className="w-5 h-5 text-indigo-400" />
            <span className="font-display text-lg font-bold text-white">VaultX</span>
          </div>
          <button
            type="button"
            onClick={logout}
            className="text-xs text-slate-400 hover:text-white cursor-pointer"
          >
            Sign Out
          </button>
        </div>

        <h1 className="font-display text-2xl font-bold text-white tracking-tight">
          Create your Master Password
        </h1>
        <p className="text-sm text-slate-300 mt-2 leading-relaxed">
          Your Master Password is kept strictly on your device and derives your AES-256-GCM encryption key via Argon2id. It must be distinct from your Firebase login password.
        </p>

        <div className="mt-5 p-4 rounded-xl bg-amber-950/30 border border-amber-500/30 text-xs text-amber-200 flex items-start gap-3 leading-relaxed">
          <ShieldAlert className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
          <div>
            <strong className="text-amber-100 block mb-0.5">
              Zero-Knowledge Warning
            </strong>
            VaultX never transmits or stores your Master Password. If you forget it and lose your Recovery Key, your encrypted vault cannot be decrypted by anyone, including VaultX support.
          </div>
        </div>

        {errorMsg && (
          <div className="mt-4 p-3.5 rounded-lg bg-rose-950/40 border border-rose-500/40 text-xs text-rose-200 flex items-start gap-2">
            <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
            <span>{errorMsg}</span>
          </div>
        )}

        <form onSubmit={handleCreateVault} className="mt-6 space-y-4">
          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Account Display Name
            </label>
            <input
              type="text"
              required
              maxLength={100}
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Master Password (min 10 characters)
            </label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                required
                minLength={10}
                value={masterPassword}
                onChange={(e) => setMasterPassword(e.target.value)}
                placeholder="Choose a strong passphrase"
                className="w-full px-3.5 py-2.5 pr-10 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <button
                type="button"
                onClick={() => setShowPassword((p) => !p)}
                aria-label={showPassword ? 'Hide master password' : 'Show master password'}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 cursor-pointer"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>

            {masterPassword && (
              <div className="mt-2.5 space-y-1.5">
                <div className="grid grid-cols-4 gap-1.5">
                  {[0, 1, 2, 3].map((idx) => (
                    <div
                      key={idx}
                      className={`h-1.5 rounded-full transition-colors ${
                        idx < strength.score ? barColors[strength.score] : 'bg-slate-800'
                      }`}
                    />
                  ))}
                </div>
                <div className="flex items-center justify-between text-xs text-slate-400 tabular-nums">
                  <span>Strength: {strength.label}</span>
                  <span>{strength.entropyBits} bits · {strength.crackTimeLabel}</span>
                </div>
              </div>
            )}
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Confirm Master Password
            </label>
            <input
              type={showPassword ? 'text' : 'password'}
              required
              minLength={10}
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Re-enter your Master Password"
              className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>

          <label className="flex items-start gap-3 text-xs text-slate-300 pt-1 cursor-pointer">
            <input
              type="checkbox"
              checked={ackZeroKnowledge}
              onChange={(e) => setAckZeroKnowledge(e.target.checked)}
              className="mt-0.5 rounded border-slate-600 bg-[#080B14] text-indigo-600 focus:ring-indigo-500"
            />
            <span>
              I understand that my Master Password is never stored on VaultX servers and I must safeguard my Recovery Key.
            </span>
          </label>

          <button
            type="submit"
            disabled={submitting}
            className="w-full py-2.5 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white transition-colors flex items-center justify-center gap-2 cursor-pointer"
          >
            {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
            <span>{submitting ? 'Deriving Argon2id Keys...' : 'Initialize Encrypted Vault'}</span>
          </button>
        </form>
      </div>
    </div>
  );
};
