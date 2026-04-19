import { cn } from '@/lib/utils';

const tones = {
  success: 'bg-[rgba(48,163,115,0.12)] text-[var(--mg-success)]',
  warning: 'bg-[rgba(245,158,11,0.14)] text-[var(--mg-warning)]',
  danger: 'bg-[rgba(226,83,74,0.12)] text-[var(--mg-danger)]',
  info: 'bg-[var(--mg-primary-soft)] text-[var(--mg-primary-strong)]',
  neutral: 'bg-[var(--mg-surface-muted)] text-[var(--mg-muted)]',
};

export function getStatusTone(status: string) {
  const normalized = status.trim().toLowerCase();
  if (
    ['approved', 'active', 'completed', 'healthy', 'resolved', 'enabled', 'verified'].includes(
      normalized,
    )
  ) {
    return 'success';
  }
  if (
    ['rejected', 'suspended', 'failed', 'cancelled', 'critical', 'high', 'disabled'].includes(
      normalized,
    )
  ) {
    return 'danger';
  }
  if (
    ['pending', 'requested', 'open', 'warning', 'in_progress', 'awaiting_review'].includes(
      normalized,
    )
  ) {
    return 'warning';
  }
  if (['info', 'reviewed', 'acknowledged', 'medium', 'confirmed'].includes(normalized)) {
    return 'info';
  }
  return 'neutral';
}

export function StatusBadge({
  status,
  className,
}: {
  status: string;
  className?: string;
}) {
  const normalized = status.trim().toLowerCase();
  const tone = getStatusTone(normalized);

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em]',
        tones[tone],
        className,
      )}
    >
      {normalized.replace(/_/g, ' ')}
    </span>
  );
}
