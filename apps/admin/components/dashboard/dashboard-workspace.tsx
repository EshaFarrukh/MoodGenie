'use client';

import Link from 'next/link';
import {
  Area,
  AreaChart,
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
  DashboardSummary,
  IncidentRow,
  NotificationHealthSummary,
  PaginatedResult,
  SystemHealthSnapshot,
  TherapistReviewRow,
} from '@/lib/types';
import {
  buildDashboardKpis,
  buildGrowthSeries,
  buildMoodDistribution,
  buildMoodTrendSeries,
  buildPlatformHealthCards,
  buildQuickActions,
  buildSystemActivitySeries,
} from '@/lib/admin-portal';
import { Button } from '@/components/ui/button';
import { AdminChartTooltip } from '@/components/ui/chart-tooltip';
import { KpiCard } from '@/components/ui/kpi-card';
import { MetricChartCard } from '@/components/ui/metric-chart-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { formatDateLabel, formatPercent } from '@/lib/utils';
import { ArrowUpRight } from 'lucide-react';

type DashboardWorkspaceProps = {
  summary: DashboardSummary;
  health: SystemHealthSnapshot;
  notificationHealth: NotificationHealthSummary;
  reviewQueue: PaginatedResult<TherapistReviewRow>;
  incidents: PaginatedResult<IncidentRow>;
};

