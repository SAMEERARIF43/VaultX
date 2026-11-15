import React, { useMemo, useState } from 'react';
import {
  Copy,
  Edit3,
  ExternalLink,
  Plus,
  Search,
  ShieldAlert,
  ShieldCheck,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';
import { runSecurityAudit } from '../lib/securityAudit';
import type { AppView, DecryptedCredential } from '../types/vault';

interface DashboardViewProps {
  onAddCredential: () => void;
  onEditCredential: (cred: DecryptedCredential) => void;
  onNavigateView: (view: AppView) => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({
  onAddCredential,
  onEditCredential,
  onNavigateView,
}) => {
  const { decryptedCredentials, copySensitiveValue } = useVault();
  const [quickSearch, setQuickSearch] = useState('');

  const audit = useMemo(
    () => runSecurityAudit(decryptedCredentials),
    [decryptedCredentials]
  );

  const uniqueCategories = useMemo(() => {
    const set = new Set<string>();
    decryptedCredentials.forEach((c) => {
      if (c.category) set.add(c.category);
    });
    return set.size;
  }, [decryptedCredentials]);

  const recentlyAdded = useMemo(() => {
    return [...decryptedCredentials]
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, 5);
  }, [decryptedCredentials]);

  const recentlyModified = useMemo(() => {
    return [...decryptedCredentials]
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime())
      .slice(0, 5);
  }, [decryptedCredentials]);

  const quickSearchResults = useMemo(() => {
    const q = quickSearch.trim().toLowerCase();
    if (!q) return [];
    return decryptedCredentials
      .filter(
        (c) =>
          c.title.toLowerCase().includes(q) ||
          c.username.toLowerCase().includes(q) ||
          c.url.toLowerCase().includes(q) ||
          c.category.toLowerCase().includes(q)
      )
      .slice(0, 6);
  }, [decryptedCredentials, quickSearch]);

  return (
    <div className="space-y-8">
      {/* Header row with quick search + add action */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="font-display text-2xl font-bold text-white tracking-tight">
            Vault Overview
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Client-side decrypted summary across your synchronized cloud credentials.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="relative flex-1 sm:w-72">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="search"
              value={quickSearch}
              onChange={(e) => setQuickSearch(e.target.value)}
              placeholder="Quick search accounts..."
              className="w-full pl-10 pr-4 py-2 rounded-lg bg-[#0D1220] border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>
          <button
            type="button"
            onClick={onAddCredential}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-sm font-semibold text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Add Password</span>
          </button>
        </div>
      </div>

      {/* Live Quick Search Results Drawer */}
      {quickSearch.trim().length > 0 && (
        <div className="rounded-xl bg-[#0D1220] border border-indigo-500/40 p-5">
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-display text-sm font-semibold text-white">
              Quick Search Matches ({quickSearchResults.length})
            </h2>
            <button
              type="button"
              onClick={() => setQuickSearch('')}
              className="text-xs text-slate-400 hover:text-white cursor-pointer"
            >
              Clear
            </button>
          </div>

          {quickSearchResults.length === 0 ? (
            <p className="text-sm text-slate-400">
              No credentials match &ldquo;{quickSearch}&rdquo;.
            </p>
          ) : (
            <div className="divide-y divide-slate-800/80">
              {quickSearchResults.map((cred) => (
                <div
                  key={cred.id}
                  className="py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                >
                  <div className="min-w-0">
                    <div className="font-medium text-sm text-white truncate">
                      {cred.title}
                    </div>
                    <div className="text-xs text-slate-400 truncate mt-0.5">
                      <span>{cred.username}</span>
                      <span className="mx-1.5" aria-hidden="true">·</span>
                      <span>{cred.category}</span>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <button
                      type="button"
                      onClick={() => copySensitiveValue(cred.username, 'Username', false)}
                      className="px-2.5 py-1.5 rounded-md bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs text-slate-200 cursor-pointer"
                    >
                      Copy User
                    </button>
                    <button
                      type="button"
                      onClick={() => copySensitiveValue(cred.password, `${cred.title} password`, true)}
                      className="px-2.5 py-1.5 rounded-md bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs text-indigo-300 cursor-pointer"
                    >
                      Copy Pass
                    </button>
                    <button
                      type="button"
                      onClick={() => onEditCredential(cred)}
                      className="px-2.5 py-1.5 rounded-md bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs text-slate-300 cursor-pointer"
                    >
                      Edit
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* 4 KPI Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <button
          type="button"
          onClick={() => onNavigateView('vault')}
          className="text-left p-5 rounded-xl bg-[#0D1220] border border-slate-800/90 hover:border-slate-700 transition-colors cursor-pointer"
        >
          <div className="text-xs font-medium text-slate-400">Total Saved Accounts</div>
          <div className="font-display text-3xl font-bold text-white mt-2 tabular-nums">
            {decryptedCredentials.length}
          </div>
          <div className="text-xs text-slate-500 mt-1.5">
            Encrypted with AES-256-GCM
          </div>
        </button>

        <button
          type="button"
          onClick={() => onNavigateView('categories')}
          className="text-left p-5 rounded-xl bg-[#0D1220] border border-slate-800/90 hover:border-slate-700 transition-colors cursor-pointer"
        >
          <div className="text-xs font-medium text-slate-400">Active Categories</div>
          <div className="font-display text-3xl font-bold text-white mt-2 tabular-nums">
            {uniqueCategories}
          </div>
          <div className="text-xs text-slate-500 mt-1.5">
            Organized credential groups
          </div>
        </button>

        <button
          type="button"
          onClick={() => onNavigateView('security')}
          className="text-left p-5 rounded-xl bg-[#0D1220] border border-slate-800/90 hover:border-slate-700 transition-colors cursor-pointer"
        >
          <div className="text-xs font-medium text-slate-400">Weak Passwords</div>
          <div
            className={`font-display text-3xl font-bold mt-2 tabular-nums ${
              audit.weakPasswords.length > 0 ? 'text-amber-400' : 'text-emerald-400'
            }`}
          >
            {audit.weakPasswords.length}
          </div>
          <div className="text-xs text-slate-500 mt-1.5">
            {audit.weakPasswords.length > 0
              ? 'Review in Security Center'
              : 'All passwords meet baseline'}
          </div>
        </button>

        <button
          type="button"
          onClick={() => onNavigateView('security')}
          className="text-left p-5 rounded-xl bg-[#0D1220] border border-slate-800/90 hover:border-slate-700 transition-colors cursor-pointer"
        >
          <div className="text-xs font-medium text-slate-400">Reused Passwords</div>
          <div
            className={`font-display text-3xl font-bold mt-2 tabular-nums ${
              audit.reusedCount > 0 ? 'text-rose-400' : 'text-emerald-400'
            }`}
          >
            {audit.reusedCount}
          </div>
          <div className="text-xs text-slate-500 mt-1.5">
            {audit.reusedGroups.length > 0
              ? `Across ${audit.reusedGroups.length} shared group(s)`
              : 'Zero password reuse detected'}
          </div>
        </button>
      </div>

      {/* Security Summary Banner */}
      <div className="p-5 rounded-xl bg-[#0D1220] border border-slate-800/90 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-start gap-3.5">
          {audit.compromisedPasswords.length > 0 || audit.weakPasswords.length > 0 ? (
            <ShieldAlert className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
          ) : (
            <ShieldCheck className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
          )}
          <div>
            <div className="text-sm font-semibold text-white">
              Vault Hygiene Health: <span className="tabular-nums">{audit.healthPercentage}%</span>
            </div>
            <p className="text-xs text-slate-400 mt-1">
              {decryptedCredentials.length === 0
                ? 'Add your first credential to begin continuous local security auditing.'
                : `${audit.compromisedPasswords.length} compromised · ${audit.weakPasswords.length} weak · ${audit.reusedCount} reused · ${audit.missingInfoAccounts.length} missing metadata`}
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => onNavigateView('security')}
          className="px-4 py-2 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs font-semibold text-slate-200 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          Open Security Center
        </button>
      </div>

      {/* Two-Column Recently Added & Recently Modified */}
      {decryptedCredentials.length === 0 ? (
        <div className="p-10 rounded-xl bg-[#0D1220] border border-slate-800/90 text-center">
          <h2 className="font-display text-lg font-semibold text-white">
            Your encrypted vault is empty
          </h2>
          <p className="text-sm text-slate-400 mt-1.5 max-w-md mx-auto">
            Save your first login credential. Everything is encrypted in your browser with AES-256-GCM before syncing to Cloud Firestore.
          </p>
          <button
            type="button"
            onClick={onAddCredential}
            className="mt-5 inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-sm font-semibold text-white transition-colors cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Add First Credential</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Recently Added */}
          <div className="rounded-xl bg-[#0D1220] border border-slate-800/90 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-display text-base font-semibold text-white">
                Recently Added Accounts
              </h2>
              <button
                type="button"
                onClick={() => onNavigateView('vault')}
                className="text-xs text-indigo-400 hover:text-indigo-300 cursor-pointer"
              >
                View All
              </button>
            </div>
            <div className="divide-y divide-slate-800/80">
              {recentlyAdded.map((cred) => (
                <div
                  key={`added-${cred.id}`}
                  className="py-3 flex items-center justify-between gap-3"
                >
                  <div className="min-w-0">
                    <div className="text-sm font-medium text-white truncate">
                      {cred.title}
                    </div>
                    <div className="text-xs text-slate-400 truncate mt-0.5 tabular-nums">
                      <span>{cred.username}</span>
                      <span className="mx-1.5" aria-hidden="true">·</span>
                      <span>{cred.category}</span>
                      <span className="mx-1.5" aria-hidden="true">·</span>
                      <span>{cred.createdAt.toLocaleDateString()}</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-1.5 shrink-0">
                    <button
                      type="button"
                      title="Copy password"
                      onClick={() => copySensitiveValue(cred.password, `${cred.title} password`, true)}
                      className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/70 transition-colors cursor-pointer"
                    >
                      <Copy className="w-4 h-4" />
                    </button>
                    <button
                      type="button"
                      title="Edit credential"
                      onClick={() => onEditCredential(cred)}
                      className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/70 transition-colors cursor-pointer"
                    >
                      <Edit3 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Recently Modified */}
          <div className="rounded-xl bg-[#0D1220] border border-slate-800/90 p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-display text-base font-semibold text-white">
                Recently Modified Accounts
              </h2>
              <button
                type="button"
                onClick={() => onNavigateView('vault')}
                className="text-xs text-indigo-400 hover:text-indigo-300 cursor-pointer"
              >
                View All
              </button>
            </div>
            <div className="divide-y divide-slate-800/80">
              {recentlyModified.map((cred) => (
                <div
                  key={`mod-${cred.id}`}
                  className="py-3 flex items-center justify-between gap-3"
                >
                  <div className="min-w-0">
                    <div className="text-sm font-medium text-white truncate">
                      {cred.title}
                    </div>
                    <div className="text-xs text-slate-400 truncate mt-0.5 tabular-nums">
                      <span>{cred.username}</span>
                      <span className="mx-1.5" aria-hidden="true">·</span>
                      <span>Updated {cred.updatedAt.toLocaleDateString()}</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-1.5 shrink-0">
                    {cred.url && (
                      <a
                        href={/^https?:\/\//i.test(cred.url) ? cred.url : `https://${cred.url}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        title="Open website"
                        className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/70 transition-colors"
                      >
                        <ExternalLink className="w-4 h-4" />
                      </a>
                    )}
                    <button
                      type="button"
                      title="Edit credential"
                      onClick={() => onEditCredential(cred)}
                      className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/70 transition-colors cursor-pointer"
                    >
                      <Edit3 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
