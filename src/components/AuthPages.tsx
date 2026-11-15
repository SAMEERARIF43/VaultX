import React, { useEffect, useState } from 'react';
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  updateProfile,
} from 'firebase/auth';
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  Eye,
  EyeOff,
  Loader2,
  Mail,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react';
import { auth, firebaseProjectId } from '../lib/firebase';
import { useVault } from '../context/VaultContext';

function formatAuthError(err: unknown): { message: string; needsEmailProviderSetup?: boolean } {
  const code =
    typeof err === 'object' && err !== null && 'code' in err
      ? String((err as { code: string }).code)
      : '';
  const msg = err instanceof Error ? err.message : 'Authentication failed.';

  if (code === 'auth/operation-not-allowed') {
    return {
      message:
        'Email/Password sign-in is not yet enabled on this Firebase project. Enable it in Firebase Console or sign in with Google below.',
      needsEmailProviderSetup: true,
    };
  }
  if (code === 'auth/email-already-in-use') {
    return { message: 'An account with this email already exists. Please sign in instead.' };
  }
  if (code === 'auth/invalid-credential' || code === 'auth/wrong-password' || code === 'auth/user-not-found') {
    return { message: 'Invalid email or account password.' };
  }
  if (code === 'auth/weak-password') {
    return { message: 'Account password must be at least 8 characters.' };
  }
  if (code === 'auth/too-many-requests') {
    return { message: 'Too many attempts. Please wait a few minutes and try again.' };
  }
  if (code === 'auth/popup-closed-by-user') {
    return { message: 'Google sign-in popup was closed before completing authentication.' };
  }
  return { message: msg };
}

interface AuthPageProps {
  mode: 'login' | 'register';
  onSwitchMode: (mode: 'login' | 'register') => void;
  onBackHome: () => void;
}

