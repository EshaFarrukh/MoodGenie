'use client';

import type { ReactNode } from 'react';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';

type DialogProps = {
  open: boolean;
  title: string;
  description?: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  size?: 'md' | 'lg' | 'xl';
};

const sizeClasses = {
  md: 'max-w-xl',
  lg: 'max-w-3xl',
  xl: 'max-w-5xl',
};

export function Dialog({
  open,
  title,
  description,
  onClose,
  children,
  footer,
  size = 'lg',
}: DialogProps) {
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[rgba(0,43,91,0.42)] px-4 py-8 backdrop-blur-sm">
      <div
        className={cn(
          'relative max-h-[90vh] w-full overflow-hidden rounded-[32px] border border-white/50 bg-[rgba(252,254,255,0.98)] shadow-[0_28px_80px_rgba(0,59,115,0.18)]',
          sizeClasses[size],
        )}
      >
        <div className="flex items-start justify-between gap-4 border-b border-[var(--mg-border)] px-6 py-5">
          <div>
            <h2 className="text-xl font-semibold tracking-[-0.04em] text-[var(--mg-heading)]">
              {title}
            </h2>
            {description ? (
              <p className="mt-1 text-sm leading-6 text-[var(--mg-muted)]">
                {description}
              </p>
            ) : null}
          </div>
          <Button
            type="button"
            size="icon"
            variant="ghost"
            onClick={onClose}
            aria-label="Close dialog"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
        <div className="max-h-[calc(90vh-9rem)] overflow-y-auto px-6 py-6">{children}</div>
        {footer ? (
          <div className="border-t border-[var(--mg-border)] px-6 py-4">{footer}</div>
        ) : null}
      </div>
    </div>
  );
}
