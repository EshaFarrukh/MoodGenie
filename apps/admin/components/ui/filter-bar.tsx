import type { PropsWithChildren, ReactNode } from 'react';
import { Card } from '@/components/ui/card';

export function FilterBar({
  children,
  actions,
}: PropsWithChildren<{ actions?: ReactNode }>) {
  return (
    <Card className="border-[var(--mg-border)] bg-[rgba(255,255,255,0.94)] shadow-[var(--mg-shadow-sm)]">
      <div className="flex flex-col gap-3.5 px-4 py-4 xl:flex-row xl:items-end xl:justify-between">
        <div className="grid flex-1 gap-3 [grid-template-columns:repeat(auto-fit,minmax(180px,1fr))]">
          {children}
        </div>
        {actions ? <div className="flex flex-wrap items-center gap-2.5">{actions}</div> : null}
      </div>
    </Card>
  );
}
