'use client';

import Link from 'next/link';
import { useMemo } from 'react';
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import type { FeatureFlag, NotificationHealthSummary, SystemHealthSnapshot } from '@/lib/types';
import { buildNotificationDeliverySeries } from '@/lib/admin-portal';
import { Button, buttonStyles } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { AdminChartTooltip } from '@/components/ui/chart-tooltip';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { MetricChartCard } from '@/components/ui/metric-chart-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { useToast } from '@/components/ui/toast-provider';
import { formatPercent, truncateChartLabel } from '@/lib/utils';

type NotificationsWorkspaceProps = {
  summary: NotificationHealthSummary;
  flags: FeatureFlag[];
  health: SystemHealthSnapshot;
};

const CHANNEL_HEALTH = [
  {
    label: 'Push channel',
    helper: 'Operational, therapist, and reminder traffic across mobile clients.',
    metricKey: 'push',
  },
  {
    label: 'In-app inbox',
    helper: 'Persistent notification center state and unread badge health.',
    metricKey: 'inApp',
  },
  {
    label: 'Wellness cadence',
    helper: 'Daily reminder readiness with muted cohorts and fatigue controls.',
    metricKey: 'wellness',
  },
] as const;

export function NotificationsWorkspace({
  summary,
  flags,
  health,
}: NotificationsWorkspaceProps) {
  const { pushToast } = useToast();
  const deliveryBreakdown = useMemo(
    () => buildNotificationDeliverySeries(summary),
    [summary],
  );
  const topFailingTypes = useMemo(() => {
    if (summary.topFailingTypes.length > 0) {
      return summary.topFailingTypes.map((entry, index) => ({
        name: entry.type.replace(/_/g, ' '),
        value: entry.count,
        fill: ['#0066CC', '#00B4D8', '#EF4444', '#003B73', '#75B8FF'][index % 5],
      }));
    }
    return [
      { name: 'No current failures', value: 1, fill: '#DCEEFF' },
    ];
  }, [summary.topFailingTypes]);

  const channelCards = CHANNEL_HEALTH.map((channel) => {
    if (channel.metricKey === 'push') {
      return {
        ...channel,
        tone: summary.pushFailures > 0 ? 'warning' : 'active',
        value: summary.pushFailures,
        unit: 'failures',
      };
    }
    if (channel.metricKey === 'inApp') {
      return {
        ...channel,
        tone: summary.unreadRate > 0.45 ? 'warning' : 'active',
        value: summary.unreadCount,
        unit: 'unread',
      };
    }
    return {
      ...channel,
      tone: summary.mutedWellnessUsers > 0 ? 'pending' : 'active',
      value: summary.mutedWellnessUsers,
      unit: 'muted profiles',
    };
  });

  const kpis = [
    {
      label: 'Deliveries sent',
      value: summary.sentCount,
      trendLabel: 'Tracked sends',
      trendDirection: 'up' as const,
      helper: 'All delivery logs successfully marked sent.',
    },
    {
      label: 'Failure rate',
      value: formatPercent(summary.failureRate),
      trendLabel: summary.failedCount === 0 ? 'Healthy' : `${summary.failedCount} failed`,
      trendDirection: summary.failedCount === 0 ? ('up' as const) : ('down' as const),
      helper: 'Keep this low before raising predictive or therapist ops volume.',
    },
    {
      label: 'Unread load',
      value: summary.unreadCount,
      trendLabel: formatPercent(summary.unreadRate),
      trendDirection: summary.unreadRate <= 0.35 ? ('up' as const) : ('flat' as const),
      helper: 'Unread inbox notifications still waiting for user attention.',
    },
    {
      label: 'Dead letters',
      value: summary.deadLetters,
      trendLabel: health.notificationDeadLetters > 0 ? 'Needs ops review' : 'Clear',
      trendDirection: health.notificationDeadLetters > 0 ? ('down' as const) : ('up' as const),
      helper: 'Retries exhausted and paused for operations follow-up.',
    },
  ];

  return (
    <div className="space-y-5">
      <section className="summary-grid-4">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </section>

      <section className="grid gap-5 xl:grid-cols-[1fr_0.8fr]">
        <MetricChartCard
          className="h-full"
          contentClassName="flex h-full flex-col justify-center pt-4"
          title="Delivery performance"
          description="A clear operating picture across sent, failed, unread, and dead-lettered notification states."
          action={
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() =>
                pushToast({
                  title: 'Notification export prepared',
                  description:
                    'The UI export action is ready to connect to a CSV or analytics endpoint.',
                  tone: 'success',
                })
              }
            >
              Export delivery data
            </Button>
          }
        >
          <div className="grid h-full items-center gap-4 xl:grid-cols-[0.92fr_1.08fr]">
            <div className="chart-frame chart-frame--compact !h-[220px] md:!h-[240px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={deliveryBreakdown}
                    dataKey="value"
                    nameKey="name"
                    innerRadius={60}
                    outerRadius={94}
                    paddingAngle={2}
                  >
                    {deliveryBreakdown.map((entry) => (
                      <Cell key={entry.name} fill={entry.fill} />
                    ))}
                  </Pie>
                  <Tooltip content={<AdminChartTooltip />} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="chart-legend-grid self-center">
              {deliveryBreakdown.map((entry) => (
                <div
                  key={entry.name}
                  className="flex items-center justify-between rounded-[18px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-2.5"
                >
                  <div className="flex items-center gap-3">
                    <span className="h-3 w-3 rounded-full" style={{ backgroundColor: entry.fill }} />
                    <span className="text-sm font-medium text-[var(--mg-text)]">{entry.name}</span>
                  </div>
                  <span className="text-sm font-semibold text-[var(--mg-heading)]">{entry.value}</span>
                </div>
              ))}
              <div className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-primary-soft)] px-4 py-3.5">
                <div className="text-sm font-semibold text-[var(--mg-primary-strong)]">
                  Wellness fatigue watch
                </div>
                <div className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-[var(--mg-heading)]">
                  {summary.mutedWellnessUsers}
                </div>
                <p className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
                  Profiles that have muted all wellness nudges. Use this as a signal to refine cadence before scaling reminders.
                </p>
              </div>
            </div>
          </div>
        </MetricChartCard>

        <Card className="h-full">
          <CardHeader>
            <div>
              <CardTitle>Channel posture</CardTitle>
              <CardDescription>
                Fast operational readout across push, in-app, and wellness reminder behavior.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {channelCards.map((channel) => (
              <div
                key={channel.label}
                className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3.5"
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold text-[var(--mg-heading)]">
                    {channel.label}
                  </div>
                  <StatusBadge status={channel.tone} />
                </div>
                <div className="mt-3 flex items-end justify-between gap-3">
                  <div className="text-[1.6rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                    {channel.value}
                  </div>
                  <div className="text-right text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                    {channel.unit}
                  </div>
                </div>
                <p className="mt-2 text-sm leading-5 text-[var(--mg-muted)] text-trim-2">
                  {channel.helper}
                </p>
              </div>
            ))}
            <div className="rounded-[20px] border border-[rgba(27,116,216,0.16)] bg-[var(--mg-primary-soft)] px-4 py-3.5">
              <div className="text-sm font-semibold text-[var(--mg-heading)]">
                Recommended next move
              </div>
              <p className="mt-2 text-sm leading-5 text-[var(--mg-muted)]">
                Keep delivery failure rate below 5 percent and dead letters at zero before broadening predictive mood notification rollout.
              </p>
            </div>
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.02fr_0.98fr]">
        <MetricChartCard
          className="h-full"
          contentClassName="flex h-full flex-col pt-4"
          title="Top failing templates"
          description="Failure hotspots that deserve fixes before additional notification volume is introduced."
        >
          {summary.topFailingTypes.length === 0 ? (
            <EmptyState
              title="No failing templates recorded"
              description="The tracked notification window is clean right now. This chart will populate automatically when failures are logged."
              className="h-full min-h-[320px] justify-center"
            />
          ) : (
            <div className="chart-frame chart-frame--compact !h-[260px] md:!h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={topFailingTypes}>
                  <CartesianGrid stroke="var(--mg-grid)" vertical={false} />
                  <XAxis
                    dataKey="name"
                    tickLine={false}
                    axisLine={false}
                    tickMargin={10}
                    tickFormatter={(value) => truncateChartLabel(value, 11)}
                  />
                  <YAxis tickLine={false} axisLine={false} tickMargin={10} width={34} />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Bar dataKey="value" radius={[12, 12, 0, 0]}>
                    {topFailingTypes.map((entry) => (
                      <Cell key={entry.name} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </MetricChartCard>

        <Card className="h-full">
          <CardHeader>
            <div>
              <CardTitle>Rollout controls</CardTitle>
              <CardDescription>
                Feature-flag posture for predictive wellness, therapist ops messaging, and channel availability.
              </CardDescription>
            </div>
            <Link href="/settings" className={buttonStyles({ variant: 'outline', size: 'sm' })}>
              Open settings
            </Link>
          </CardHeader>
          <CardContent className="space-y-2.5">
            {flags.map((flag) => (
              <div
                key={flag.id}
                className="flex items-start justify-between gap-4 rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3.5"
              >
                <div className="min-w-0">
                  <div className="text-sm font-semibold text-[var(--mg-heading)]">
                    {flag.id.replace(/_/g, ' ')}
                  </div>
                  <div className="mt-1 text-sm leading-5 text-[var(--mg-muted)] text-trim-2">
                    {flag.description}
                  </div>
                </div>
                <div className="flex flex-col items-end gap-2">
                  <StatusBadge status={flag.enabled ? 'enabled' : 'disabled'} />
                  <span className="rounded-full bg-[var(--mg-surface-muted)] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
                    {flag.rollout}% rollout
                  </span>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Operator checklist</CardTitle>
              <CardDescription>
                A compact runbook for staying ahead of fatigue, delivery drift, and unread overload.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {[
              'Review dead letters before increasing reminder frequency.',
              'Watch unread rate before assuming wellness nudges are landing with users.',
              'Keep lock-screen copy generic by default for privacy-sensitive updates.',
              'Separate therapist ops and user wellness failures during incident triage.',
            ].map((step, index) => (
              <div
                key={step}
                className="flex items-start gap-3 rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded-2xl bg-[var(--mg-primary-soft)] text-sm font-semibold text-[var(--mg-primary-strong)]">
                  {index + 1}
                </div>
                <p className="text-sm leading-6 text-[var(--mg-muted)]">{step}</p>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Connected operations</CardTitle>
              <CardDescription>
                Notification health is strongest when it is paired with incident triage, booking operations, and release readiness.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <Link
              href="/ops/system-health"
              className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 transition hover:border-[var(--mg-border-strong)] hover:bg-white"
            >
              <div className="text-sm font-semibold text-[var(--mg-heading)]">System health</div>
              <p className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
                {health.recentNotificationFailures} failures in the last 24 hours with {health.notificationDeadLetters} dead letters to inspect.
              </p>
            </Link>
            <Link
              href="/ai-ops/incidents"
              className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 transition hover:border-[var(--mg-border-strong)] hover:bg-white"
            >
              <div className="text-sm font-semibold text-[var(--mg-heading)]">Incident flags</div>
              <p className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
                {health.openAiIncidents} active incidents can directly influence whether predictive or crisis-adjacent notifications should ship.
              </p>
            </Link>
            <Link
              href="/reports"
              className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 transition hover:border-[var(--mg-border-strong)] hover:bg-white"
            >
              <div className="text-sm font-semibold text-[var(--mg-heading)]">Reports</div>
              <p className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
                Present delivery health alongside growth, mood trends, and session completion for a more honest platform story.
              </p>
            </Link>
            <Link
              href="/config/feature-flags"
              className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 transition hover:border-[var(--mg-border-strong)] hover:bg-white"
            >
              <div className="text-sm font-semibold text-[var(--mg-heading)]">Feature flags</div>
              <p className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
                Move directly into audited rollout controls when channel posture suggests tightening or expanding exposure.
              </p>
            </Link>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
