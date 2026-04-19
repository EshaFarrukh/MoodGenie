import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

export type DetailInfoItem = {
  label: string;
  value: ReactNode;
  helper?: ReactNode;
};

export function DetailInfoGrid({
  items,
  columns = 2,
  className,
}: {
  items: DetailInfoItem[];
  columns?: 1 | 2 | 3;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'grid gap-3',
        columns === 1
          ? 'grid-cols-1'
          : columns === 3
          ? 'grid-cols-1 md:grid-cols-2 xl:grid-cols-3'
          : 'grid-cols-1 md:grid-cols-2',
        className,
      )}
    >
      {items.map((item) => (
        <div
          key={item.label}
          className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4"
        >
          <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            {item.label}
          </div>
          <div className="mt-2 text-sm font-semibold leading-6 text-[var(--mg-heading)]">
            {item.value}
          </div>
          {item.helper ? (
            <div className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
              {item.helper}
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}
