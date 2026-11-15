import React, { useMemo, useState } from 'react';
import {
  Copy,
  Edit3,
  ExternalLink,
  Eye,
  EyeOff,
  Plus,
  Search,
  Trash2,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';
import { ReauthModal } from './ReauthModal';
import { DEFAULT_CATEGORIES, type DecryptedCredential } from '../types/vault';

interface VaultListViewProps {
  initialViewMode?: 'vault' | 'categories';
  onAddCredential: () => void;
  onEditCredential: (cred: DecryptedCredential) => void;
}

export const VaultListView: React.FC<VaultListViewProps> = ({
  initialViewMode = 'vault',
  onAddCredential,
  onEditCredential,
}) => {
  const {
    decryptedCredentials,
    securitySettings,
    copySensitiveValue,
    removeCredential,
  } = useVault();

  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [sortBy, setSortBy] = useState<'updated' | 'created' | 'title'>('updated');
  const [revealedIds, setRevealedIds] = useState<Set<string>>(new Set());
  const [deleteTarget, setDeleteTarget] = useState<DecryptedCredential | null>(null);
  const [reauthPendingId, setReauthPendingId] = useState<string | null>(null);
  const [sessionReauthenticated, setSessionReauthenticated] = useState(false);

  const categoriesWithCounts = useMemo(() => {
    const counts = new Map<string, number>();
    DEFAULT_CATEGORIES.forEach((cat) => counts.set(cat, 0));
    decryptedCredentials.forEach((cred) => {
      const cat = cred.category || 'Personal';
      counts.set(cat, (counts.get(cat) || 0) + 1);
    });
    return Array.from(counts.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [decryptedCredentials]);

  const filtered = useMemo(() => {
    const q = searchTerm.trim().toLowerCase();
    const list = decryptedCredentials.filter((cred) => {
      const matchesCat =
        selectedCategory === 'All' || (cred.category || 'Personal') === selectedCategory;
      if (!matchesCat) return false;
      if (!q) return true;
      return (
        cred.title.toLowerCase().includes(q) ||
        cred.username.toLowerCase().includes(q) ||
        cred.url.toLowerCase().includes(q) ||
        cred.category.toLowerCase().includes(q) ||
        cred.notes.toLowerCase().includes(q)
      );
    });

    list.sort((a, b) => {
      if (sortBy === 'title') return a.title.localeCompare(b.title);
      if (sortBy === 'created') return b.createdAt.getTime() - a.createdAt.getTime();
      return b.updatedAt.getTime() - a.updatedAt.getTime();
    });

    return list;
  }, [decryptedCredentials, searchTerm, selectedCategory, sortBy]);

  const toggleReveal = (id: string) => {
    if (revealedIds.has(id)) {
      setRevealedIds((prev) => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
      return;
    }

    if (securitySettings.requireReauthForReveal && !sessionReauthenticated) {
      setReauthPendingId(id);
      return;
    }

    setRevealedIds((prev) => new Set(prev).add(id));
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    await removeCredential(deleteTarget.id);
    setDeleteTarget(null);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="font-display text-2xl font-bold text-white tracking-tight">
            {initialViewMode === 'categories' ? 'Vault Categories' : 'Encrypted Password Vault'}
          </h1>
          <p className="text-sm text-slate-400 mt-1 tabular-nums">
            {decryptedCredentials.length} total saved credentials · decrypted locally in memory
          </p>
        </div>

        <button
          type="button"
          onClick={onAddCredential}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-sm font-semibold text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          <Plus className="w-4 h-4" />
          <span>Add Credential</span>
        </button>
      </div>

      {/* Category Summary Grid when in Categories mode */}
      {initialViewMode === 'categories' && (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          <button
            type="button"
            onClick={() => setSelectedCategory('All')}
            className={`text-left p-4 rounded-xl border transition-colors cursor-pointer ${
              selectedCategory === 'All'
                ? 'bg-indigo-600/15 border-indigo-500/60 text-white'
                : 'bg-[#0D1220] border-slate-800/90 text-slate-300 hover:border-slate-700'
            }`}
          >
            <div className="text-xs text-slate-400">All Credentials</div>
            <div className="font-display text-2xl font-bold text-white mt-1 tabular-nums">
              {decryptedCredentials.length}
            </div>
          </button>
          {categoriesWithCounts.map(([cat, count]) => (
            <button
              key={cat}
              type="button"
              onClick={() => setSelectedCategory(cat)}
              className={`text-left p-4 rounded-xl border transition-colors cursor-pointer ${
                selectedCategory === cat
                  ? 'bg-indigo-600/15 border-indigo-500/60 text-white'
                  : 'bg-[#0D1220] border-slate-800/90 text-slate-300 hover:border-slate-700'
              }`}
            >
              <div className="text-xs text-slate-400 truncate">{cat}</div>
              <div className="font-display text-2xl font-bold text-white mt-1 tabular-nums">
                {count}
              </div>
            </button>
          ))}
        </div>
      )}

      {/* Search, Category Filter Bar & Sort */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="search"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by title, username, URL, or notes..."
            className="w-full pl-10 pr-4 py-2.5 rounded-lg bg-[#0D1220] border border-slate-800 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="flex items-center gap-1 p-1 rounded-lg bg-[#0D1220] border border-slate-800 overflow-x-auto max-w-full">
            <button
              type="button"
              onClick={() => setSelectedCategory('All')}
              className={`px-3 py-1.5 rounded-md text-xs font-medium whitespace-nowrap transition-colors cursor-pointer ${
                selectedCategory === 'All'
                  ? 'bg-indigo-600 text-white'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              All
            </button>
            {categoriesWithCounts
              .filter(([, count]) => count > 0 || DEFAULT_CATEGORIES.includes('Work'))
              .slice(0, 6)
              .map(([cat]) => (
                <button
                  key={cat}
                  type="button"
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-3 py-1.5 rounded-md text-xs font-medium whitespace-nowrap transition-colors cursor-pointer ${
                    selectedCategory === cat
                      ? 'bg-indigo-600 text-white'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  {cat}
                </button>
              ))}
          </div>

          <select
            aria-label="Sort credentials"
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as 'updated' | 'created' | 'title')}
            className="px-3 py-2 rounded-lg bg-[#0D1220] border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
          >
            <option value="updated">Sort: Last Modified</option>
            <option value="created">Sort: Date Created</option>
            <option value="title">Sort: Name A–Z</option>
          </select>
        </div>
      </div>

      {/* Credential Records List */}
      {filtered.length === 0 ? (
        <div className="p-12 rounded-xl bg-[#0D1220] border border-slate-800/90 text-center">
          <h2 className="font-display text-lg font-semibold text-white">
            {decryptedCredentials.length === 0
              ? 'No saved credentials yet'
              : 'No matching credentials found'}
          </h2>
          <p className="text-sm text-slate-400 mt-1.5">
            {decryptedCredentials.length === 0
              ? 'Create your first encrypted entry to store passwords, URLs, and notes securely.'
              : 'Try adjusting your search query or selected category filter.'}
          </p>
          {decryptedCredentials.length === 0 && (
            <button
              type="button"
              onClick={onAddCredential}
              className="mt-5 inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-sm font-semibold text-white cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>Add Credential</span>
            </button>
          )}
        </div>
      ) : (
        <div className="rounded-xl bg-[#0D1220] border border-slate-800/90 divide-y divide-slate-800/80">
          {filtered.map((cred) => {
            const isRevealed = revealedIds.has(cred.id);
            const initial = (cred.title || '?').slice(0, 2).toUpperCase();

            return (
              <div
                key={cred.id}
                className="p-5 hover:bg-[#11182B]/70 transition-colors flex flex-col lg:flex-row lg:items-center justify-between gap-4"
              >
                <div className="flex items-start gap-4 min-w-0 flex-1">
                  <div className="w-10 h-10 rounded-lg bg-indigo-500/15 border border-indigo-500/25 flex items-center justify-center font-display text-sm font-bold text-indigo-300 shrink-0">
                    {initial}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="font-display text-base font-semibold text-white truncate">
                        {cred.title}
                      </h3>
                      {cred.url && (
                        <a
                          href={/^https?:\/\//i.test(cred.url) ? cred.url : `https://${cred.url}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-xs text-indigo-400 hover:text-indigo-300 truncate max-w-[220px]"
                        >
                          <span className="truncate">{cred.url.replace(/^https?:\/\//, '')}</span>
                          <ExternalLink className="w-3 h-3 shrink-0" />
                        </a>
                      )}
                    </div>

                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-slate-400 tabular-nums">
                      <span className="text-slate-300">{cred.username}</span>
                      <span aria-hidden="true">·</span>
                      <span>{cred.category}</span>
                      <span aria-hidden="true">·</span>
                      <span>Updated {cred.updatedAt.toLocaleDateString()}</span>
                    </div>

                    {cred.notes && (
                      <p className="mt-2 text-xs text-slate-400 line-clamp-2 max-w-2xl">
                        {cred.notes}
                      </p>
                    )}
                  </div>
                </div>

                {/* Secret Field & Controls */}
                <div className="flex flex-wrap items-center gap-2 sm:gap-2.5 shrink-0">
                  <div className="px-3 py-1.5 rounded-lg bg-[#080B14] border border-slate-800 font-mono text-xs text-slate-200 min-w-[140px] max-w-[210px] truncate">
                    {isRevealed ? cred.password : '••••••••••••••••'}
                  </div>

                  <button
                    type="button"
                    onClick={() => toggleReveal(cred.id)}
                    title={isRevealed ? 'Hide password' : 'Reveal password'}
                    className="p-2 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-slate-300 hover:text-white transition-colors cursor-pointer"
                  >
                    {isRevealed ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>

                  <button
                    type="button"
                    onClick={() => copySensitiveValue(cred.username, 'Username', false)}
                    className="px-3 py-2 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs font-medium text-slate-200 transition-colors cursor-pointer"
                  >
                    Copy User
                  </button>

                  <button
                    type="button"
                    onClick={() =>
                      copySensitiveValue(cred.password, `${cred.title} password`, true)
                    }
                    className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-indigo-600/20 hover:bg-indigo-600/30 border border-indigo-500/40 text-xs font-medium text-indigo-200 transition-colors cursor-pointer"
                  >
                    <Copy className="w-3.5 h-3.5" />
                    <span>Copy Pass</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => onEditCredential(cred)}
                    title="Edit credential"
                    className="p-2 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-slate-300 hover:text-white transition-colors cursor-pointer"
                  >
                    <Edit3 className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setDeleteTarget(cred)}
                    title="Delete credential"
                    className="p-2 rounded-lg bg-[#101626] hover:bg-rose-950/60 border border-slate-700/80 hover:border-rose-500/40 text-slate-400 hover:text-rose-300 transition-colors cursor-pointer"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteTarget && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4"
          role="dialog"
          aria-modal="true"
        >
          <div className="w-full max-w-sm bg-[#0D1220] border border-slate-800 rounded-2xl p-6 shadow-2xl">
            <h2 className="font-display text-lg font-bold text-white">
              Delete Credential?
            </h2>
            <p className="text-sm text-slate-300 mt-2">
              This will permanently remove <strong>{deleteTarget.title}</strong> ({deleteTarget.username}) from your encrypted Firestore vault.
            </p>
            <div className="mt-5 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setDeleteTarget(null)}
                className="px-4 py-2 rounded-lg bg-[#101626] border border-slate-700 text-xs font-medium text-slate-300 hover:text-white cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={confirmDelete}
                className="px-4 py-2 rounded-lg bg-rose-600 hover:bg-rose-500 text-xs font-semibold text-white cursor-pointer"
              >
                Delete Permanently
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Re-authentication Gate Modal */}
      <ReauthModal
        isOpen={Boolean(reauthPendingId)}
        actionDescription="reveal hidden vault passwords"
        onVerified={() => {
          setSessionReauthenticated(true);
          if (reauthPendingId) {
            setRevealedIds((prev) => new Set(prev).add(reauthPendingId));
          }
          setReauthPendingId(null);
        }}
        onCancel={() => setReauthPendingId(null)}
      />
    </div>
  );
};