export function DashboardWorkspace({
  summary,
  health,
  notificationHealth,
  reviewQueue,
  incidents,
}: DashboardWorkspaceProps) {
  const kpis = buildDashboardKpis(summary, health);
  const systemActivity = buildSystemActivitySeries(summary, health);
  const userGrowth = buildGrowthSeries(summary.totalUsers);
  const moodDistribution = buildMoodDistribution(summary);
  const moodTrend = buildMoodTrendSeries(summary.totalUsers);
  const quickActions = buildQuickActions(
    summary.therapistsAwaitingReview,
    health.openAiIncidents,
  );
  const platformHealth = buildPlatformHealthCards(health);

  return (
    <div className="space-y-6">
      {/* KPIs */}
      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </section>

      {/* Main Charts */}
      <section className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <MetricChartCard
            title="System Activity"
            description="Live overview across sessions, chats, and active incidents"
            footer={
              <div className="flex items-center gap-4 text-xs font-medium text-[var(--mg-muted)]">
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-[var(--mg-primary-strong)]" />Sessions</span>
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-[var(--mg-accent)]" />Chats</span>
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-[var(--mg-danger)]" />Incidents</span>
              </div>
            }
          >
            <div className="h-72 w-full pt-4">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={systemActivity}>
                  <CartesianGrid stroke="var(--mg-grid)" vertical={false} />
                  <XAxis dataKey="day" tickLine={false} axisLine={false} tickMargin={10} fontSize={12} fill="var(--mg-muted)" />
                  <YAxis tickLine={false} axisLine={false} tickMargin={10} width={30} fontSize={12} fill="var(--mg-muted)" />
                  <Tooltip content={<AdminChartTooltip />} />
                  <Line type="monotone" dataKey="sessions" stroke="var(--mg-primary-strong)" strokeWidth={2} dot={false} />
                  <Line type="monotone" dataKey="chats" stroke="var(--mg-accent)" strokeWidth={2} dot={false} />
                  <Line type="monotone" dataKey="incidents" stroke="var(--mg-danger)" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </MetricChartCard>
        </div>

        <div>
          <div className="h-full rounded-[22px] border border-[var(--mg-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(248,251,255,0.96))] p-5 shadow-[var(--mg-shadow-md)]">
            <h3 className="text-sm font-semibold text-[var(--mg-heading)]">Platform Health</h3>
            <p className="mb-5 mt-1 text-xs text-[var(--mg-muted)]">Quick pulse on system reliability</p>

            <div className="space-y-3">
              {platformHealth.map((item) => (
                <div key={item.label} className="flex items-center justify-between rounded-[18px] bg-[var(--mg-surface-subtle)] p-3">
                  <div>
                    <div className="text-sm font-medium text-[var(--mg-heading)]">{item.label}</div>
                    <div className="text-xs text-[var(--mg-muted)]">{item.helper}</div>
                  </div>
                  <div className="text-lg font-semibold text-[var(--mg-heading)]">{item.value}</div>
                </div>
              ))}
              <div className="rounded-[18px] border border-[rgba(0,102,204,0.12)] bg-[var(--mg-primary-soft)] p-3">
                <div className="flex items-center justify-between">
                  <div className="text-sm font-medium text-[var(--mg-primary-strong)]">Notification Delivery</div>
                  <div className="text-lg font-semibold text-[var(--mg-heading)]">{formatPercent(notificationHealth.failureRate)}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Secondary Row */}
      <section className="grid gap-6 lg:grid-cols-3">
        <MetricChartCard title="User Growth" description="Monthly acquisition trend">
          <div className="h-56 w-full pt-4">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={userGrowth}>
                <XAxis dataKey="month" tickLine={false} axisLine={false} tickMargin={10} fontSize={12} fill="var(--mg-muted)" />
                <YAxis tickLine={false} axisLine={false} tickMargin={10} width={30} fontSize={12} fill="var(--mg-muted)" />
                <Tooltip content={<AdminChartTooltip />} />
                <Bar dataKey="users" radius={[4, 4, 0, 0]} fill="var(--mg-primary)" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </MetricChartCard>

        <MetricChartCard title="Mood Intelligence" description="Wellbeing distribution and alerts">
          <div className="flex h-56 flex-col justify-between pt-2">
            <ResponsiveContainer width="100%" height="50%">
              <AreaChart data={moodTrend}>
                <XAxis dataKey="day" tickLine={false} axisLine={false} tickMargin={10} fontSize={10} hide />
                <Tooltip content={<AdminChartTooltip />} />
                <Area type="monotone" dataKey="elevatedRisk" stroke="var(--mg-accent)" fill="rgba(0,180,216,0.12)" strokeWidth={1.4} />
              </AreaChart>
            </ResponsiveContainer>

            <div className="mt-4 grid grid-cols-2 gap-2">
              {moodDistribution.slice(0,4).map((entry) => (
                <div key={entry.name} className="flex items-center justify-between rounded-xl bg-[var(--mg-surface-subtle)] p-2 text-xs">
                  <span className="flex items-center gap-1.5">
                    <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: entry.fill }} />
                    <span className="font-medium text-[var(--mg-text)]">{entry.name}</span>
                  </span>
                  <span className="font-semibold text-[var(--mg-heading)]">{entry.value}</span>
                </div>
              ))}
            </div>
          </div>
        </MetricChartCard>

        <div className="rounded-[22px] border border-[var(--mg-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(248,251,255,0.96))] p-5 shadow-[var(--mg-shadow-md)]">
          <h3 className="text-sm font-semibold text-[var(--mg-heading)]">Quick Actions</h3>
          <div className="mt-4 space-y-2">
            {quickActions.map((action) => (
              <Link
                key={action.title}
                href={action.href}
                className="group flex flex-col rounded-[18px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-3 transition-colors hover:border-[var(--mg-border-strong)] hover:bg-white"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-[var(--mg-heading)]">{action.title}</span>
                  <ArrowUpRight className="h-4 w-4 text-[var(--mg-muted)] group-hover:text-[var(--mg-primary)]" />
                </div>
                <span className="mt-1 text-xs text-[var(--mg-muted)] line-clamp-1">{action.description}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* Queues */}
      <section className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-[22px] border border-[var(--mg-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(248,251,255,0.96))] p-5 shadow-[var(--mg-shadow-md)]">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-[var(--mg-heading)]">Recent Therapist Approvals</h3>
              <p className="text-xs text-[var(--mg-muted)]">Provider review backlog</p>
            </div>
            <Link href="/therapists/review-queue" className="text-xs font-medium text-[var(--mg-primary)] hover:text-[var(--mg-primary-strong)]">View all</Link>
          </div>

          <div className="space-y-2">
            {reviewQueue.items.length === 0 ? (
              <div className="p-4 text-center text-sm text-[var(--mg-muted)]">Queue is clear</div>
            ) : (
              reviewQueue.items.slice(0, 5).map((therapist) => (
                <Link
                  key={therapist.id}
                  href={`/therapists/${therapist.id}`}
                  className="flex items-center justify-between rounded-[18px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-3 transition-colors hover:border-[var(--mg-border-strong)] hover:bg-white"
                >
                  <div className="min-w-0">
                    <div className="text-sm font-medium text-[var(--mg-heading)] truncate">{therapist.name}</div>
                    <div className="text-xs text-[var(--mg-muted)] truncate">{therapist.specialty || 'Pending'} • {therapist.email || 'No email'}</div>
                  </div>
                  <StatusBadge status={therapist.reviewStatus} />
                </Link>
              ))
            )}
          </div>
        </div>

        <div className="rounded-[22px] border border-[var(--mg-border)] bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(248,251,255,0.96))] p-5 shadow-[var(--mg-shadow-md)]">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-[var(--mg-heading)]">Incident Flags</h3>
              <p className="text-xs text-[var(--mg-muted)]">Active trust & safety events</p>
            </div>
            <Link href="/ai-ops/incidents" className="text-xs font-medium text-[var(--mg-primary)] hover:text-[var(--mg-primary-strong)]">View all</Link>
          </div>

          <div className="space-y-2">
            {incidents.items.length === 0 ? (
              <div className="p-4 text-center text-sm text-[var(--mg-muted)]">No active incidents</div>
            ) : (
              incidents.items.slice(0, 5).map((incident) => (
                <Link
                  key={incident.id}
                  href={`/ai-ops/incidents/${incident.id}`}
                  className="flex items-center justify-between rounded-[18px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-3 transition-colors hover:border-[var(--mg-border-strong)] hover:bg-white"
                >
                  <div className="min-w-0 pr-4">
                    <div className="text-sm font-medium text-[var(--mg-heading)] truncate">{incident.title}</div>
                    <div className="text-xs text-[var(--mg-muted)]">{incident.category || 'General'}</div>
                  </div>
                  <StatusBadge status={incident.severity} />
                </Link>
              ))
            )}
          </div>
        </div>
      </section>
    </div>
  );
}
