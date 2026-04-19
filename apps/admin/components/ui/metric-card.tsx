import { Card, CardContent } from '@/components/ui/card';

type MetricCardProps = {
  label: string;
  value: number | string;
  caption: string;
};

export function MetricCard({ label, value, caption }: MetricCardProps) {
  return (
    <Card className="h-full overflow-hidden">
      <CardContent className="p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
          {label}
        </p>
        <p className="mt-2 text-[1.8rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
          {value}
        </p>
        <p className="mt-1.5 text-sm leading-5 text-[var(--mg-muted)] text-trim-2">{caption}</p>
      </CardContent>
    </Card>
  );
}
