import Link from 'next/link';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { PaginationControls } from '@/components/ui/pagination-controls';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getDataRightsJobs } from '@/lib/dal';
import { formatDateTimeLabel } from '@/lib/utils';

type DataRequestsPageProps = {
  searchParams?: Promise<{ page?: string }>;
};

export default async function DataRequestsPage({
  searchParams,
}: DataRequestsPageProps) {
  await requireAdminSession(['super_admin', 'support_ops']);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getDataRightsJobs(page);
  const jobs = result.items;
  const kpis = [
    {
      label: 'Open ops queue',
      value: jobs.filter((job) => job.opsStatus === 'open').length,
      helper: 'Privacy requests still waiting on first operational touch.',
    },
    {
      label: 'In progress',
      value: jobs.filter((job) => job.opsStatus === 'in_progress').length,
      helper: 'Requests currently moving through privacy operations.',
    },
    {
      label: 'System failures',
      value: jobs.filter((job) => job.status === 'failed').length,
      helper: 'Jobs with platform-level failure that still need follow-up.',
    },
    {
      label: 'Completed',
      value: jobs.filter((job) => job.status === 'completed').length,
      helper: 'Requests already fulfilled successfully.',
    },
  ];

  return (
    <section className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </div>

      <Card>
        <CardHeader>
          <div>
            <CardTitle>Privacy jobs</CardTitle>
            <CardDescription>
              Track export and deletion workflows with clear ownership, live state, and audit-friendly operational visibility.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          {jobs.length === 0 ? (
            <div className="p-6">
              <EmptyState
                title="No privacy jobs yet"
                description="Export and deletion workflows will appear here once they are created from the app or support operations."
              />
            </div>
          ) : (
            <div className="table-wrap">
              <table className="table">
          <thead>
            <tr>
              <th>Job</th>
              <th>User</th>
              <th>Type</th>
              <th>System Status</th>
              <th>Ops Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((job) => (
              <tr key={job.id}>
                <td>
                  <strong>
                    <Link href={`/support/data-requests/${job.id}`}>{job.id}</Link>
                  </strong>
                  <div className="muted">
                    {job.requesterDisplayName || job.requesterEmail || 'Unknown requester'}
                  </div>
                </td>
                <td>
                  <Link href={`/users/${job.userId}`}>{job.userId}</Link>
                </td>
                <td>{job.type.replace(/_/g, ' ')}</td>
                <td>
                  <StatusBadge status={job.status} />
                </td>
                <td>
                  <StatusBadge status={job.opsStatus} />
                </td>
                <td>{formatDateTimeLabel(job.createdAt)}</td>
              </tr>
            ))}
          </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
      <PaginationControls
        page={result.page}
        hasNextPage={result.hasNextPage}
        searchParams={{ page: params.page }}
      />
    </section>
  );
}
