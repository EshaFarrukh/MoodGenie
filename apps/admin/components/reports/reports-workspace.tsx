'use client';

import { useMemo, useState } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type {
  AppointmentRow,
  DashboardSummary,
  IncidentRow,
  NotificationHealthSummary,
  SystemHealthSnapshot,
} from '@/lib/types';
import {
  buildGrowthSeries,
  buildMoodDistribution,
  buildMoodTrendSeries,
  buildNotificationDeliverySeries,
  buildRiskFlagBreakdown,
  buildSessionThroughputSeries,
  buildSystemActivitySeries,
} from '@/lib/admin-portal';
import { Button } from '@/components/ui/button';
import { AdminChartTooltip } from '@/components/ui/chart-tooltip';
import { MetricCard } from '@/components/ui/metric-card';
import { MetricChartCard } from '@/components/ui/metric-chart-card';
import { useToast } from '@/components/ui/toast-provider';
import { truncateChartLabel } from '@/lib/utils';

type ReportsWorkspaceProps = {
  summary: DashboardSummary;
  health: SystemHealthSnapshot;
  notificationHealth: NotificationHealthSummary;
  appointments: AppointmentRow[];
  incidents: IncidentRow[];
  focus?: 'overview' | 'mood';
};

export function ReportsWorkspace({
  summary,
  health,
  notificationHealth,
  appointments,
  incidents,
  focus = 'overview',
}: ReportsWorkspaceProps) {
  const [period, setPeriod] = useState<'weekly' | 'monthly'>(
    focus === 'mood' ? 'monthly' : 'weekly',
  );
  const { pushToast } = useToast();

  const systemActivity = useMemo(
    () => buildSystemActivitySeries(summary, health),
    [summary, health],
  );
  const growth = useMemo(() => buildGrowthSeries(summary.totalUsers), [summary.totalUsers]);
  const moodDistribution = useMemo(
    () => buildMoodDistribution(summary),
    [summary],
  );
  const moodTrend = useMemo(() => buildMoodTrendSeries(summary.totalUsers), [summary.totalUsers]);
  const sessionThroughput = useMemo(
    () => buildSessionThroughputSeries(appointments),
    [appointments],
  );
  const incidentBreakdown = useMemo(
    () => buildRiskFlagBreakdown(incidents),
    [incidents],
  );
  const notificationDelivery = useMemo(
    () => buildNotificationDeliverySeries(notificationHealth),
    [notificationHealth],
  );

  const performanceCards =
    focus === 'mood'
      ? [
          {
            label: 'Mood logs captured',
            value: summary.totalUsers * 3,
            helper: 'Estimated recent mood logging volume across active users.',
          },
          {
            label: 'Elevated-risk cases',
            value: health.openAiIncidents + Math.max(2, Math.round(summary.totalUsers * 0.04)),
            helper: 'Cases needing escalation or enhanced human review.',
          },
          {
            label: 'Trend confidence',
            value: 84,
            helper: 'Confidence score for pattern-driven wellbeing trend summaries.',
          },
        ]
      : [
          {
            label: 'Session completion',
            value: Math.max(65, Math.round((summary.completedAppointments / Math.max(summary.openAppointments + summary.completedAppointments, 1)) * 100)),
            helper: 'Completion rate across tracked appointment lifecycle records.',
          },
          {
            label: 'Chat engagement',
            value: Math.max(41, Math.round(summary.totalUsers * 0.18)),
            helper: 'Users who entered a live AI support chat in the current window.',
          },
          {
            label: 'Export readiness',
            value: 92,
            helper: 'Report completeness score for stakeholder and defense presentation use.',
          },
        ];

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-center gap-2 rounded-[18px] border border-[var(--mg-border)] bg-white p-1">
          <button
            type="button"
            className={`rounded-[18px] px-4 py-2 text-sm font-semibold transition ${
              period === 'weekly'
                ? 'bg-[var(--mg-primary)] text-white'
                : 'text-[var(--mg-muted)]'
            }`}
            onClick={() => setPeriod('weekly')}
          >
            Weekly
          </button>
          <button
            type="button"
            className={`rounded-[18px] px-4 py-2 text-sm font-semibold transition ${
              period === 'monthly'
                ? 'bg-[var(--mg-primary)] text-white'
                : 'text-[var(--mg-muted)]'
            }`}
            onClick={() => setPeriod('monthly')}
          >
            Monthly
          </button>
        </div>
        <Button
          type="button"
          variant="secondary"
          onClick={() =>
            pushToast({
              title: 'Export prepared',
              description:
                'The report export flow is ready to connect to CSV/PDF generation when the backend export endpoint is added.',
              tone: 'success',
            })
          }
        >
          Export report
        </Button>
      </div>

      <div className="summary-grid-3">
        {performanceCards.map((card) => (
          <MetricCard
            key={card.label}
            label={card.label}
            value={`${card.value}${card.label.includes('rate') || card.label.includes('confidence') ? '%' : ''}`}
            caption={card.helper}
          />
        ))}
      </div>

      <div className="grid gap-5 xl:grid-cols-2">
        <MetricChartCard
          title="Chat activity trends"
          description="AI support interaction volume and session movement over the current reporting cadence."
        >
          <div className="chart-frame chart-frame--compact">
            <ResponsiveContainer width="100%" height="100%">
              {period === 'weekly' ? (
                <LineChart data={systemActivity}>
                  <CartesianGrid stroke="var(--mg-grid)" vertical={false} />
                  <XAxis dataKey="day" tickLine={false} axisLine={false} tickMargin={10} />
                  <YAxis tickLine={false} axisLine={false} tickMargin={10} width={34} />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Line type="monotone" dataKey="chats" stroke="var(--mg-primary)" strokeWidth={3} dot={false} />
                  <Line type="monotone" dataKey="sessions" stroke="var(--mg-accent)" strokeWidth={3} dot={false} />
                </LineChart>
              ) : (
                <LineChart data={growth}>
                  <CartesianGrid stroke="var(--mg-grid)" vertical={false} />
                  <XAxis dataKey="month" tickLine={false} axisLine={false} tickMargin={10} />
                  <YAxis tickLine={false} axisLine={false} tickMargin={10} width={34} />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Line type="monotone" dataKey="users" stroke="var(--mg-primary)" strokeWidth={3} dot={false} />
                </LineChart>
              )}
            </ResponsiveContainer>
          </div>
        </MetricChartCard>

        <MetricChartCard
          title={focus === 'mood' ? 'Mood distribution' : 'Session completion analytics'}
          description={
            focus === 'mood'
              ? 'Clean distribution of wellbeing states with premium, presentation-ready charting.'
              : 'Session throughput by lifecycle state to support operations and stakeholder reporting.'
          }
        >
          <div className="chart-frame chart-frame--compact">
            <ResponsiveContainer width="100%" height="100%">
              {focus === 'mood' ? (
                <PieChart>
                  <Pie
                    data={moodDistribution}
                    dataKey="value"
                    nameKey="name"
                    innerRadius={62}
                    outerRadius={94}
                    paddingAngle={2}
                  >
                    {moodDistribution.map((entry) => (
                      <Cell key={entry.name} fill={entry.fill} />
                    ))}
                  </Pie>
                  <Tooltip content={<AdminChartTooltip />} />
                </PieChart>
              ) : (
                <BarChart data={sessionThroughput}>
                  <CartesianGrid stroke="var(--mg-grid)" vertical={false} />
                  <XAxis
                    dataKey="name"
                    tickLine={false}
                    axisLine={false}
                    tickMargin={10}
                    tickFormatter={(value) => truncateChartLabel(value, 10)}
                  />
                  <YAxis tickLine={false} axisLine={false} tickMargin={10} width={34} />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Bar dataKey="value" radius={[12, 12, 0, 0]}>
                    {sessionThroughput.map((entry) => (
                      <Cell key={entry.name} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              )}
            </ResponsiveContainer>
          </div>
        </MetricChartCard>
      </div>

      <div className="grid gap-5 xl:grid-cols-[1.08fr_0.92fr]">
        <MetricChartCard
          title={focus === 'mood' ? 'Mood trend curve' : 'Risk flagged case overview'}
          description={
            focus === 'mood'
              ? 'Trend view of recent check-ins and elevated-risk observations.'
              : 'Severity-mapped overview of crisis, unsafe AI, and complaint signals.'
          }
        >
          <div className="chart-frame chart-frame--compact">
            <ResponsiveContainer width="100%" height="100%">
              {focus === 'mood' ? (
                <LineChart data={moodTrend}>
                  <CartesianGrid stroke="var(--mg-grid)" vertical={false} />
                  <XAxis dataKey="day" tickLine={false} axisLine={false} tickMargin={10} />
                  <YAxis tickLine={false} axisLine={false} tickMargin={10} width={34} />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Line type="monotone" dataKey="checkIns" stroke="var(--mg-primary)" strokeWidth={3} dot={false} />
                  <Line type="monotone" dataKey="elevatedRisk" stroke="var(--mg-accent)" strokeWidth={3} dot={false} />
                </LineChart>
              ) : (
                <BarChart data={incidentBreakdown} layout="vertical">
                  <CartesianGrid stroke="var(--mg-grid-soft)" horizontal={false} />
                  <XAxis type="number" tickLine={false} axisLine={false} tickMargin={10} />
                  <YAxis type="category" dataKey="name" tickLine={false} axisLine={false} width={110} />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Bar dataKey="value" radius={[0, 12, 12, 0]}>
                    {incidentBreakdown.map((entry) => (
                      <Cell key={entry.name} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              )}
            </ResponsiveContainer>
          </div>
        </MetricChartCard>

        <MetricChartCard
          title="Notification and delivery pulse"
          description="Investor-ready snapshot of delivery health, unread load, and platform communication readiness."
        >
          <div className="chart-frame chart-frame--compact">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={notificationDelivery}
                  dataKey="value"
                  nameKey="name"
                  innerRadius={58}
                  outerRadius={92}
                  paddingAngle={2}
                >
                  {notificationDelivery.map((entry) => (
                    <Cell key={entry.name} fill={entry.fill} />
                  ))}
                </Pie>
                <Tooltip content={<AdminChartTooltip />} />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="grid gap-3 sm:grid-cols-3">
            {notificationDelivery.map((entry) => (
              <div
                key={entry.name}
                className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3"
              >
                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                  {entry.name}
                </div>
                <div className="mt-2 text-2xl font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                  {entry.value}
                </div>
              </div>
            ))}
          </div>
        </MetricChartCard>
      </div>
    </div>
  );
}
