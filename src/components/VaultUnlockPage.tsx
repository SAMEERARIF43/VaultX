import React, { useState } from 'react';
import {
  AlertTriangle,
  Eye,
  EyeOff,
  KeyRound,
  Loader2,
  Lock,
  LogOut,
  ShieldCheck,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';

export const VaultUnlockPage: React.FC = () => {
  const {
    authUser,
    userProfile,
    masterConfig,
    unlockVault,
    recoverVaultWithKey,
    logout,
  } = useVault();

  const [mode, setMode] = useState<'master' | 'recovery'>('master');
  const [masterPassword, setMasterPassword] = useState('');
  const [recoveryKey, setRecoveryKey] = useState('');
  const [showSecret, setShowSecret] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleUnlock = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setSubmitting(true);
    try {
      if (mode === 'master') {
        await unlockVault(masterPassword);
        setMasterPassword('');
      } else {
        await recoverVaultWithKey(recoveryKey);
        setRecoveryKey('');
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Unable to unlock vault.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex items-center justify-center px-4 py-12">
      <div className="max-w-md w-full bg-[#0D1220] border border-slate-800/90 rounded-2xl p-8">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2.5">
            <ShieldCheck className="w-5 h-5 text-indigo-400" />
            <span className="font-display text-lg font-bold text-white">VaultX</span>
          </div>
          <button
            type="button"
            onClick={logout}
            className="inline-flex items-center gap-1.5 text-xs text-slate-400 hover:text-white transition-colors cursor-pointer"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span>Sign Out</span>
          </button>
        </div>

        <div className="flex items-center gap-3 mb-4">
          <div className="w-11 h-11 rounded-xl bg-indigo-500/15 border border-indigo-500/30 flex items-center justify-center shrink-0">
            {mode === 'master' ? (
              <Lock className="w-5 h-5 text-indigo-400" />
            ) : (
              <KeyRound className="w-5 h-5 text-amber-400" />
            )}
          </div>
          <div className="min-w-0">
            <h1 className="font-display text-xl font-bold text-white truncate">
              Vault is locked
            </h1>
            <p className="text-xs text-slate-400 truncate">
              {userProfile?.displayName || authUser?.email} · {authUser?.email}
            </p>
          </div>
        </div>

        {/* Segmented toggle between Master Password and Recovery Key */}
        <div className="grid grid-cols-2 gap-1 p-1 rounded-lg bg-[#080B14] border border-slate-800/80 mb-5">
          <button
            type="button"
            onClick={() => {
              setMode('master');
              setErrorMsg(null);
            }}
            className={`py-2 px-3 rounded-md text-xs font-medium transition-colors cursor-pointer ${
              mode === 'master'
                ? 'bg-indigo-600 text-white'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Master Password
          </button>
          <button
            type="button"
            onClick={() => {
              setMode('recovery');
              setErrorMsg(null);
            }}
            className={`py-2 px-3 rounded-md text-xs font-medium transition-colors cursor-pointer ${
              mode === 'recovery'
                ? 'bg-indigo-600 text-white'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Recovery Key
          </button>
        </div>

        {errorMsg && (
          <div className="mb-4 p-3.5 rounded-lg bg-rose-950/40 border border-rose-500/40 text-xs text-rose-200 flex items-start gap-2">
            <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
            <span>{errorMsg}</span>
          </div>
        )}

        <form onSubmit={handleUnlock} className="space-y-4">
          {mode === 'master' ? (
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Enter Master Password
              </label>
              <div className="relative">
                <input
                  type={showSecret ? 'text' : 'password'}
                  required
                  autoFocus
                  value={masterPassword}
                  onChange={(e) => setMasterPassword(e.target.value)}
                  placeholder="Your local decryption password"
                  className="w-full px-3.5 py-2.5 pr-10 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
                <button
                  type="button"
                  onClick={() => setShowSecret((p) => !p)}
                  aria-label={showSecret ? 'Hide password' : 'Show password'}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 cursor-pointer"
                >
                  {showSecret ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>
          ) : (
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-xs font-medium text-slate-300">
                  256-Bit Recovery Key
                </label>
                {masterConfig?.recoveryKeyHint && (
                  <span className="text-xs font-mono text-slate-400">
                    Ending {masterConfig.recoveryKeyHint}
                  </span>
                )}
              </div>
              <textarea
                required
                rows={3}
                value={recoveryKey}
                onChange={(e) => setRecoveryKey(e.target.value)}
                placeholder="VX-XXXX-XXXX-XXXX-..."
                className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 font-mono text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
            </div>
          )}

          <button
            type="submit"
            disabled={submitting}
            className="w-full py-2.5 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white transition-colors flex items-center justify-center gap-2 cursor-pointer"
          >
            {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
            <span>
              {submitting
                ? 'Deriving Key via Argon2id...'
                : mode === 'master'
                  ? 'Unlock Vault'
                  : 'Recover & Unlock Vault'}
            </span>
          </button>
        </form>

        {masterConfig && (
          <div className="mt-6 pt-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-500 tabular-nums">
            <span>
              {masterConfig.kdfAlgorithm} · {Math.round(masterConfig.kdfMemoryKiB / 1024)} MiB · {masterConfig.kdfIterations} iter
            </span>
            <span>Key v{masterConfig.keyVersion}</span>
          </div>
        )}
      </div>
    </div>
  );
};
