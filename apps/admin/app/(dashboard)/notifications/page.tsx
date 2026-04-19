import { NotificationsWorkspace } from '@/components/notifications/notifications-workspace';
import { requireAdminSession } from '@/lib/auth';
import { getFeatureFlags, getNotificationHealthSummary, getSystemHealthSnapshot } from '@/lib/dal';

const NOTIFICATION_FLAG_IDS = new Set([
  'predictive_mood_notifications',
  'ai_generated_notification_copy',
  'appointment_emails',
  'therapist_push_ops',
]);

export default async function NotificationsPage() {
  await requireAdminSession([
    'super_admin',
    'support_ops',
    'trust_safety',
    'read_only_analytics',
  ]);

  const [summary, flags, health] = await Promise.all([
    getNotificationHealthSummary(),
    getFeatureFlags(),
    getSystemHealthSnapshot(),
  ]);

  return (
    <NotificationsWorkspace
      summary={summary}
      flags={flags.filter((flag) => NOTIFICATION_FLAG_IDS.has(flag.id))}
      health={health}
    />
  );
}