export const AuthPage: React.FC<AuthPageProps> = ({ mode, onSwitchMode, onBackHome }) => {
  const { showToast } = useVault();
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [forgotMode, setForgotMode] = useState(false);
  const [resetSent, setResetSent] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [showProviderHelp, setShowProviderHelp] = useState(false);

  const resetFormState = () => {
    setErrorMsg(null);
    setShowProviderHelp(false);
    setResetSent(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    resetFormState();

    const cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      setErrorMsg('Please enter a valid email address.');
      return;
    }

    if (forgotMode) {
      setSubmitting(true);
      try {
        await sendPasswordResetEmail(auth, cleanEmail);
        setResetSent(true);
        showToast('Password reset link sent to your email.', 'success');
      } catch (err) {
        const formatted = formatAuthError(err);
        setErrorMsg(formatted.message);
        setShowProviderHelp(Boolean(formatted.needsEmailProviderSetup));
      } finally {
        setSubmitting(false);
      }
      return;
    }

    if (password.length < 8) {
      setErrorMsg('Account password must be at least 8 characters long.');
      return;
    }

    if (mode === 'register') {
      if (!displayName.trim()) {
        setErrorMsg('Please enter your name.');
        return;
      }
      if (password !== confirmPassword) {
        setErrorMsg('Account passwords do not match.');
        return;
      }
    }

    setSubmitting(true);
    try {
      if (mode === 'register') {
        const cred = await createUserWithEmailAndPassword(auth, cleanEmail, password);
        await updateProfile(cred.user, { displayName: displayName.trim() });
        await sendEmailVerification(cred.user);
        showToast('Account created. Please check your inbox to verify your email.', 'success');
      } else {
        await signInWithEmailAndPassword(auth, cleanEmail, password);
      }
    } catch (err) {
      const formatted = formatAuthError(err);
      setErrorMsg(formatted.message);
      setShowProviderHelp(Boolean(formatted.needsEmailProviderSetup));
    } finally {
      setSubmitting(false);
    }
  };

  const handleGoogleSignIn = async () => {
    resetFormState();
    setSubmitting(true);
    try {
      const provider = new GoogleAuthProvider();
      await signInWithPopup(auth, provider);
    } catch (err) {
      const formatted = formatAuthError(err);
      setErrorMsg(formatted.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex flex-col justify-center py-12 px-4 sm:px-6">
      <div className="max-w-md w-full mx-auto">
        <button
          type="button"
          onClick={onBackHome}
          className="inline-flex items-center gap-2 text-xs font-medium text-slate-400 hover:text-white mb-6 transition-colors cursor-pointer"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Back to VaultX Home</span>
        </button>

        <div className="bg-[#0D1220] border border-slate-800/90 rounded-2xl p-8">
          <div className="flex items-center gap-2.5 mb-2">
            <ShieldCheck className="w-5 h-5 text-indigo-400" />
            <span className="font-display text-lg font-bold text-white">VaultX</span>
          </div>

          <h1 className="font-display text-2xl font-bold text-white tracking-tight">
            {forgotMode
              ? 'Reset account password'
              : mode === 'register'
                ? 'Create your VaultX account'
                : 'Sign in to VaultX'}
          </h1>
          <p className="text-sm text-slate-400 mt-1.5 leading-relaxed">
            {forgotMode
              ? 'Enter your registered email to receive an account password reset link.'
              : mode === 'register'
                ? 'Step 1 of 3: Create your cloud account. You will set your separate Master Password after verifying your email.'
                : 'Authenticate to synchronize and unlock your encrypted cloud vault.'}
          </p>

          {errorMsg && (
            <div className="mt-5 p-3.5 rounded-lg bg-rose-950/40 border border-rose-500/40 text-xs text-rose-200 space-y-2">
              <div className="flex items-start gap-2">
                <AlertTriangle className="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
                <span>{errorMsg}</span>
              </div>
              {showProviderHelp && (
                <div className="pt-2 border-t border-rose-500/30 text-slate-300 space-y-1">
                  <p className="font-medium text-white">How to enable Email/Password Auth:</p>
                  <p>
                    1. Open Firebase Console for project <code className="text-indigo-300">{firebaseProjectId}</code>
                  </p>
                  <p>2. Go to Authentication → Sign-in method → Enable Email/Password.</p>
                </div>
              )}
            </div>
          )}

          {resetSent && forgotMode && (
            <div className="mt-5 p-3.5 rounded-lg bg-emerald-950/40 border border-emerald-500/40 text-xs text-emerald-200 flex items-start gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
              <span>
                Reset email dispatched if an account exists for <strong>{email}</strong>. Note: resetting your account password does not alter your Vault Master Password.
              </span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="mt-6 space-y-4">
            {mode === 'register' && !forgotMode && (
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Full Name
                </label>
                <input
                  type="text"
                  required
                  maxLength={100}
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="Alex Mercer"
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
              </div>
            )}

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">
                Email Address
              </label>
              <input
                type="email"
                required
                maxLength={254}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@domain.com"
                className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
            </div>

            {!forgotMode && (
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="block text-xs font-medium text-slate-300">
                    Account Login Password
                  </label>
                  {mode === 'login' && (
                    <button
                      type="button"
                      onClick={() => {
                        setForgotMode(true);
                        resetFormState();
                      }}
                      className="text-xs text-indigo-400 hover:text-indigo-300 cursor-pointer"
                    >
                      Forgot password?
                    </button>
                  )}
                </div>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    minLength={8}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Minimum 8 characters"
                    className="w-full px-3.5 py-2.5 pr-10 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
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
              </div>
            )}

            {mode === 'register' && !forgotMode && (
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">
                  Confirm Account Password
                </label>
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  minLength={8}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Re-enter account password"
                  className="w-full px-3.5 py-2.5 rounded-lg bg-[#080B14] border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
                <p className="text-xs text-slate-400 mt-2">
                  This password authenticates your Firebase account. Your encryption Master Password will be configured separately.
                </p>
              </div>
            )}

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-2.5 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white transition-colors flex items-center justify-center gap-2 cursor-pointer"
            >
              {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
              <span>
                {forgotMode
                  ? 'Send Reset Email'
                  : mode === 'register'
                    ? 'Create Account & Verify Email'
                    : 'Sign In'}
              </span>
            </button>
          </form>

          {!forgotMode && (
            <>
              <div className="my-5 flex items-center gap-3 text-xs text-slate-500">
                <div className="flex-1 h-px bg-slate-800" />
                <span>or continue with</span>
                <div className="flex-1 h-px bg-slate-800" />
              </div>

              <button
                type="button"
                disabled={submitting}
                onClick={handleGoogleSignIn}
                className="w-full py-2.5 px-4 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-sm font-medium text-slate-200 transition-colors flex items-center justify-center gap-2.5 cursor-pointer"
              >
                <svg className="w-4 h-4" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill="#EA4335"
                    d="M12 5.04c1.9 0 3.53.65 4.84 1.9l3.6-3.6C18.23 1.29 15.32 0 12 0 7.31 0 3.26 2.69 1.29 6.61l4.2 3.26C6.49 6.91 9.02 5.04 12 5.04z"
                  />
                  <path
                    fill="#4285F4"
                    d="M23.49 12.27c0-.79-.07-1.55-.2-2.27H12v4.51h6.47c-.28 1.48-1.12 2.74-2.38 3.58l3.67 2.85c2.15-1.98 3.73-4.9 3.73-8.67z"
                  />
                  <path
                    fill="#FBBC05"
                    d="M5.49 14.13c-.24-.7-.38-1.45-.38-2.23s.14-1.53.38-2.23L1.29 6.41A11.97 11.97 0 0 0 0 11.9c0 1.98.48 3.84 1.29 5.49l4.2-3.26z"
                  />
                  <path
                    fill="#34A853"
                    d="M12 24c3.24 0 5.96-1.07 7.95-2.91l-3.67-2.85c-1.07.72-2.45 1.15-4.28 1.15-2.98 0-5.51-1.87-6.51-4.83l-4.2 3.26C3.26 21.31 7.31 24 12 24z"
                  />
                </svg>
                <span>Continue with Google</span>
              </button>
            </>
          )}

          <div className="mt-6 pt-5 border-t border-slate-800/80 text-center text-xs text-slate-400">
            {forgotMode ? (
              <button
                type="button"
                onClick={() => {
                  setForgotMode(false);
                  resetFormState();
                }}
                className="text-indigo-400 hover:text-indigo-300 font-medium cursor-pointer"
              >
                Return to Sign In
              </button>
            ) : mode === 'register' ? (
              <span>
                Already have a VaultX account?{' '}
                <button
                  type="button"
                  onClick={() => {
                    onSwitchMode('login');
                    resetFormState();
                  }}
                  className="text-indigo-400 hover:text-indigo-300 font-medium cursor-pointer"
                >
                  Sign In
                </button>
              </span>
            ) : (
              <span>
                New to VaultX?{' '}
                <button
                  type="button"
                  onClick={() => {
                    onSwitchMode('register');
                    resetFormState();
                  }}
                  className="text-indigo-400 hover:text-indigo-300 font-medium cursor-pointer"
                >
                  Create an account
                </button>
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export const EmailVerificationPage: React.FC = () => {
  const { authUser, refreshUserState, logout, showToast } = useVault();
  const [sending, setSending] = useState(false);
  const [checking, setChecking] = useState(false);
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown <= 0) return;
    const t = window.setInterval(() => setCooldown((c) => Math.max(0, c - 1)), 1000);
    return () => window.clearInterval(t);
  }, [cooldown]);

  const handleResend = async () => {
    if (!auth.currentUser || cooldown > 0) return;
    setSending(true);
    try {
      await sendEmailVerification(auth.currentUser);
      setCooldown(60);
      showToast('Verification email resent. Check your inbox and spam folder.', 'success');
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Unable to send verification email.';
      showToast(msg, 'error');
    } finally {
      setSending(false);
    }
  };

  const handleCheckStatus = async () => {
    setChecking(true);
    try {
      await refreshUserState();
      if (!auth.currentUser?.emailVerified) {
        showToast('Email is not verified yet. Please click the link sent to your inbox.', 'info');
      } else {
        showToast('Email verified! Proceeding to Master Password setup.', 'success');
      }
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex items-center justify-center px-4 py-12">
      <div className="max-w-md w-full bg-[#0D1220] border border-slate-800/90 rounded-2xl p-8">
        <div className="w-12 h-12 rounded-xl bg-indigo-500/15 border border-indigo-500/30 flex items-center justify-center mb-5">
          <Mail className="w-6 h-6 text-indigo-400" />
        </div>

        <h1 className="font-display text-2xl font-bold text-white tracking-tight">
          Verify your email address
        </h1>
        <p className="text-sm text-slate-300 mt-2 leading-relaxed">
          VaultX enforces verified email ownership before initializing encrypted cloud storage. We sent a verification link to{' '}
          <strong className="text-white">{authUser?.email}</strong>.
        </p>

        <div className="mt-6 space-y-3">
          <button
            type="button"
            disabled={checking}
            onClick={handleCheckStatus}
            className="w-full py-2.5 px-4 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 text-sm font-semibold text-white transition-colors flex items-center justify-center gap-2 cursor-pointer"
          >
            {checking ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <RefreshCw className="w-4 h-4" />
            )}
            <span>I&apos;ve Verified My Email</span>
          </button>

          <button
            type="button"
            disabled={sending || cooldown > 0}
            onClick={handleResend}
            className="w-full py-2.5 px-4 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 disabled:opacity-60 text-sm font-medium text-slate-200 transition-colors cursor-pointer"
          >
            {cooldown > 0
              ? `Resend Verification Email (${cooldown}s)`
              : sending
                ? 'Sending...'
                : 'Resend Verification Email'}
          </button>
        </div>

        <div className="mt-6 pt-5 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
          <span>Wrong account?</span>
          <button
            type="button"
            onClick={logout}
            className="text-slate-300 hover:text-white font-medium cursor-pointer"
          >
            Sign Out
          </button>
        </div>
      </div>
    </div>
  );
};
