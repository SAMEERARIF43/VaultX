import React, { useEffect, useState } from 'react';
import {
  AlertTriangle,
  Eye,
  EyeOff,
  Loader2,
  RefreshCw,
  Trash2,
  X,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';
import { evaluatePasswordStrength, generateSecurePassword } from '../lib/passwordGenerator';
import { DEFAULT_CATEGORIES, type DecryptedCredential } from '../types/vault';

interface CredentialModalProps {
  isOpen: boolean;
  editingCredential?: DecryptedCredential | null;
  initialPassword?: string;
  existingCategories: string[];
  onClose: () => void;
}

export const CredentialModal: React.FC<CredentialModalProps> = ({
  isOpen,
  editingCredential,
  initialPassword = '',
  existingCategories,
  onClose,
}) => {
  const { addCredential, editCredential, removeCredential } = useVault();

  const [title, setTitle] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [url, setUrl] = useState('');
  const [category, setCategory] = useState('Work');
  const [customCategory, setCustomCategory] = useState('');
  const [notes, setNotes] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [saving, setSaving] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const allCategories = Array.from(
    new Set([...DEFAULT_CATEGORIES, ...existingCategories])
  ).sort();

  useEffect(() => {
    if (!isOpen) return;
    setErrorMsg(null);
    setConfirmDelete(false);
    setShowPassword(false);

    if (editingCredential) {
      setTitle(editingCredential.title);
      setUsername(editingCredential.username);
      setPassword(editingCredential.password);
      setUrl(editingCredential.url);
      setCategory(editingCredential.category || 'Personal');
      setCustomCategory('');
      setNotes(editingCredential.notes || '');
    } else {
      setTitle('');
      setUsername('');
      setPassword(initialPassword);
      setUrl('');
      setCategory('Work');
      setCustomCategory('');
      setNotes('');
    }
  }, [isOpen, editingCredential, initialPassword]);

  if (!isOpen) return null;

  const strength = evaluatePasswordStrength(password);
  const barColors = [
    'bg-rose-500',
    'bg-rose-500',
    'bg-amber-500',
    'bg-sky-500',
    'bg-emerald-500',
  ];

  const handleQuickGenerate = () => {
    const generated = generateSecurePassword({
      length: 20,
      uppercase: true,
      lowercase: true,
      numbers: true,
      symbols: true,
      excludeAmbiguous: true,
    });
    setPassword(generated);
    setShowPassword(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (!title.trim()) {
      setErrorMsg('Application or website name is required.');
      return;
    }
    if (!username.trim()) {
      setErrorMsg('Username or email is required.');
      return;
    }
    if (!password) {
      setErrorMsg('Password is required.');
      return;
    }

    const finalCategory =
      category === '__custom__' ? customCategory.trim() || 'Personal' : category;

    setSaving(true);
    try {
      const payload = {
        title: title.trim(),
        username: username.trim(),
        password,
        url: url.trim(),
        category: finalCategory,
        notes: notes.trim(),
      };
      if (editingCredential) {
        await editCredential(editingCredential.id, payload);
      } else {
        await addCredential(payload);
      }
      onClose();
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Unable to save credential.');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!editingCredential) return;
    setSaving(true);
    try {
      await removeCredential(editingCredential.id);
      onClose();
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Failed to delete credential.');
      setSaving(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="credential-modal-title"
    >
      <div className="w-full max-w-lg bg-[#0D1220] border border-slate-800 rounded-2xl shadow-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800">
          <h2 id="credential-modal-title" className="font-display text-lg font-bold text-white">
            {editingCredential ? 'Edit Encrypted Credential' : 'Add New Credential'}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close modal"
            className="text-slate-400 hover:text-white p-1 rounded-lg transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4 overflow-y-auto">
          {errorMsg && (
            <div className="p-3 rounded-lg bg-rose-950/40 border border-rose-500/40 text-xs text-rose-200 flex items-start gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
              <span>{errorMsg}</span>
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Application or Website
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="GitHub, Chase Bank, AWS..."
                className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Category
              </label>
              <select
                value={allCategories.includes(category) ? category : '__custom__'}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white focus:outline-none focus:border-indigo-500"
              >
                {allCategories.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat}
                  </option>
                ))}
                <option value="__custom__">+ Custom Category...</option>
              </select>
            </div>
          </div>

          {category === '__custom__' && (
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Custom Category Name
              </label>
              <input
                type="text"
                required
                value={customCategory}
                onChange={(e) => setCustomCategory(e.target.value)}
                placeholder="e.g. Cloud Infrastructure"
                className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Username or Email
            </label>
            <input
              type="text"
              required
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="name@example.com"
              className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="block text-xs font-medium text-slate-300">
                Password
              </label>
              <button
                type="button"
                onClick={handleQuickGenerate}
                className="inline-flex items-center gap-1 text-xs font-medium text-indigo-400 hover:text-indigo-300 cursor-pointer"
              >
                <RefreshCw className="w-3 h-3" />
                <span>Generate Strong Password</span>
              </button>
            </div>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter or generate password"
                className="w-full px-3.5 py-2.5 pr-10 rounded-lg bg-[#080B14] border border-slate-700/80 font-mono text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <button
                type="button"
                onClick={() => setShowPassword((p) => !p)}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 cursor-pointer"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>

            {password && (
              <div className="mt-2 space-y-1">
                <div className="grid grid-cols-4 gap-1.5">
                  {[0, 1, 2, 3].map((idx) => (
                    <div
                      key={idx}
                      className={`h-1 rounded-full ${
                        idx < strength.score ? barColors[strength.score] : 'bg-slate-800'
                      }`}
                    />
                  ))}
                </div>
                <div className="flex items-center justify-between text-xs text-slate-400 tabular-nums">
                  <span>{strength.label}</span>
                  <span>{strength.entropyBits} bits</span>
                </div>
              </div>
            )}
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Website URL (optional, used for domain matching)
            </label>
            <input
              type="text"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://github.com"
              className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Encrypted Notes (optional)
            </label>
            <textarea
              rows={3}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Backup codes, security questions, or account notes..."
              className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
            />
          </div>

          {editingCredential && !confirmDelete && (
            <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-500 tabular-nums">
              <span>Created {editingCredential.createdAt.toLocaleDateString()}</span>
              <button
                type="button"
                onClick={() => setConfirmDelete(true)}
                className="inline-flex items-center gap-1.5 text-rose-400 hover:text-rose-300 font-medium cursor-pointer"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Delete Credential</span>
              </button>
            </div>
          )}

          {editingCredential && confirmDelete && (
            <div className="p-3.5 rounded-xl bg-rose-950/30 border border-rose-500/40 space-y-2.5">
              <p className="text-xs text-rose-200">
                Permanently delete <strong>{editingCredential.title}</strong> from your encrypted cloud vault? This cannot be undone.
              </p>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  disabled={saving}
                  onClick={handleDelete}
                  className="px-3 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-500 text-xs font-semibold text-white cursor-pointer"
                >
                  Confirm Delete
                </button>
                <button
                  type="button"
                  onClick={() => setConfirmDelete(false)}
                  className="px-3 py-1.5 rounded-lg bg-[#101626] border border-slate-700 text-xs text-slate-300 hover:text-white cursor-pointer"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          <div className="pt-3 flex items-center justify-end gap-3 border-t border-slate-800">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-sm font-medium text-slate-300 transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saving}
              className="px-5 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white transition-colors flex items-center gap-2 cursor-pointer"
            >
              {saving && <Loader2 className="w-4 h-4 animate-spin" />}
              <span>{editingCredential ? 'Encrypt & Update' : 'Encrypt & Save'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
