import React from 'react';
import { CheckCircle2, AlertCircle, Info, X } from 'lucide-react';
import { useVault } from '../context/VaultContext';

export const ToastContainer: React.FC = () => {
  const { toasts, dismissToast } = useVault();

  if (toasts.length === 0) return null;

  return (
    <div
      aria-live="polite"
      className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-[calc(100%-2rem)]"
    >
      {toasts.map((toast) => {
        const Icon =
          toast.type === 'success'
            ? CheckCircle2
            : toast.type === 'error'
              ? AlertCircle
              : Info;
        const borderClass =
          toast.type === 'success'
            ? 'border-emerald-500/40 bg-[#0D161A]'
            : toast.type === 'error'
              ? 'border-rose-500/40 bg-[#180E14]'
              : 'border-indigo-500/40 bg-[#0D1326]';
        const iconColor =
          toast.type === 'success'
            ? 'text-emerald-400'
            : toast.type === 'error'
              ? 'text-rose-400'
              : 'text-indigo-400';

        return (
          <div
            key={toast.id}
            className={`flex items-start gap-3 px-4 py-3 rounded-xl border shadow-xl text-sm text-slate-100 ${borderClass}`}
          >
            <Icon className={`w-4 h-4 mt-0.5 shrink-0 ${iconColor}`} />
            <p className="flex-1 leading-snug">{toast.text}</p>
            <button
              type="button"
              onClick={() => dismissToast(toast.id)}
              aria-label="Dismiss notification"
              className="text-slate-400 hover:text-slate-200 transition-colors p-0.5"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        );
      })}
    </div>
  );
};
