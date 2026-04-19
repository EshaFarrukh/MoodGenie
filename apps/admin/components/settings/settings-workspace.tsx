'use client';

import { useMemo } from 'react';
import type { DashboardSummary, FeatureFlag, SystemHealthSnapshot } from '@/lib/types';
import { FeatureFlagEditor } from '@/components/config/feature-flag-editor';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { KpiCard } from '@/components/ui/kpi-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { useToast } from '@/components/ui/toast-provider';

type SettingsWorkspaceProps = {
  flags: FeatureFlag[];
  summary: DashboardSummary;
  health: SystemHealthSnapshot;
};

export function SettingsWorkspace({
  flags,
  summary,
  health,
}: SettingsWorkspaceProps) {
  const { pushToast } = useToast();

  const kpis = useMemo(
    () => [
      {
        label: 'Security posture',
        value: health.recentUnhandledErrors === 0 ? 'Healthy' : 'Watch',
        trendLabel:
          health.recentUnhandledErrors === 0
            ? 'No recent unhandled client crashes'
            : `${health.recentUnhandledErrors} recent client errors`,
        trendDirection:
          health.recentUnhandledErrors === 0 ? ('up' as const) : ('flat' as const),
        helper: 'Operational confidence across auth, crash posture, and protected admin access.',
      },
      {
        label: 'Launch switches',
        value: `${flags.filter((flag) => flag.enabled).length}/${flags.length}`,
        trendLabel: 'Feature flags enabled',
        trendDirection: 'up' as const,
        helper: 'Rollout switches currently active across the admin control plane.',
      },
      {
        label: 'Therapist backlog',
        value: summary.therapistsAwaitingReview,
        trendLabel: summary.therapistsAwaitingReview === 0 ? 'Clear' : 'Needs review',
        trendDirection:
          summary.therapistsAwaitingReview === 0 ? ('up' as const) : ('down' as const),
        helper: 'Credential workflow load that can affect settings and staffing operations.',
      },
      {
        label: 'Privacy queue',
        value: health.privacyQueue,
        trendLabel: health.stalePrivacyJobs > 0 ? 'SLA risk' : 'Within target',
        trendDirection: health.stalePrivacyJobs > 0 ? ('down' as const) : ('up' as const),
        helper: 'Security-sensitive workflows still in motion across exports and deletions.',
      },
    ],
    [flags, health, summary.therapistsAwaitingReview],
  );

  const rolePermissions = [
    {
      role: 'Super Admin',
      scope: 'Full platform control, feature flags, launch posture, and destructive controls.',
      tone: 'active',
    },
    {
      role: 'Trust & Safety',
      scope: 'Incident flags, unsafe AI escalations, and moderation-sensitive settings.',
      tone: 'warning',
    },
    {
      role: 'Support Ops',
      scope: 'Users, bookings, notifications, and incident routing without launch-level switches.',
      tone: 'info',
    },
    {
      role: 'Clinical Ops',
      scope: 'Therapist verification, booking operations, and mood workflow oversight.',
      tone: 'pending',
    },
  ];

  const configurationCards = [
    {
      title: 'General settings',
      status: 'active',
      items: [
        `Default reporting posture: weekly executive summaries plus monthly deep dives`,
        `Therapist review backlog: ${summary.therapistsAwaitingReview} pending applications`,
        `Sessions actively open: ${health.openAppointments}`,
      ],
    },
    {
      title: 'Notification rules',
      status: health.notificationDeadLetters > 0 ? 'warning' : 'active',
      items: [
        `Unread inbox load: ${health.unreadNotifications} notifications`,
        `Delivery failures in 24h: ${health.recentNotificationFailures}`,
        `Keep generic lock-screen copy until privacy policy explicitly allows detail`,
      ],
    },
    {
      title: 'AI moderation',
      status: health.openAiIncidents > 0 ? 'warning' : 'active',
      items: [
        `${health.openAiIncidents} open AI incidents and ${health.highSeverityAiIncidents} high-severity cases`,
        `Recent degraded AI states: ${health.recentAiDegradations}`,
        `Predictive or higher-risk messaging should expand only when incident posture is calm`,
      ],
    },
    {
      title: 'Security preferences',
      status: health.stalePrivacyJobs > 0 ? 'warning' : 'active',
      items: [
        `Privacy queue: ${health.privacyQueue}`,
        `Stale privacy jobs beyond SLA: ${health.stalePrivacyJobs}`,
        `Confirmed appointments missing rooms: ${health.confirmedAppointmentsMissingRoom}`,
      ],
    },
  ];

  return (
    <div className="space-y-5">
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </section>

      <section className="grid gap-5 xl:grid-cols-2">
        <Card className="h-full">
          <CardHeader>
            <div>
              <CardTitle>Control plane overview</CardTitle>
              <CardDescription>
                High-signal settings for access, rollout, and operational guardrails.
              </CardDescription>
            </div>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() =>
                pushToast({
                  title: 'Configuration snapshot prepared',
                  description:
                    'The settings export flow is ready for a backend configuration endpoint when you want to wire it.',
                  tone: 'success',
                })
              }
            >
              Export config
            </Button>
          </CardHeader>
          <CardContent className="space-y-3.5">
            {configurationCards.map((card) => (
              <div
                key={card.title}
                className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4"
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold text-[var(--mg-heading)]">
                    {card.title}
                  </div>
                  <StatusBadge status={card.status} />
                </div>
                <div className="mt-3 space-y-2">
                  {card.items.map((item) => (
                    <div key={item} className="text-sm leading-5 text-[var(--mg-muted)] text-trim-2">
                      {item}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card className="h-full">
          <CardHeader>
            <div>
              <CardTitle>Role permissions</CardTitle>
              <CardDescription>
                Clear authority boundaries for people running clinical, safety, and support workflows.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="grid gap-3.5 sm:grid-cols-2">
            {rolePermissions.map((permission) => (
              <div
                key={permission.role}
                className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4"
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="text-sm font-semibold text-[var(--mg-heading)]">
                    {permission.role}
                  </div>
                  <StatusBadge status={permission.tone} />
                </div>
                <p className="mt-3 text-sm leading-5 text-[var(--mg-muted)] text-trim-3">
                  {permission.scope}
                </p>
              </div>
            ))}
            <div className="rounded-[20px] border border-[rgba(27,116,216,0.16)] bg-[var(--mg-primary-soft)] p-4 sm:col-span-2">
              <div className="text-sm font-semibold text-[var(--mg-primary-strong)]">
                Security principle
              </div>
              <p className="mt-2 text-sm leading-5 text-[var(--mg-muted)]">
                Sensitive controls should stay narrow, auditable, and easy to review.
              </p>
            </div>
          </CardContent>
        </Card>
      </section>

      <section>
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Platform configuration cards</CardTitle>
              <CardDescription>
                The core configuration groups used most often by internal operators.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {[
              {
                title: 'General platform',
                subtitle: 'Session SLAs, environment defaults, and operational thresholds.',
              },
              {
                title: 'Notification posture',
                subtitle: 'Reminder cadence, unread pressure, and delivery governance.',
              },
              {
                title: 'Role and access controls',
                subtitle: 'Scope by role, trust boundary enforcement, and approval surfaces.',
              },
              {
                title: 'AI safety controls',
                subtitle: 'Moderation posture, degraded-state containment, and escalation policy.',
              },
            ].map((item) => (
              <div
                key={item.title}
                className="flex min-h-[132px] flex-col rounded-[18px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4"
              >
                <div className="text-sm font-semibold text-[var(--mg-heading)]">{item.title}</div>
                <p className="mt-2 text-sm leading-5 text-[var(--mg-muted)] text-trim-3">{item.subtitle}</p>
              </div>
            ))}
          </CardContent>
        </Card>
      </section>

      <section>
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Feature rollout controls</CardTitle>
              <CardDescription>
                Audited feature flags with rollout percentages and clear operational ownership.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="pt-0">
            {flags.length === 0 ? null : <FeatureFlagEditor flags={flags} />}
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
