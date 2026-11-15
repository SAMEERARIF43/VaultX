import React, { useState } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  FolderKanban,
  KeyRound,
  LayoutDashboard,
  Lock,
  LogOut,
  Menu,
  Settings,
  ShieldAlert,
  ShieldCheck,
  Sparkles,
  Vault,
  X,
} from 'lucide-react';
import { useVault } from '../context/VaultContext';
import type { AppView } from '../types/vault';

interface WorkspaceShellProps {
  activeView: AppView;
  onChangeView: (view: AppView) => void;
  onAddCredential: () => void;
  children: React.ReactNode;
}

export const WorkspaceShell: React.FC<WorkspaceShellProps> = ({
  activeView,
  onChangeView,
  children,
}) => {
  const {
    authUser,
    userProfile,
    clipboardSecondsLeft,
    lastCopiedLabel,
    lockVault,
    logout,
  } = useVault();

  const [collapsed, setCollapsed] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const navItems: { id: AppView; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'vault', label: 'My Vault', icon: Vault },
    { id: 'generator', label: 'Password Generator', icon: Sparkles },
    { id: 'security', label: 'Security Center', icon: ShieldAlert },
    { id: 'categories', label: 'Categories', icon: FolderKanban },
    { id: 'recovery', label: 'Recovery Key', icon: KeyRound },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  const handleNavClick = (id: AppView) => {
    onChangeView(id);
    setMobileMenuOpen(false);
  };

  return (
    <div className="min-h-screen bg-[#080B14] text-slate-100 flex">
      {/* Desktop Collapsible Sidebar */}
      <aside
        className={`hidden md:flex flex-col border-r border-slate-800/80 bg-[#0B0F1B] transition-[width] duration-200 shrink-0 ${
          collapsed ? 'w-20' : 'w-64'
        }`}
      >
        <div className="h-16 px-4 flex items-center justify-between border-b border-slate-800/80">
          <div className="flex items-center gap-2.5 min-w-0">
            <ShieldCheck className="w-5 h-5 text-indigo-400 shrink-0" />
            {!collapsed && (
              <span className="font-display text-lg font-bold text-white tracking-tight truncate">
                VaultX
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={() => setCollapsed((c) => !c)}
            aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/70 transition-colors cursor-pointer"
          >
            {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
          </button>
        </div>

        <nav className="flex-1 p-3 space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = activeView === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => handleNavClick(item.id)}
                title={collapsed ? item.label : undefined}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors cursor-pointer ${
                  active
                    ? 'bg-indigo-600/20 text-white border border-indigo-500/30'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/50 border border-transparent'
                }`}
              >
                <Icon className={`w-4 h-4 shrink-0 ${active ? 'text-indigo-400' : ''}`} />
                {!collapsed && <span className="truncate">{item.label}</span>}
              </button>
            );
          })}
        </nav>

        <div className="p-3 border-t border-slate-800/80 space-y-1">
          <button
            type="button"
            onClick={() => lockVault('Vault locked manually.')}
            title={collapsed ? 'Lock Vault' : undefined}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-300 hover:text-white hover:bg-slate-800/60 transition-colors cursor-pointer"
          >
            <Lock className="w-4 h-4 shrink-0 text-amber-400" />
            {!collapsed && <span className="truncate">Lock Vault</span>}
          </button>

          <button
            type="button"
            onClick={logout}
            title={collapsed ? 'Logout' : undefined}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-400 hover:text-rose-300 hover:bg-rose-950/30 transition-colors cursor-pointer"
          >
            <LogOut className="w-4 h-4 shrink-0" />
            {!collapsed && <span className="truncate">Logout</span>}
          </button>
        </div>
      </aside>

      {/* Mobile Slide-Over Drawer */}
      {mobileMenuOpen && (
        <div className="fixed inset-0 z-50 md:hidden flex">
          <div
            className="fixed inset-0 bg-black/70"
            onClick={() => setMobileMenuOpen(false)}
          />
          <aside className="relative w-72 max-w-[80vw] bg-[#0B0F1B] border-r border-slate-800 flex flex-col z-10">
            <div className="h-16 px-4 flex items-center justify-between border-b border-slate-800">
              <div className="flex items-center gap-2.5">
                <ShieldCheck className="w-5 h-5 text-indigo-400" />
                <span className="font-display text-lg font-bold text-white">VaultX</span>
              </div>
              <button
                type="button"
                onClick={() => setMobileMenuOpen(false)}
                aria-label="Close navigation"
                className="p-1.5 text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <nav className="flex-1 p-3 space-y-1">
              {navItems.map((item) => {
                const Icon = item.icon;
                const active = activeView === item.id;
                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => handleNavClick(item.id)}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium ${
                      active
                        ? 'bg-indigo-600/20 text-white border border-indigo-500/30'
                        : 'text-slate-400 hover:text-white'
                    }`}
                  >
                    <Icon className="w-4 h-4 shrink-0" />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </nav>
            <div className="p-3 border-t border-slate-800 space-y-1">
              <button
                type="button"
                onClick={() => {
                  setMobileMenuOpen(false);
                  lockVault('Vault locked manually.');
                }}
                className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-300"
              >
                <Lock className="w-4 h-4 text-amber-400" />
                <span>Lock Vault</span>
              </button>
              <button
                type="button"
                onClick={logout}
                className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-400"
              >
                <LogOut className="w-4 h-4" />
                <span>Logout</span>
              </button>
            </div>
          </aside>
        </div>
      )}

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 px-4 sm:px-8 border-b border-slate-800/80 bg-[#080B14]/90 backdrop-blur-md flex items-center justify-between gap-4 sticky top-0 z-20">
          <div className="flex items-center gap-3 min-w-0">
            <button
              type="button"
              onClick={() => setMobileMenuOpen(true)}
              aria-label="Open navigation menu"
              className="md:hidden p-2 rounded-lg text-slate-300 hover:bg-slate-800/60"
            >
              <Menu className="w-5 h-5" />
            </button>
            <div className="text-xs sm:text-sm text-slate-400 truncate">
              <span>VaultX</span>
              <span className="mx-2" aria-hidden="true">/</span>
              <span className="text-slate-200 font-medium capitalize">
                {navItems.find((n) => n.id === activeView)?.label || activeView}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-4 shrink-0">
            {clipboardSecondsLeft > 0 && (
              <div className="hidden sm:flex items-center gap-2 text-xs text-amber-300 tabular-nums">
                <span>
                  Clipboard ({lastCopiedLabel}) clears in {clipboardSecondsLeft}s
                </span>
              </div>
            )}

            <div className="hidden sm:block text-right">
              <div className="text-xs font-medium text-slate-200 truncate max-w-[180px]">
                {userProfile?.displayName || authUser?.email}
              </div>
              <div className="text-[11px] text-slate-500 truncate max-w-[180px]">
                {authUser?.email}
              </div>
            </div>

            <button
              type="button"
              onClick={() => lockVault('Vault locked manually.')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[#101626] hover:bg-[#161F36] border border-slate-700/80 text-xs font-medium text-slate-200 transition-colors cursor-pointer"
            >
              <Lock className="w-3.5 h-3.5 text-amber-400" />
              <span>Lock</span>
            </button>
          </div>
        </header>

        <main className="flex-1 p-4 sm:p-8 max-w-7xl w-full mx-auto">
          {children}
        </main>
      </div>
    </div>
  );
};
