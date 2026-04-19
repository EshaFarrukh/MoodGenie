import { ReportsWorkspace } from '@/components/reports/reports-workspace';
import { requireAdminSession } from '@/lib/auth';
import {
  getAIIncidents,
  getAppointments,
  getDashboardSummary,
  getNotificationHealthSummary,
  getSystemHealthSnapshot,
} from '@/lib/dal';

export default async function ReportsPage() {
  await requireAdminSession([
    'super_admin',
    'support_ops',
    'trust_safety',
    'read_only_analytics',
  ]);

  const [summary, health, notificationHealth, appointments, incidents] =
    await Promise.all([
      getDashboardSummary(),
      getSystemHealthSnapshot(),
      getNotificationHealthSummary(),
      getAppointments('', 1),
      getAIIncidents(1),
    ]);

  return (
    <ReportsWorkspace
      summary={summary}
      health={health}
      notificationHealth={notificationHealth}
      appointments={appointments.items}
      incidents={incidents.items}
    />
  );
}
