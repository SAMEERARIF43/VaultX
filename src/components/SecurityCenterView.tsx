import React, { useMemo } from 'react';
import {
  AlertOctagon,
  AlertTriangle,
  CheckCircle2,
  Info,
  KeyRound,
  ShieldCheck,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';
import { runSecurityAudit } from '../lib/securityAudit';
import type { DecryptedCredential } from '../types/vault';

interface SecurityCenterViewProps {
  onFixCredential: (cred: DecryptedCredential) => void;
}

export const SecurityCenterView: React.FC<SecurityCenterViewProps> = ({
  onFixCredential,
}) => {
  const { decryptedCredentials } = useVault();

  const report = useMemo(
    () => runSecurityAudit(decryptedCredentials),
    [decryptedCredentials]
  );

  return (
    <div className="space-y-8">
      <div>
        <h1 className="font-display text-2xl font-bold text-white tracking-tight">
          Security Center
        </h1>
        <p className="text-sm text-slate-400 mt-1">
          Zero-knowledge local audit. All checks execute exclusively in browser memory—plaintext passwords are never transmitted to any external service.
        </p>
      </div>

      {/* Overview Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-5 rounded-xl bg-[#0D1220] border border-slate-800/90">
          <div className="text-xs font-medium text-slate-400">Overall Vault Health</div>
          <div
            className={`font-display text-3xl font-bold mt-2 tabular-nums ${
              report.healthPercentage >= 85
                ? 'text-emerald-400'
                : report.healthPercentage >= 60
                  ? 'text-amber-400'
                  : 'text-rose-400'
            }`}
          >
            {report.healthPercentage}%
          </div>
          <div className="text-xs text-slate-500 mt-1.5 tabular-nums">
            {report.totalChecked} accounts analyzed
          </div>
        </div>

        <div className="p-5 rounded-xl bg-[#0D1220] border border-slate-800/90">
          <div className="text-xs font-medium text-slate-400">Potentially Compromised</div>
          <div
            className={`font-display text-3xl font-bold mt-2 tabular-nums ${
              report.compromisedPasswords.length > 0 ? 'text-rose-400' : 'text-emerald-400'
            }`}
          >
            {report.compromisedPasswords.length}
          </div>
          <div className="text-xs text-slate-500 mt-1.5">
            Offline breach &amp; username checks
          </div>
        </div>

        <div className="p-5 rounded-xl bg-[#0D1220] border border-slate-800/90">
          <div className="text-xs font-medium text-slate-400">Weak Passwords</div>
          <div
            className={`font-display text-3xl font-bold mt-2 tabular-nums ${
              report.weakPasswords.length > 0 ? 'text-amber-400' : 'text-emerald-400'
            }`}
          >
            {report.weakPasswords.length}
          </div>
          <div className="text-xs text-slate-500 mt-1.5">
            Below 68 bits entropy or 12 chars
          </div>
        </div>

        <div className="p-5 rounded-xl bg-[#0D1220] border border-slate-800/90">
          <div className="text-xs font-medium text-slate-400">Reused Passwords</div>
          <div
            className={`font-display text-3xl font-bold mt-2 tabular-nums ${
              report.reusedCount > 0 ? 'text-rose-400' : 'text-emerald-400'
            }`}
          >
            {report.reusedCount}
          </div>
          <div className="text-xs text-slate-500 mt-1.5 tabular-nums">
            {report.reusedGroups.length} duplicate password group(s)
          </div>
        </div>
      </div>

      {report.totalChecked === 0 ? (
        <div className="p-10 rounded-xl bg-[#0D1220] border border-slate-800/90 text-center">
          <ShieldCheck className="w-10 h-10 text-indigo-400 mx-auto mb-3" />
          <h2 className="font-display text-lg font-semibold text-white">
            No credentials to audit yet
          </h2>
          <p className="text-sm text-slate-400 mt-1">
            Add credentials to your vault to analyze strength, reuse, and hygiene automatically.
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {/* 1. Compromised Passwords */}
          <section className="rounded-xl bg-[#0D1220] border border-slate-800/90 p-6">
            <div className="flex items-center gap-2.5 mb-4">
              <AlertOctagon className="w-5 h-5 text-rose-400" />
              <h2 className="font-display text-base font-semibold text-white">
                Potentially Compromised Passwords ({report.compromisedPasswords.length})
              </h2>
            </div>

            {report.compromisedPasswords.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-emerald-300">
                <CheckCircle2 className="w-4 h-4" />
                <span>None of your saved passwords match common leaked patterns or usernames.</span>
              </div>
            ) : (
              <div className="divide-y divide-slate-800/80">
                {report.compromisedPasswords.map((item) => (
                  <div
                    key={`comp-${item.credential.id}`}
                    className="py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                  >
                    <div>
                      <div className="text-sm font-semibold text-white">
                        {item.credential.title}
                      </div>
                      <div className="text-xs text-rose-300 mt-0.5">
                        {item.credential.username} · {item.reason}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => onFixCredential(item.credential)}
                      className="px-3.5 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-500 text-xs font-semibold text-white shrink-0 cursor-pointer"
                    >
                      Replace Password
                    </button>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* 2. Reused Passwords */}
          <section className="rounded-xl bg-[#0D1220] border border-slate-800/90 p-6">
            <div className="flex items-center gap-2.5 mb-4">
              <KeyRound className="w-5 h-5 text-amber-400" />
              <h2 className="font-display text-base font-semibold text-white">
                Reused Passwords ({report.reusedGroups.length} groups)
              </h2>
            </div>

            {report.reusedGroups.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-emerald-300">
                <CheckCircle2 className="w-4 h-4" />
                <span>Every account uses a unique password.</span>
              </div>
            ) : (
              <div className="space-y-4">
                {report.reusedGroups.map((group, idx) => (
                  <div
                    key={`reuse-${idx}`}
                    className="p-4 rounded-xl bg-[#080B14] border border-slate-800"
                  >
                    <div className="text-xs font-medium text-amber-300 mb-3 tabular-nums">
                      Shared password across {group.count} accounts
                    </div>
                    <div className="divide-y divide-slate-800/80">
                      {group.credentials.map((cred) => (
                        <div
                          key={cred.id}
                          className="py-2.5 flex items-center justify-between gap-3"
                        >
                          <div className="min-w-0">
                            <div className="text-sm font-medium text-white truncate">
                              {cred.title}
                            </div>
                            <div className="text-xs text-slate-400 truncate">
                              {cred.username} · {cred.category}
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => onFixCredential(cred)}
                            className="px-3 py-1.5 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700 text-xs font-medium text-slate-200 shrink-0 cursor-pointer"
                          >
                            Make Unique
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* 3. Weak Passwords */}
          <section className="rounded-xl bg-[#0D1220] border border-slate-800/90 p-6">
            <div className="flex items-center gap-2.5 mb-4">
              <AlertTriangle className="w-5 h-5 text-amber-400" />
              <h2 className="font-display text-base font-semibold text-white">
                Weak Passwords ({report.weakPasswords.length})
              </h2>
            </div>

            {report.weakPasswords.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-emerald-300">
                <CheckCircle2 className="w-4 h-4" />
                <span>All saved passwords demonstrate strong entropy.</span>
              </div>
            ) : (
              <div className="divide-y divide-slate-800/80">
                {report.weakPasswords.map((item) => (
                  <div
                    key={`weak-${item.credential.id}`}
                    className="py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                  >
                    <div>
                      <div className="text-sm font-semibold text-white">
                        {item.credential.title}
                      </div>
                      <div className="text-xs text-amber-300 mt-0.5">
                        {item.credential.username} · {item.reason}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => onFixCredential(item.credential)}
                      className="px-3.5 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-xs font-semibold text-white shrink-0 cursor-pointer"
                    >
                      Strengthen
                    </button>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* 4. Missing Security Information / Stale Passwords */}
          <section className="rounded-xl bg-[#0D1220] border border-slate-800/90 p-6">
            <div className="flex items-center gap-2.5 mb-4">
              <Info className="w-5 h-5 text-sky-400" />
              <h2 className="font-display text-base font-semibold text-white">
                Missing Security Metadata ({report.missingInfoAccounts.length})
              </h2>
            </div>

            {report.missingInfoAccounts.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-emerald-300">
                <CheckCircle2 className="w-4 h-4" />
                <span>All accounts include domain URLs and recent rotation timestamps.</span>
              </div>
            ) : (
              <div className="divide-y divide-slate-800/80">
                {report.missingInfoAccounts.map((item) => (
                  <div
                    key={`miss-${item.credential.id}`}
                    className="py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                  >
                    <div>
                      <div className="text-sm font-semibold text-white">
                        {item.credential.title}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        {item.reason}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => onFixCredential(item.credential)}
                      className="px-3.5 py-1.5 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700 text-xs font-medium text-slate-200 shrink-0 cursor-pointer"
                    >
                      Update Details
                    </button>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
};
