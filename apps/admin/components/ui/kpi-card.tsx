import { ArrowDownRight, ArrowUpRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { cn, formatNumber } from '@/lib/utils';

export function KpiCard({
  label,
  value,
  helper,
  trendLabel,
  trendDirection = 'up',
}: {
  label: string;
  value: number | string;
  helper: string;
  trendLabel?: string;
  trendDirection?: 'up' | 'down' | 'flat';
}) {
  return (
    <Card className="h-full overflow-hidden">
      <CardContent className="flex h-full flex-col px-4.5 pb-4.5 pt-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--mg-muted)]">
              {label}
            </div>
            <div className="mt-1.5 text-[1.82rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
              {typeof value === 'number' ? formatNumber(value) : value}
            </div>
          </div>
          <div className="rounded-full bg-[var(--mg-primary-soft)] px-2.5 py-1.5 text-[10px] font-semibold uppercase tracking-[0.14em] text-[var(--mg-primary-strong)]">
            Live
          </div>
        </div>
        <p className="mt-2.5 text-sm leading-5 text-[var(--mg-muted)] text-trim-2">{helper}</p>
        {trendLabel ? (
          <div
            className={cn(
              'mt-3.5 inline-flex items-center gap-2 self-start rounded-full px-3 py-1.5 text-xs font-semibold',
              trendDirection === 'down'
                ? 'bg-[rgba(226,83,74,0.12)] text-[var(--mg-danger)]'
                : trendDirection === 'flat'
                ? 'bg-[var(--mg-surface-muted)] text-[var(--mg-muted)]'
                : 'bg-[rgba(48,163,115,0.12)] text-[var(--mg-success)]',
            )}
          >
            {trendDirection === 'down' ? (
              <ArrowDownRight className="h-3.5 w-3.5" />
            ) : (
              <ArrowUpRight className="h-3.5 w-3.5" />
            )}
            {trendLabel}
          </div>
        ) : <div className="mt-3.5 h-[30px]" />}
      </CardContent>
    </Card>
  );
}
