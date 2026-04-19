import {
  getAIIncidents,
  getDashboardSummary,
  getNotificationHealthSummary,
  getSystemHealthSnapshot,
  getTherapistReviewQueue,
} from '@/lib/dal';
import { DashboardWorkspace } from '@/components/dashboard/dashboard-workspace';

export default async function DashboardPage() {
  const [summary, health, notificationHealth, reviewQueue, incidents] =
    await Promise.all([
      getDashboardSummary(),
      getSystemHealthSnapshot(),
      getNotificationHealthSummary(),
      getTherapistReviewQueue(1),
      getAIIncidents(1),
    ]);

  return (
    <DashboardWorkspace
      summary={summary}
      health={health}
      notificationHealth={notificationHealth}
      reviewQueue={reviewQueue}
      incidents={incidents}
    />
  );
}
