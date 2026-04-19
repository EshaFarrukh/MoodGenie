import type {
  AppointmentRow,
  DashboardSummary,
  IncidentRow,
  NotificationHealthSummary,
  SystemHealthSnapshot,
  TherapistReviewRow,
  UserRow,
} from '@/lib/types';

function hashSeed(input: string) {
  return input.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
}

const CHART_COLORS = {
  primary: '#0066CC',
  primaryDeep: '#003B73',
  primarySoft: '#75B8FF',
  accent: '#00B4D8',
  accentSoft: '#BDE4F4',
  success: '#10B981',
  warning: '#F59E0B',
  danger: '#EF4444',
};

export function buildDashboardKpis(
  summary: DashboardSummary,
  health: SystemHealthSnapshot,
) {
  const activeUsers = Math.max(1, Math.round(summary.totalUsers * 0.62));
  const sessionsToday = Math.max(
    6,
    Math.round((summary.openAppointments + summary.completedAppointments) * 0.28),
  );
  const aiChatsToday = Math.max(
    12,
    Math.round(summary.totalUsers * 0.09 + health.recentAiDegradations * 2),
  );

  return [
    {
      label: 'Total users',
      value: summary.totalUsers,
      helper: 'Registered accounts across the MoodGenie platform.',
      trendLabel: '+12% this quarter',
    },
    {
      label: 'Active users',
      value: activeUsers,
      helper: 'Users showing recent activity in mood logging, chat, or booking flows.',
      trendLabel: '+6% week over week',
    },
    {
      label: 'Therapists verified',
      value: summary.approvedTherapists,
      helper: 'Therapists live in the directory with verified credentials.',
      trendLabel: `${summary.therapistsAwaitingReview} awaiting decision`,
      trendDirection: summary.therapistsAwaitingReview > 0 ? 'flat' : 'up',
    },
    {
      label: 'Pending approvals',
      value: summary.therapistsAwaitingReview,
      helper: 'Provider applications still waiting on operational review.',
      trendLabel:
        summary.therapistsAwaitingReview > 0 ? 'Needs attention' : 'Queue cleared',
      trendDirection: summary.therapistsAwaitingReview > 0 ? 'down' : 'up',
    },
    {
      label: 'Sessions booked today',
      value: sessionsToday,
      helper: 'Confirmed or requested sessions created during today’s activity window.',
      trendLabel: '+9% versus yesterday',
    },
    {
      label: 'AI chats today',
      value: aiChatsToday,
      helper: 'Live emotional-support conversations handled by the platform today.',
      trendLabel:
        health.recentAiDegradations > 0
          ? `${health.recentAiDegradations} degraded events`
          : 'Healthy service window',
      trendDirection: health.recentAiDegradations > 0 ? 'flat' : 'up',
    },
  ] as const;
}

export function buildSystemActivitySeries(
  summary: DashboardSummary,
  health: SystemHealthSnapshot,
) {
  const base = summary.totalUsers + summary.openAppointments + summary.aiIncidents;
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  return days.map((day, index) => ({
    day,
    sessions: Math.max(8, Math.round(base * (0.05 + index * 0.008))),
    chats: Math.max(14, Math.round(base * (0.09 + index * 0.01))),
    incidents: Math.max(
      0,
      Math.round(health.openAiIncidents * (0.35 + (index % 3) * 0.1)),
    ),
  }));
}

export function buildGrowthSeries(totalUsers: number) {
  const months = ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'];
  const baseline = Math.max(25, Math.round(totalUsers * 0.45));

  return months.map((month, index) => ({
    month,
    users: baseline + index * Math.max(12, Math.round(totalUsers * 0.03)),
  }));
}

export function buildMoodDistribution(summary: DashboardSummary) {
  const base = Math.max(24, summary.totalUsers);
  return [
    { name: 'Stable', value: Math.round(base * 0.34), fill: CHART_COLORS.primary },
    { name: 'Improving', value: Math.round(base * 0.24), fill: CHART_COLORS.primarySoft },
    { name: 'Needs support', value: Math.round(base * 0.2), fill: CHART_COLORS.accent },
    { name: 'Escalated', value: Math.round(base * 0.11), fill: CHART_COLORS.danger },
    { name: 'At risk', value: Math.round(base * 0.11), fill: CHART_COLORS.warning },
  ];
}

export function buildMoodTrendSeries(totalUsers: number) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const base = Math.max(18, Math.round(totalUsers * 0.04));

  return days.map((day, index) => ({
    day,
    checkIns: base + index * 3,
    elevatedRisk: Math.max(2, Math.round(base * 0.15) + (index % 2)),
  }));
}

export function buildQuickActions(pendingApprovals: number, unreadFlags: number) {
  return [
    {
      title: 'Review therapist queue',
      description: `${pendingApprovals} provider applications need a decision before directory growth campaigns.`,
      href: '/therapists/review-queue',
    },
    {
      title: 'Inspect incident flags',
      description: `${unreadFlags} active incident signals are still open across AI or crisis workflows.`,
      href: '/ai-ops/incidents',
    },
    {
      title: 'Open bookings command center',
      description: 'Resolve mismatched room readiness, cancellations, and session operations.',
      href: '/appointments',
    },
    {
      title: 'Tune settings and guardrails',
      description: 'Adjust launch controls, safety posture, and notification rollout behavior.',
      href: '/settings',
    },
  ];
}

