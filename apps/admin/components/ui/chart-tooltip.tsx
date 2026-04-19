import type { NameType, ValueType } from 'recharts/types/component/DefaultTooltipContent';

type ChartTooltipEntry = {
  name?: NameType;
  value?: ValueType;
  color?: string;
  dataKey?: string | number;
  payload?: {
    fill?: string;
  };
};

type AdminChartTooltipProps = {
  active?: boolean;
  payload?: ChartTooltipEntry[];
  label?: string | number;
};

function formatTooltipValue(value: ValueType) {
  if (typeof value === 'number') {
    return new Intl.NumberFormat('en-US').format(value);
  }
  return value;
}

export function AdminChartTooltip({
  active,
  payload,
  label,
}: AdminChartTooltipProps) {
  if (!active || !payload || payload.length === 0) {
    return null;
  }

  return (
    <div className="min-w-[176px] rounded-[18px] border border-[var(--mg-border)] bg-[rgba(255,255,255,0.97)] px-3.5 py-3 shadow-[0_18px_38px_rgba(16,63,115,0.12)] backdrop-blur-sm">
      {label ? (
        <div className="mb-2 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
          {String(label)}
        </div>
      ) : null}
      <div className="space-y-2">
        {payload.map((entry) => (
          <div
            key={`${entry.name}-${entry.dataKey}`}
            className="flex items-center justify-between gap-3"
          >
            <div className="flex min-w-0 items-center gap-2.5">
              <span
                className="h-2.5 w-2.5 rounded-full"
                style={{
                  backgroundColor:
                    entry.color || entry.payload?.fill || 'var(--mg-primary)',
                }}
              />
              <span className="truncate text-sm text-[var(--mg-text)]">
                {String(entry.name)}
              </span>
            </div>
            <span className="text-sm font-semibold text-[var(--mg-heading)]">
              {entry.value == null ? '—' : formatTooltipValue(entry.value)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
