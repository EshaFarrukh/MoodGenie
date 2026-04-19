import { SettingsWorkspace } from '@/components/settings/settings-workspace';
import { requireAdminSession } from '@/lib/auth';
import { getDashboardSummary, getFeatureFlags, getSystemHealthSnapshot } from '@/lib/dal';

export default async function SettingsPage() {
  await requireAdminSession(['super_admin', 'trust_safety']);
  const [flags, summary, health] = await Promise.all([
    getFeatureFlags(),
    getDashboardSummary(),
    getSystemHealthSnapshot(),
  ]);

  return <SettingsWorkspace flags={flags} summary={summary} health={health} />;
}
