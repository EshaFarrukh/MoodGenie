'use client';

import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useMemo,
  useState,
} from 'react';
import { CheckCircle2, CircleAlert, X } from 'lucide-react';
import { cn } from '@/lib/utils';

type Toast = {
  id: string;
  title: string;
  description?: string;
  tone?: 'success' | 'error' | 'info';
};

type ToastContextValue = {
  pushToast: (toast: Omit<Toast, 'id'>) => void;
};

const ToastContext = createContext<ToastContextValue | null>(null);

export function ToastProvider({ children }: PropsWithChildren) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const pushToast = useCallback((toast: Omit<Toast, 'id'>) => {
    const id = crypto.randomUUID();
    setToasts((current) => [...current, { ...toast, id }]);
    window.setTimeout(() => {
      setToasts((current) => current.filter((entry) => entry.id !== id));
    }, 3400);
  }, []);

  const dismiss = useCallback((id: string) => {
    setToasts((current) => current.filter((entry) => entry.id !== id));
  }, []);

  const value = useMemo(() => ({ pushToast }), [pushToast]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="pointer-events-none fixed right-4 top-4 z-[70] flex w-full max-w-sm flex-col gap-3">
        {toasts.map((toast) => {
          const tone = toast.tone || 'info';
          return (
            <div
              key={toast.id}
              className={cn(
                'pointer-events-auto rounded-3xl border bg-white px-4 py-4 shadow-[0_20px_50px_rgba(0,59,115,0.14)]',
                tone === 'success'
                  ? 'border-[rgba(48,163,115,0.22)]'
                  : tone === 'error'
                  ? 'border-[rgba(226,83,74,0.22)]'
                  : 'border-[rgba(27,116,216,0.18)]',
              )}
            >
              <div className="flex items-start gap-3">
                <div
                  className={cn(
                    'mt-0.5 rounded-2xl p-2',
                    tone === 'success'
                      ? 'bg-[rgba(48,163,115,0.12)] text-[var(--mg-success)]'
                      : tone === 'error'
                      ? 'bg-[rgba(226,83,74,0.12)] text-[var(--mg-danger)]'
                      : 'bg-[var(--mg-primary-soft)] text-[var(--mg-primary)]',
                  )}
                >
                  {tone === 'success' ? (
                    <CheckCircle2 className="h-4 w-4" />
                  ) : (
                    <CircleAlert className="h-4 w-4" />
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-semibold text-[var(--mg-heading)]">
                    {toast.title}
                  </div>
                  {toast.description ? (
                    <div className="mt-1 text-sm text-[var(--mg-muted)]">
                      {toast.description}
                    </div>
                  ) : null}
                </div>
                <button
                  type="button"
                  className="rounded-full p-1 text-[var(--mg-muted)] transition hover:bg-[var(--mg-surface-muted)]"
                  onClick={() => dismiss(toast.id)}
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
}
