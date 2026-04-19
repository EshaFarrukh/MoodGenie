import type { ReactNode } from 'react';
import { Inbox } from 'lucide-react';
import { cn } from '@/lib/utils';

export function EmptyState({
  title,
  description,
  action,
  className,
}: {
  title: string;
  description: string;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'flex min-h-36 flex-col items-center justify-center rounded-[22px] border border-dashed border-[var(--mg-border-strong)] bg-[var(--mg-surface-subtle)] px-6 py-7 text-center',
        className,
      )}
    >
      <div className="mb-3.5 rounded-2xl bg-white p-3 text-[var(--mg-primary)] shadow-[var(--mg-shadow-sm)]">
        <Inbox className="h-6 w-6" />
      </div>
      <h3 className="text-lg font-semibold tracking-[-0.03em] text-[var(--mg-heading)]">
        {title}
      </h3>
      <p className="mt-2 max-w-md text-sm leading-5 text-[var(--mg-muted)]">
        {description}
      </p>
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  );
}
