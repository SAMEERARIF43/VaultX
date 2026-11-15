import React, { useState } from 'react';
import { ArrowRight, KeyRound, Lock, RefreshCw, ShieldCheck } from 'lucide-react';

interface LandingPageProps {
  onNavigate: (route: 'login' | 'register') => void;
}

export const LandingPage: React.FC<LandingPageProps> = ({ onNavigate }) => {
  const [imgFailed, setImgFailed] = useState(false);

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex flex-col">
      {/* 3-Zone Top Bar Contract */}
      <header className="border-b border-slate-800/80 bg-[#080B14]/90 backdrop-blur-md sticky top-0 z-30">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between gap-8">
          <a
            href="#top"
            className="font-display text-xl font-bold tracking-tight text-white whitespace-nowrap shrink-0 flex items-center gap-2.5"
          >
            <ShieldCheck className="w-5 h-5 text-indigo-400" />
            <span>VaultX</span>
          </a>

          <nav className="hidden md:flex items-center gap-7 text-sm font-medium text-slate-300">
            <a
              href="#architecture"
              className="hover:text-white transition-colors whitespace-nowrap shrink-0"
            >
              Encryption
            </a>
            <a
              href="#capabilities"
              className="hover:text-white transition-colors whitespace-nowrap shrink-0"
            >
              Capabilities
            </a>
            <a
              href="#extension"
              className="hover:text-white transition-colors whitespace-nowrap shrink-0"
            >
              Extension Roadmap
            </a>
            <button
              type="button"
              onClick={() => onNavigate('login')}
              className="hover:text-white transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              Sign In
            </button>
          </nav>

          <div className="flex items-center shrink-0">
            <button
              type="button"
              onClick={() => onNavigate('register')}
              className="px-4 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-500 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              Create Vault
            </button>
          </div>
        </div>
      </header>

      <main id="top" className="flex-1">
        {/* Hero Split Section */}
        <section className="max-w-7xl mx-auto px-6 pt-16 pb-20 lg:pt-24 lg:pb-24">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-stretch">
            <div className="lg:col-span-6 flex flex-col justify-center">
              <p className="text-sm font-medium text-indigo-400 mb-4 tracking-wide">
                Zero-Knowledge Cloud Password Management
              </p>
              <h1 className="font-display text-[clamp(2.25rem,4vw,3.5rem)] font-bold tracking-tight text-white leading-[1.08] text-balance mb-6">
                Your credentials encrypted locally before they ever touch the cloud.
              </h1>
              <p className="text-base sm:text-lg text-slate-300 leading-relaxed max-w-xl mb-8">
                VaultX derives your encryption key in your browser using Argon2id and seals every credential with AES-256-GCM and a unique 96-bit nonce before syncing across devices.
              </p>

              <div className="flex flex-wrap items-center gap-4">
                <button
                  type="button"
                  onClick={() => onNavigate('register')}
                  className="inline-flex items-center gap-2 px-6 py-3 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-500 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  <span>Create Encrypted Vault</span>
                  <ArrowRight className="w-4 h-4" />
                </button>
                <button
                  type="button"
                  onClick={() => onNavigate('login')}
                  className="inline-flex items-center gap-2 px-6 py-3 text-sm font-semibold text-slate-200 bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                >
                  <span>Sign In to Existing Vault</span>
                </button>
              </div>

              <div className="mt-10 pt-8 border-t border-slate-800/80 grid grid-cols-3 gap-6 max-w-lg">
                <div>
                  <div className="font-mono text-lg font-semibold text-white tabular-nums">
                    Argon2id
                  </div>
                  <div className="text-xs text-slate-400 mt-1">
                    64 MiB key derivation
                  </div>
                </div>
                <div>
                  <div className="font-mono text-lg font-semibold text-white tabular-nums">
                    AES-256-GCM
                  </div>
                  <div className="text-xs text-slate-400 mt-1">
                    Authenticated encryption
                  </div>
                </div>
                <div>
                  <div className="font-mono text-lg font-semibold text-white tabular-nums">
                    96-bit IV
                  </div>
                  <div className="text-xs text-slate-400 mt-1">
                    Unique nonce per write
                  </div>
                </div>
              </div>
            </div>

            <div className="lg:col-span-6 flex">
              <div className="w-full rounded-2xl overflow-hidden border border-slate-800 bg-[#0D1220] flex items-center justify-center min-h-[320px]">
                {!imgFailed ? (
                  <img
                    src="/src/assets/images/vaultx_hero_architecture_1794733965030.jpg"
                    alt="VaultX titanium cryptographic vault door mechanism"
                    referrerPolicy="no-referrer"
                    onError={() => setImgFailed(true)}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="p-10 text-center flex flex-col items-center justify-center gap-4">
                    <Lock className="w-12 h-12 text-indigo-400" />
                    <div className="font-display text-lg font-semibold text-slate-200">
                      Client-Side Cryptographic Isolation
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </section>

        {/* Architecture Mechanism Section */}
        <section
          id="architecture"
          className="border-t border-slate-800/80 bg-[#0B0F1B] py-20"
        >
          <div className="max-w-7xl mx-auto px-6">
            <div className="max-w-2xl mb-12">
              <h2 className="font-display text-2xl sm:text-3xl font-bold text-white tracking-tight text-balance">
                Zero-knowledge architecture built on Web Crypto standards
              </h2>
              <p className="text-slate-400 mt-3 text-base leading-relaxed">
                Authentication verifies your identity to Cloud Firestore, while your Master Password never leaves your device.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
              <div className="md:col-span-7 p-7 rounded-xl bg-[#0F1526] border border-slate-800/90">
                <h3 className="font-display text-lg font-semibold text-white mb-2">
                  01. Dual-Secret Separation (Account vs. Master Password)
                </h3>
                <p className="text-sm text-slate-300 leading-relaxed mb-5">
                  Your Firebase Authentication password grants access to your isolated user record. Your separate Master Password derives a 256-bit Key Encryption Key via Argon2id to unwrap your Vault Data Encryption Key locally.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-4 border-t border-slate-800/80 text-xs text-slate-400">
                  <div>
                    <span className="text-slate-200 font-medium block mb-1">
                      What Cloud Firestore Stores
                    </span>
                    Salts, Argon2id parameters, wrapped vault key, and AES-GCM ciphertext records.
                  </div>
                  <div>
                    <span className="text-slate-200 font-medium block mb-1">
                      What Never Leaves Your Browser
                    </span>
                    Master password, plaintext credentials, notes, URLs, and unwrapped vault keys.
                  </div>
                </div>
              </div>

              <div className="md:col-span-5 p-7 rounded-xl bg-[#0F1526] border border-slate-800/90 flex flex-col justify-between">
                <div>
                  <h3 className="font-display text-lg font-semibold text-white mb-2">
                    02. 256-Bit Recovery Key Design
                  </h3>
                  <p className="text-sm text-slate-300 leading-relaxed">
                    Because VaultX cannot reset your Master Password on the server, setup generates a 256-bit Recovery Key that independently wraps your Vault Key for emergency access.
                  </p>
                </div>
                <div className="mt-6 pt-4 border-t border-slate-800/80 flex items-center gap-3 text-xs text-slate-400">
                  <KeyRound className="w-4 h-4 text-indigo-400 shrink-0" />
                  <span>Rotatable anytime from Account Settings after verifying your Master Password.</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Capabilities Bento */}
        <section id="capabilities" className="border-t border-slate-800/80 py-20">
          <div className="max-w-7xl mx-auto px-6">
            <div className="max-w-2xl mb-12">
              <h2 className="font-display text-2xl sm:text-3xl font-bold text-white tracking-tight text-balance">
                Everything needed to manage, audit, and synchronize credentials
              </h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="p-6 rounded-xl bg-[#0D1220] border border-slate-800/90">
                <h3 className="font-display text-base font-semibold text-white mb-2">
                  Encrypted Cloud Vault
                </h3>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Organize accounts by category, attach notes and URLs, search instantaneously in memory, and sync live across devices via Firestore.
                </p>
              </div>

              <div className="p-6 rounded-xl bg-[#0D1220] border border-slate-800/90">
                <h3 className="font-display text-base font-semibold text-white mb-2">
                  Unbiased Password Generator
                </h3>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Uses Web Crypto rejection sampling with customizable length and character sets, entropy estimation, and one-click vault saving.
                </p>
              </div>

              <div className="p-6 rounded-xl bg-[#0D1220] border border-slate-800/90">
                <h3 className="font-display text-base font-semibold text-white mb-2">
                  Local Security Center
                </h3>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Flags weak, reused, stale, and common breached passwords completely inside your browser without transmitting secrets to third parties.
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* Future-Ready Browser Extension Section */}
        <section
          id="extension"
          className="border-t border-slate-800/80 bg-[#0B0F1B] py-20"
        >
          <div className="max-w-7xl mx-auto px-6 grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">
            <div className="lg:col-span-7">
              <h2 className="font-display text-2xl sm:text-3xl font-bold text-white tracking-tight text-balance mb-4">
                Built for future Chrome and Edge extension integration
              </h2>
              <p className="text-sm sm:text-base text-slate-300 leading-relaxed mb-6">
                Browsers enforce Same-Origin Policy so standard web apps cannot inspect forms on other websites. VaultX separates domain-matching utilities, Manifest V3 message contracts, and encrypted Firestore sync so a companion extension can detect login, registration, and password-change forms with explicit user autofill consent.
              </p>
              <div className="flex flex-wrap gap-6 text-xs text-slate-400">
                <div className="flex items-center gap-2">
                  <RefreshCw className="w-4 h-4 text-indigo-400" />
                  <span>Real-time Firestore sync contract</span>
                </div>
                <div className="flex items-center gap-2">
                  <ShieldCheck className="w-4 h-4 text-indigo-400" />
                  <span>Strict host &amp; origin matching</span>
                </div>
              </div>
            </div>

            <div className="lg:col-span-5 p-6 rounded-xl bg-[#080B14] border border-slate-800 font-mono text-xs text-slate-300 space-y-2">
              <div className="text-slate-400">Extension Message Contract (Manifest V3)</div>
              <pre className="overflow-x-auto text-indigo-300 leading-relaxed">
{`{
  "type": "VAULTX_DETECTED_FORM",
  "origin": "https://github.com",
  "formKind": "password-change",
  "authorizedByUserGesture": true
}`}
              </pre>
            </div>
          </div>
        </section>
      </main>

      {/* Quiet Footer */}
      <footer className="border-t border-slate-800/80 py-8 px-6">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <div>VaultX · Client-Side Argon2id &amp; AES-256-GCM Password Manager</div>
          <div className="flex items-center gap-6">
            <button
              type="button"
              onClick={() => onNavigate('login')}
              className="hover:text-slate-300 transition-colors cursor-pointer"
            >
              Sign In
            </button>
            <button
              type="button"
              onClick={() => onNavigate('register')}
              className="hover:text-slate-300 transition-colors cursor-pointer"
            >
              Create Account
            </button>
          </div>
        </div>
      </footer>
    </div>
  );
};
