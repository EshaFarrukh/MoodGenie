import type { ButtonHTMLAttributes, PropsWithChildren } from 'react';
import { cn } from '@/lib/utils';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'outline';
type ButtonSize = 'sm' | 'md' | 'lg' | 'icon';

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    'bg-[var(--mg-primary)] text-white shadow-[0_14px_30px_rgba(19,87,171,0.22)] hover:bg-[var(--mg-primary-strong)]',
  secondary:
    'bg-[var(--mg-primary-soft)] text-[var(--mg-primary-strong)] hover:bg-[rgba(27,116,216,0.16)]',
  ghost:
    'bg-transparent text-[var(--mg-text)] hover:bg-[var(--mg-surface-muted)]',
  danger:
    'bg-[rgba(226,83,74,0.12)] text-[var(--mg-danger)] hover:bg-[rgba(226,83,74,0.18)]',
  outline:
    'border border-[var(--mg-border-strong)] bg-[rgba(255,255,255,0.96)] text-[var(--mg-text)] hover:bg-[var(--mg-surface-subtle)]',
};

const sizeClasses: Record<ButtonSize, string> = {
  sm: 'h-[2.125rem] px-3 text-sm',
  md: 'h-10 px-4 text-sm',
  lg: 'h-11 px-5 text-sm',
  icon: 'h-9 w-9 justify-center',
};

export function buttonStyles({
  variant = 'primary',
  size = 'md',
  className,
}: {
  variant?: ButtonVariant;
  size?: ButtonSize;
  className?: string;
}) {
  return cn(
    'inline-flex items-center gap-2 rounded-[18px] font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--mg-primary)]/30 disabled:pointer-events-none disabled:opacity-50',
    variantClasses[variant],
    sizeClasses[size],
    className,
  );
}

export type ButtonProps = PropsWithChildren<
  ButtonHTMLAttributes<HTMLButtonElement> & {
    variant?: ButtonVariant;
    size?: ButtonSize;
  }
>;

export function Button({
  className,
  variant = 'primary',
  size = 'md',
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={buttonStyles({ variant, size, className })}
      {...props}
    >
      {children}
    </button>
  );
}
