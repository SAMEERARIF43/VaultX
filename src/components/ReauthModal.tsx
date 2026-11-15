import React, { useState } from 'react';
import { AlertTriangle, Loader2, ShieldCheck, X } from 'lucide-react';
import { useVault } from '../context/VaultContext';

interface ReauthModalProps {
  isOpen: boolean;
  actionDescription: string;
  onVerified: () => void;
  onCancel: () => void;
}

export const ReauthModal: React.FC<ReauthModalProps> = ({
  isOpen,
  actionDescription,
  onVerified,
  onCancel,
}) => {
  const { verifyMasterPassword } = useVault();
  const [masterPassword, setMasterPassword] = useState('');
  const [verifying, setVerifying] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setVerifying(true);
    try {
      const ok = await verifyMasterPassword(masterPassword);
      if (!ok) {
        setErrorMsg('Incorrect Master Password.');
        return;
      }
      setMasterPassword('');
      onVerified();
    } finally {
      setVerifying(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4"
      role="dialog"
      aria-modal="true"
    >
      <div className="w-full max-w-sm bg-[#0D1220] border border-slate-800 rounded-2xl p-6 shadow-2xl">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-indigo-400" />
            <h2 className="font-display text-base font-bold text-white">
              Verify Master Password
            </h2>
          </div>
          <button
            type="button"
            onClick={onCancel}
            aria-label="Close verification dialog"
            className="text-slate-400 hover:text-white cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <p className="text-xs text-slate-300 leading-relaxed mb-4">
          Re-authentication is enabled for sensitive actions. Confirm your Master Password to {actionDescription}.
        </p>

        {errorMsg && (
          <div className="mb-3 p-2.5 rounded-lg bg-rose-950/40 border border-rose-500/40 text-xs text-rose-200 flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            type="password"
            required
            autoFocus
            value={masterPassword}
            onChange={(e) => setMasterPassword(e.target.value)}
            placeholder="Enter Master Password"
            className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
          />

          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onCancel}
              className="px-3.5 py-2 rounded-lg bg-[#101626] border border-slate-700 text-xs font-medium text-slate-300 hover:text-white cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={verifying}
              className="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-xs font-semibold text-white flex items-center gap-1.5 cursor-pointer"
            >
              {verifying && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
              <span>Verify</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
