import type { ReactNode } from 'react';
import { requireAdminSession } from '@/lib/auth';
import { AdminShell } from '@/components/layout/admin-shell';
import { getDashboardSummary, getSystemHealthSnapshot } from '@/lib/dal';

export const dynamic = 'force-dynamic';

export default async function DashboardLayout({
  children,
}: {
  children: ReactNode;
}) {
  const session = await requireAdminSession();
  const [summary, health] = await Promise.all([
    getDashboardSummary(),
    getSystemHealthSnapshot(),
  ]);

  const alerts = [
    {
      id: 'approvals',
      title: 'Therapist approvals waiting',
      description: `${summary.therapistsAwaitingReview} provider profiles are still pending review.`,
      href: '/therapists/review-queue',
      tone:
        summary.therapistsAwaitingReview > 0
          ? ('warning' as const)
          : ('info' as const),
    },
    {
      id: 'incidents',
      title: 'Incident queue open',
      description: `${health.openAiIncidents} AI or crisis incidents need reviewer attention.`,
      href: '/ai-ops/incidents',
      tone:
        health.highSeverityAiIncidents > 0 ? ('danger' as const) : ('warning' as const),
    },
    {
      id: 'notifications',
      title: 'Notification health',
      description: `${health.recentNotificationFailures} delivery failures logged in the last 24 hours.`,
      href: '/notifications',
      tone:
        health.recentNotificationFailures > 0
          ? ('warning' as const)
          : ('info' as const),
    },
  ];

  const platformStatus =
    health.highSeverityAiIncidents > 0 || health.recentUnhandledErrors > 0
      ? 'risk'
      : health.recentNotificationFailures > 0 ||
        summary.therapistsAwaitingReview > 0 ||
        health.confirmedAppointmentsMissingRoom > 0
      ? 'watch'
      : 'stable';

  return (
    <AdminShell
      admin={session}
      chrome={{
        platformStatus,
        pendingApprovals: summary.therapistsAwaitingReview,
        unreadNotifications: health.unreadNotifications,
        openIncidents: health.openAiIncidents,
        alerts,
      }}
    >
      {children}
    </AdminShell>
  );
}
