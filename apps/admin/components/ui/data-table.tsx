import type { PropsWithChildren, ReactNode } from 'react';
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function DataTable({
  title,
  description,
  toolbar,
  children,
  className,
}: PropsWithChildren<{
  title?: string;
  description?: string;
  toolbar?: ReactNode;
  className?: string;
}>) {
  return (
    <Card className={cn('overflow-hidden', className)}>
      {(title || description || toolbar) ? (
        <div className="flex flex-col gap-3.5 border-b border-[var(--mg-border)] px-5 py-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="min-w-0">
            {title ? (
              <h3 className="text-[1.02rem] font-semibold tracking-[-0.03em] text-[var(--mg-heading)]">
                {title}
              </h3>
            ) : null}
            {description ? (
              <p className="mt-1 text-sm leading-5 text-[var(--mg-muted)]">
                {description}
              </p>
            ) : null}
          </div>
          {toolbar ? <div className="flex flex-wrap items-center gap-2.5">{toolbar}</div> : null}
        </div>
      ) : null}
      <div className="overflow-x-auto">{children}</div>
    </Card>
  );
}
