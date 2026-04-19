import Link from 'next/link';
import { PrivacyJobOpsForm } from '@/components/privacy/privacy-job-ops-form';
import { buttonStyles } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DetailInfoGrid } from '@/components/ui/detail-info-grid';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getDataRightsJobById } from '@/lib/dal';
import { formatDateTimeLabel } from '@/lib/utils';

type DataRequestDetailPageProps = {
  params: Promise<{ jobId: string }>;
};

function summarizeValue(value: unknown) {
  if (typeof value === 'number' || typeof value === 'string') {
    return String(value);
  }
  if (Array.isArray(value)) {
    return value.join(', ');
  }
  if (typeof value === 'boolean') {
    return value ? 'Yes' : 'No';
  }
  return JSON.stringify(value);
}

export default async function DataRequestDetailPage({
  params,
}: DataRequestDetailPageProps) {
  await requireAdminSession(['super_admin', 'support_ops']);
  const { jobId } = await params;
  const job = await getDataRightsJobById(jobId);

  if (!job) {
    return (
      <Card>
        <CardHeader>
          <div>
            <CardTitle>Privacy job not found</CardTitle>
            <CardDescription>
              The requested export or deletion job could not be loaded.
            </CardDescription>
          </div>
        </CardHeader>
      </Card>
    );
  }

  const initialOpsStatus = ['open', 'acknowledged', 'in_progress', 'closed'].includes(
    job.opsStatus,
  )
    ? (job.opsStatus as 'open' | 'acknowledged' | 'in_progress' | 'closed')
    : 'open';
  const heroKpis = [
    {
      label: 'System status',
      value: job.status.replace(/_/g, ' '),
      helper: 'Current backend lifecycle state for the request.',
    },
    {
      label: 'Ops status',
      value: job.opsStatus.replace(/_/g, ' '),
      helper: 'Manual support workflow state used by the ops team.',
    },
    {
      label: 'Owner',
      value: job.opsOwner || 'Unassigned',
      helper: 'Named person or queue currently accountable for this job.',
    },
    {
      label: 'Result fields',
      value: Object.keys(job.resultSummary).length,
      helper: 'Structured fields returned by the completed secure workflow.',
    },
  ];

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden bg-[linear-gradient(180deg,#ffffff_0%,#f5faff_100%)]">
        <CardContent className="px-6 pb-6 pt-6">
          <div className="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[var(--mg-muted)]">
                <Link href="/support/data-requests" className="transition hover:text-[var(--mg-primary)]">
                  Privacy jobs
                </Link>
                <span>/</span>
                <span>{job.id}</span>
              </div>
              <div>
                <h2 className="text-[2rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                  {job.type.replace(/_/g, ' ')} request
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--mg-muted)]">
                  Requester: {job.requesterDisplayName || job.userId} • {job.requesterEmail || 'No email on file'}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge status={job.status} />
                <StatusBadge status={job.opsStatus} />
                <span className="rounded-full bg-[var(--mg-surface-muted)] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
                  {job.requestSource || 'Unknown source'}
                </span>
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link href="/support/data-requests" className={buttonStyles({ variant: 'outline', size: 'sm' })}>
                Back to privacy jobs
              </Link>
            </div>
          </div>
        </CardContent>
      </Card>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {heroKpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Request metadata</CardTitle>
              <CardDescription>
                Secure workflow context, ownership, and timing for this export or deletion request.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-6">
            <DetailInfoGrid
              items={[
                {
                  label: 'User',
                  value: (
                    <Link href={`/users/${job.userId}`} className="font-semibold text-[var(--mg-heading)] transition hover:text-[var(--mg-primary)]">
                      {job.userId}
                    </Link>
                  ),
                },
                { label: 'Requester role', value: job.requesterRole || 'Unknown' },
                { label: 'Source', value: job.requestSource || 'Unknown' },
                { label: 'Requested at', value: formatDateTimeLabel(job.createdAt) },
                { label: 'Updated at', value: formatDateTimeLabel(job.updatedAt) },
                { label: 'Completed at', value: formatDateTimeLabel(job.completedAt) },
                { label: 'Owner', value: job.opsOwner || 'Unassigned' },
                { label: 'System error', value: job.errorMessage || 'None recorded' },
              ]}
            />

            <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-5">
              <div className="text-sm font-semibold text-[var(--mg-heading)]">Result summary</div>
              {Object.keys(job.resultSummary).length === 0 ? (
                <div className="mt-4">
                  <EmptyState
                    title="No result summary recorded"
                    description="Structured result fields will appear here when the backend secure workflow completes."
                  />
                </div>
              ) : (
                <div className="mt-4 grid gap-3 md:grid-cols-2">
                  {Object.entries(job.resultSummary).map(([key, value]) => (
                    <div
                      key={key}
                      className="rounded-[20px] border border-[var(--mg-border)] bg-white px-4 py-4"
                    >
                      <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                        {key.replace(/([A-Z])/g, ' $1').replace(/_/g, ' ')}
                      </div>
                      <div className="mt-2 text-sm font-semibold leading-6 text-[var(--mg-heading)]">
                        {summarizeValue(value)}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Operations workflow</CardTitle>
              <CardDescription>
                Keep ownership, notes, and closure state on the record so privacy work never lives only in chat or the console.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <PrivacyJobOpsForm
              jobId={job.id}
              initialStatus={initialOpsStatus}
              initialOwner={job.opsOwner}
              initialNotes={job.opsNotes}
            />
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
