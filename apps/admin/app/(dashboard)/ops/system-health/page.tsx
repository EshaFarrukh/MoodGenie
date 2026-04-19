import Link from 'next/link';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { KpiCard } from '@/components/ui/kpi-card';
import { requireAdminSession } from '@/lib/auth';
import { getSystemHealthSnapshot } from '@/lib/dal';

export default async function SystemHealthPage() {
  await requireAdminSession([
    'super_admin',
    'support_ops',
    'trust_safety',
    'read_only_analytics',
  ]);
  const summary = await getSystemHealthSnapshot();
  const kpis = [
    {
      label: 'Review backlog',
      value: summary.therapistReviewBacklog,
      helper: 'Therapists still waiting on operational trust decisions.',
    },
    {
      label: 'Open AI incidents',
      value: summary.openAiIncidents,
      helper: 'Safety or backend anomalies requiring active attention.',
    },
    {
      label: 'Privacy queue',
      value: summary.privacyQueue,
      helper: 'Export or deletion workflows still in progress.',
    },
    {
      label: 'Open sessions',
      value: summary.openAppointments,
      helper: 'Requested or confirmed appointments requiring healthy flow.',
    },
    {
      label: 'Notification failures',
      value: summary.recentNotificationFailures,
      helper: 'Push delivery failures seen in the last 24 hours.',
    },
    {
      label: 'Unread inbox',
      value: summary.unreadNotifications,
      helper: 'Unread in-app notifications still waiting on users.',
    },
  ];

  const operationalSignals = [
    'Therapist approval backlog should stay near zero before scaling growth.',
    `High-severity AI incidents still open: ${summary.highSeverityAiIncidents}`,
    `Unassigned AI incidents: ${summary.unassignedAiIncidents}`,
    `Confirmed appointments missing call rooms: ${summary.confirmedAppointmentsMissingRoom}`,
    `Active call rooms observed: ${summary.activeCallRooms}`,
    `Stale privacy jobs beyond SLA: ${summary.stalePrivacyJobs}`,
    `Recent unhandled mobile errors: ${summary.recentUnhandledErrors}`,
    `Recent AI degraded or fallback states: ${summary.recentAiDegradations}`,
    `Notifications sent in the last 24 hours: ${summary.recentNotificationsSent}`,
    `Notification dead letters awaiting ops review: ${summary.notificationDeadLetters}`,
  ];

  const shortcuts = [
    { href: '/ai-ops/incidents', label: 'Review AI incidents' },
    { href: '/ops/notification-health', label: 'Review notification ops' },
    { href: '/appointments', label: 'Inspect appointments' },
    { href: '/support/data-requests', label: 'Triage privacy jobs' },
    { href: '/therapists/review-queue', label: 'Clear therapist backlog' },
  ];

  return (
    <div className="space-y-6">
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Operational posture</CardTitle>
              <CardDescription>
                This page is the live launch-readiness wall for the product
                team, support, and trust operations.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {operationalSignals.map((item) => (
              <div
                key={item}
                className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]"
              >
                {item}
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Recommended alert wiring</CardTitle>
              <CardDescription>
                These are the first alerts to connect as release hardening continues.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            {shortcuts.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white"
              >
                {item.label}
              </Link>
            ))}
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
