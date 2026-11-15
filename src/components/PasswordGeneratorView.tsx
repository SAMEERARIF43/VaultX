import React, { useCallback, useEffect, useState } from 'react';
import { Copy, Plus, RefreshCw, ShieldCheck } from 'lucide-react';
import { useVault } from '../context/VaultContext';
import { evaluatePasswordStrength, generateSecurePassword } from '../lib/passwordGenerator';
import type { PasswordGeneratorOptions } from '../types/vault';

interface PasswordGeneratorViewProps {
  onSaveToVault: (generatedPassword: string) => void;
}

export const PasswordGeneratorView: React.FC<PasswordGeneratorViewProps> = ({
  onSaveToVault,
}) => {
  const { copySensitiveValue } = useVault();
  const [options, setOptions] = useState<PasswordGeneratorOptions>({
    length: 20,
    uppercase: true,
    lowercase: true,
    numbers: true,
    symbols: true,
    excludeAmbiguous: true,
  });
  const [password, setPassword] = useState('');

  const regenerate = useCallback((opts: PasswordGeneratorOptions) => {
    try {
      const next = generateSecurePassword(opts);
      setPassword(next);
    } catch {
      // At least one option must stay active
    }
  }, []);

  useEffect(() => {
    regenerate(options);
  }, [options, regenerate]);

  const strength = evaluatePasswordStrength(password);

  const toggleOption = (key: keyof Omit<PasswordGeneratorOptions, 'length'>) => {
    const next = { ...options, [key]: !options[key] };
    // Prevent unchecking all 4 character pools
    if (!next.uppercase && !next.lowercase && !next.numbers && !next.symbols) {
      return;
    }
    setOptions(next);
  };

  const barColors = [
    'bg-rose-500',
    'bg-rose-500',
    'bg-amber-500',
    'bg-sky-500',
    'bg-emerald-500',
  ];

  return (
    <div className="max-w-3xl space-y-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-white tracking-tight">
          Cryptographic Password Generator
        </h1>
        <p className="text-sm text-slate-400 mt-1">
          Generated locally using <code className="text-indigo-300">crypto.getRandomValues</code> with rejection sampling to eliminate modulo bias.
        </p>
      </div>

      {/* Output Card */}
      <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-5">
        <div className="p-5 rounded-xl bg-[#080B14] border border-slate-800 font-mono text-lg sm:text-xl tracking-wide break-all leading-relaxed select-all">
          {password.split('').map((ch, idx) => {
            const isDigit = /[0-9]/.test(ch);
            const isSymbol = /[^a-zA-Z0-9]/.test(ch);
            const color = isDigit
              ? 'text-sky-400'
              : isSymbol
                ? 'text-indigo-400'
                : 'text-slate-100';
            return (
              <span key={idx} className={color}>
                {ch}
              </span>
            );
          })}
        </div>

        {/* Strength Meter */}
        <div className="space-y-2">
          <div className="grid grid-cols-4 gap-2">
            {[0, 1, 2, 3].map((idx) => (
              <div
                key={idx}
                className={`h-2 rounded-full transition-colors ${
                  idx < strength.score ? barColors[strength.score] : 'bg-slate-800'
                }`}
              />
            ))}
          </div>
          <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-400 tabular-nums">
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-emerald-400" />
              <span className="text-slate-200 font-medium">{strength.label}</span>
              <span aria-hidden="true">·</span>
              <span>{strength.entropyBits} bits entropy</span>
            </div>
            <span>Est. offline brute-force: {strength.crackTimeLabel}</span>
          </div>
        </div>

        {/* Primary Action Buttons */}
        <div className="flex flex-wrap items-center gap-3 pt-1">
          <button
            type="button"
            onClick={() => regenerate(options)}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-sm font-medium text-slate-200 transition-colors cursor-pointer"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Regenerate</span>
          </button>

          <button
            type="button"
            onClick={() => copySensitiveValue(password, 'Generated password', true)}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-sm font-semibold text-white transition-colors cursor-pointer"
          >
            <Copy className="w-4 h-4" />
            <span>Copy Password</span>
          </button>

          <button
            type="button"
            onClick={() => onSaveToVault(password)}
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-emerald-600/20 hover:bg-emerald-600/30 border border-emerald-500/40 text-sm font-semibold text-emerald-200 transition-colors cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Save to Vault</span>
          </button>
        </div>
      </div>

      {/* Controls Card */}
      <div className="p-6 rounded-2xl bg-[#0D1220] border border-slate-800/90 space-y-6">
        <div>
          <div className="flex items-center justify-between mb-2">
            <label htmlFor="pw-length" className="text-sm font-medium text-white">
              Password Length
            </label>
            <span className="font-mono text-base font-bold text-indigo-300 tabular-nums">
              {options.length} characters
            </span>
          </div>
          <input
            id="pw-length"
            type="range"
            min={8}
            max={64}
            value={options.length}
            onChange={(e) => setOptions((prev) => ({ ...prev, length: Number(e.target.value) }))}
            className="w-full accent-indigo-500 cursor-pointer"
          />
          <div className="flex justify-between text-xs text-slate-500 mt-1 tabular-nums">
            <span>8</span>
            <span>16</span>
            <span>32</span>
            <span>48</span>
            <span>64</span>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2 border-t border-slate-800/80">
          {[
            { key: 'uppercase', label: 'Uppercase Letters (A–Z)' },
            { key: 'lowercase', label: 'Lowercase Letters (a–z)' },
            { key: 'numbers', label: 'Numbers (0–9)' },
            { key: 'symbols', label: 'Special Characters (!@#$...)' },
            { key: 'excludeAmbiguous', label: 'Exclude Ambiguous (0, O, 1, l, I)' },
          ].map((item) => {
            const k = item.key as keyof Omit<PasswordGeneratorOptions, 'length'>;
            return (
              <label
                key={item.key}
                className="flex items-center justify-between p-3.5 rounded-xl bg-[#080B14] border border-slate-800 cursor-pointer hover:border-slate-700 transition-colors"
              >
                <span className="text-sm text-slate-200">{item.label}</span>
                <input
                  type="checkbox"
                  checked={options[k]}
                  onChange={() => toggleOption(k)}
                  className="w-4 h-4 rounded border-slate-600 bg-[#0D1220] text-indigo-600 focus:ring-indigo-500"
                />
              </label>
            );
          })}
        </div>
      </div>
    </div>
  );
};
