import React, { Component, useMemo, useState, type ErrorInfo, type ReactNode } from 'react';
import { Loader2, ShieldAlert } from 'lucide-react';
import { VaultProvider, useVault } from './context/VaultContext';
import { ToastContainer } from './components/ToastContainer';
import { LandingPage } from './components/LandingPage';
import { AuthPage, EmailVerificationPage } from './components/AuthPages';
import {
  MasterPasswordSetupPage,
  RecoveryKeyCeremonyPage,
} from './components/MasterPasswordSetupPage';
import { VaultUnlockPage } from './components/VaultUnlockPage';
import { WorkspaceShell } from './components/WorkspaceShell';
import { DashboardView } from './components/DashboardView';
import { VaultListView } from './components/VaultListView';
import { PasswordGeneratorView } from './components/PasswordGeneratorView';
import { SecurityCenterView } from './components/SecurityCenterView';
import { SettingsAndRecoveryView } from './components/SettingsAndRecoveryView';
import { CredentialModal } from './components/CredentialModal';
import type { AppView, DecryptedCredential } from './types/vault';

class AppErrorBoundary extends Component<
  { children: ReactNode },
  { hasError: boolean; message: string }
> {
  constructor(props: { children: ReactNode }) {
    super(props);
    this.state = { hasError: false, message: '' };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, message: error.message || 'An unexpected error occurred.' };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('VaultX Error Boundary:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#080B14] text-slate-100 flex items-center justify-center p-6">
          <div className="max-w-md w-full bg-[#0D1220] border border-rose-500/40 rounded-2xl p-8 space-y-4">
            <ShieldAlert className="w-8 h-8 text-rose-400" />
            <h1 className="font-display text-xl font-bold text-white">
              Vault Session Interrupted
            </h1>
            <p className="text-sm text-slate-300 leading-relaxed break-words">
              {this.state.message}
            </p>
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-sm font-semibold text-white cursor-pointer"
            >
              Reload Application
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

const VaultXRouter: React.FC = () => {
  const {
    authUser,
    authReady,
    vaultDataLoading,
    isVaultInitialized,
    isVaultUnlocked,
    pendingRecoveryCeremonyKey,
    decryptedCredentials,
  } = useVault();

  const [publicRoute, setPublicRoute] = useState<'landing' | 'login' | 'register'>('landing');
  const [activeView, setActiveView] = useState<AppView>('dashboard');
  const [modalOpen, setModalOpen] = useState(false);
  const [editingCredential, setEditingCredential] = useState<DecryptedCredential | null>(null);
  const [prefilledPassword, setPrefilledPassword] = useState('');

  const existingCategories = useMemo(
    () =>
      Array.from(
        new Set(decryptedCredentials.map((c) => c.category).filter(Boolean))
      ),
    [decryptedCredentials]
  );

  const openAddModal = (initialPassword = '') => {
    setEditingCredential(null);
    setPrefilledPassword(initialPassword);
    setModalOpen(true);
  };

  const openEditModal = (cred: DecryptedCredential) => {
    setEditingCredential(cred);
    setPrefilledPassword('');
    setModalOpen(true);
  };

  if (!authReady || (authUser?.emailVerified && vaultDataLoading)) {
    return (
      <div className="min-h-screen bg-[#080B14] text-slate-100 flex flex-col items-center justify-center gap-3">
        <Loader2 className="w-7 h-7 text-indigo-400 animate-spin" />
        <p className="text-sm text-slate-400">Synchronizing encrypted vault state...</p>
      </div>
    );
  }

  // 1. Unauthenticated routes
  if (!authUser) {
    if (publicRoute === 'login') {
      return (
        <AuthPage
          mode="login"
          onSwitchMode={(m) => setPublicRoute(m)}
          onBackHome={() => setPublicRoute('landing')}
        />
      );
    }
    if (publicRoute === 'register') {
      return (
        <AuthPage
          mode="register"
          onSwitchMode={(m) => setPublicRoute(m)}
          onBackHome={() => setPublicRoute('landing')}
        />
      );
    }
    return <LandingPage onNavigate={(r) => setPublicRoute(r)} />;
  }

  // 2. Email verification gate
  if (!authUser.emailVerified) {
    return <EmailVerificationPage />;
  }

  // 3. One-time Recovery Key ceremony immediately after initial vault creation
  if (pendingRecoveryCeremonyKey) {
    return <RecoveryKeyCeremonyPage />;
  }

  // 4. Master password setup gate for new verified accounts
  if (!isVaultInitialized) {
    return <MasterPasswordSetupPage />;
  }

  // 5. Vault unlock / recovery gate when locked in memory
  if (!isVaultUnlocked) {
    return <VaultUnlockPage />;
  }

  // 6. Unlocked encrypted workspace
  return (
    <>
      <WorkspaceShell
        activeView={activeView}
        onChangeView={setActiveView}
        onAddCredential={() => openAddModal()}
      >
        {activeView === 'dashboard' && (
          <DashboardView
            onAddCredential={() => openAddModal()}
            onEditCredential={openEditModal}
            onNavigateView={setActiveView}
          />
        )}
        {activeView === 'vault' && (
          <VaultListView
            initialViewMode="vault"
            onAddCredential={() => openAddModal()}
            onEditCredential={openEditModal}
          />
        )}
        {activeView === 'categories' && (
          <VaultListView
            initialViewMode="categories"
            onAddCredential={() => openAddModal()}
            onEditCredential={openEditModal}
          />
        )}
        {activeView === 'generator' && (
          <PasswordGeneratorView
            onSaveToVault={(pw) => openAddModal(pw)}
          />
        )}
        {activeView === 'security' && (
          <SecurityCenterView onFixCredential={openEditModal} />
        )}
        {activeView === 'recovery' && (
          <SettingsAndRecoveryView key="recovery-tab" initialTab="recovery" />
        )}
        {activeView === 'settings' && (
          <SettingsAndRecoveryView key="general-tab" initialTab="general" />
        )}
      </WorkspaceShell>

      <CredentialModal
        isOpen={modalOpen}
        editingCredential={editingCredential}
        initialPassword={prefilledPassword}
        existingCategories={existingCategories}
        onClose={() => {
          setModalOpen(false);
          setEditingCredential(null);
          setPrefilledPassword('');
        }}
      />
    </>
  );
};

export default function App() {
  return (
    <AppErrorBoundary>
      <VaultProvider>
        <VaultXRouter />
        <ToastContainer />
      </VaultProvider>
    </AppErrorBoundary>
  );
}