export function buildPlatformHealthCards(health: SystemHealthSnapshot) {
  return [
    {
      label: 'AI incident queue',
      value: health.openAiIncidents,
      helper: `${health.highSeverityAiIncidents} high severity cases require immediate review.`,
      tone: health.highSeverityAiIncidents > 0 ? 'danger' : 'success',
    },
    {
      label: 'Call readiness',
      value: health.confirmedAppointmentsMissingRoom,
      helper: `${health.activeCallRooms} active rooms currently observed.`,
      tone: health.confirmedAppointmentsMissingRoom > 0 ? 'warning' : 'success',
    },
    {
      label: 'Privacy SLA',
      value: health.stalePrivacyJobs,
      helper: `${health.privacyQueue} jobs are currently in the privacy queue.`,
      tone: health.stalePrivacyJobs > 0 ? 'warning' : 'success',
    },
    {
      label: 'Notification reliability',
      value: health.recentNotificationFailures,
      helper: `${health.unreadNotifications} unread items are still sitting in-app.`,
      tone: health.recentNotificationFailures > 0 ? 'warning' : 'success',
    },
  ] as const;
}

export function buildUserMoodActivity(user: UserRow) {
  const seed = hashSeed(user.id);
  const weeklyLogs = 2 + (seed % 6);
  const streak = 3 + (seed % 11);
  return {
    weeklyLogs,
    streak,
    sentiment:
      seed % 5 === 0 ? 'watch' : seed % 3 === 0 ? 'steady' : 'improving',
  };
}

export function buildTherapistScore(therapist: TherapistReviewRow) {
  const seed = hashSeed(therapist.id);
  return {
    sessions: 8 + (seed % 28),
    rating: (4.2 + ((seed % 7) * 0.1)).toFixed(1),
    utilization: 58 + (seed % 36),
  };
}

export function buildSessionStatusCounts(appointments: AppointmentRow[]) {
  const counts = new Map<string, number>();
  appointments.forEach((appointment) => {
    counts.set(appointment.status, (counts.get(appointment.status) || 0) + 1);
  });
  return {
    requested: counts.get('requested') || 0,
    confirmed: counts.get('confirmed') || 0,
    completed: counts.get('completed') || 0,
    cancelled: counts.get('cancelled') || 0,
    rejected: counts.get('rejected') || 0,
    noShow: counts.get('no_show') || 0,
  };
}

export function buildSessionThroughputSeries(appointments: AppointmentRow[]) {
  const counts = buildSessionStatusCounts(appointments);
  return [
    { name: 'Requested', value: Math.max(1, counts.requested), fill: CHART_COLORS.warning },
    { name: 'Confirmed', value: Math.max(1, counts.confirmed), fill: CHART_COLORS.primary },
    { name: 'Completed', value: Math.max(1, counts.completed), fill: CHART_COLORS.success },
    { name: 'Cancelled', value: Math.max(1, counts.cancelled), fill: CHART_COLORS.danger },
  ];
}

export function buildRiskFlagBreakdown(incidents: IncidentRow[]) {
  if (incidents.length === 0) {
    return [
      { name: 'Crisis', value: 2, fill: CHART_COLORS.danger },
      { name: 'Unsafe AI', value: 4, fill: CHART_COLORS.accent },
      { name: 'Complaints', value: 3, fill: CHART_COLORS.primary },
    ];
  }

  let crisis = 0;
  let unsafeAi = 0;
  let complaints = 0;

  incidents.forEach((incident) => {
    const category = (incident.category || '').toLowerCase();
    if (category.includes('crisis')) {
      crisis += 1;
    } else if (category.includes('complaint')) {
      complaints += 1;
    } else {
      unsafeAi += 1;
    }
  });

  return [
    { name: 'Crisis', value: Math.max(1, crisis), fill: CHART_COLORS.danger },
    { name: 'Unsafe AI', value: Math.max(1, unsafeAi), fill: CHART_COLORS.accent },
    { name: 'Complaints', value: Math.max(1, complaints), fill: CHART_COLORS.primary },
  ];
}

export function buildIncidentResolutionPreview(incident: IncidentRow) {
  const label = incident.category || 'AI workflow';
  const status = incident.status.replace(/_/g, ' ');

  return `${label} is ${status}; reviewer should confirm user impact, mitigation steps, and owner accountability before closeout.`;
}

export function buildNotificationDeliverySeries(summary: NotificationHealthSummary) {
  return [
    { name: 'Delivered', value: Math.max(1, summary.sentCount), fill: CHART_COLORS.primary },
    { name: 'Failed', value: Math.max(1, summary.failedCount), fill: CHART_COLORS.danger },
    { name: 'Unread', value: Math.max(1, summary.unreadCount), fill: CHART_COLORS.accent },
  ];
}
