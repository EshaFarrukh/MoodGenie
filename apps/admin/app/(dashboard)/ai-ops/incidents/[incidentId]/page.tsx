import Link from 'next/link';
import { notFound } from 'next/navigation';
import { IncidentOpsForm } from '@/components/ai/incident-ops-form';
import { buttonStyles } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DetailInfoGrid } from '@/components/ui/detail-info-grid';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getAIIncidentById } from '@/lib/dal';
import { formatDateTimeLabel } from '@/lib/utils';

type AIIncidentDetailPageProps = {
  params: Promise<{ incidentId: string }>;
};

export default async function AIIncidentDetailPage({
  params,
}: AIIncidentDetailPageProps) {
  const admin = await requireAdminSession([
    'super_admin',
    'trust_safety',
    'support_ops',
  ]);
  const { incidentId } = await params;
  const incident = await getAIIncidentById(incidentId);
  const canManageIncident = admin.roles.some((role) =>
    ['super_admin', 'trust_safety', 'support_ops'].includes(role),
  );

  if (!incident) {
    notFound();
  }

  const heroKpis = [
    {
      label: 'Severity',
      value: incident.severity.replace(/_/g, ' '),
      helper: 'Priority level currently assigned to this incident.',
    },
    {
      label: 'Status',
      value: incident.status.replace(/_/g, ' '),
      helper: 'Current operational workflow stage.',
    },
    {
      label: 'Assigned reviewer',
      value: incident.assignedTo || 'Unassigned',
      helper: 'Owner accountable for driving the case forward.',
    },
    {
      label: 'Affected user',
      value: incident.userName || incident.userEmail || incident.userId || 'Not linked',
      helper: 'The user currently linked to this incident case.',
    },
  ];

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden bg-[linear-gradient(180deg,#ffffff_0%,#f5faff_100%)]">
        <CardContent className="px-6 pb-6 pt-6">
          <div className="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[var(--mg-muted)]">
                <Link href="/ai-ops/incidents" className="transition hover:text-[var(--mg-primary)]">
                  Incident Flags
                </Link>
                <span>/</span>
                <span>{incident.id}</span>
              </div>
              <div>
                <h2 className="text-[2rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                  {incident.title}
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--mg-muted)]">
                  Investigate user impact, assign ownership, and document the operational response in one trusted incident workspace.
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge status={incident.severity} />
                <StatusBadge status={incident.status} />
                <span className="rounded-full bg-[var(--mg-surface-muted)] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
                  {incident.category || 'General'}
                </span>
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link href="/ai-ops/incidents" className={buttonStyles({ variant: 'outline', size: 'sm' })}>
                Back to incidents
              </Link>
            </div>
          </div>
        </CardContent>
      </Card>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {heroKpis.map((kpi) => (
          <KpiCard key={kpi.label} label={kpi.label} value={kpi.value} helper={kpi.helper} />
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Incident context</CardTitle>
              <CardDescription>
                Core evidence, timestamps, and affected-account linkage for this safety case.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <DetailInfoGrid
              items={[
                { label: 'Incident ID', value: incident.id },
                { label: 'Severity', value: <StatusBadge status={incident.severity} /> },
                { label: 'Status', value: <StatusBadge status={incident.status} /> },
                { label: 'Category', value: incident.category || 'General' },
                { label: 'Source', value: incident.source || 'Unknown' },
                { label: 'Created', value: formatDateTimeLabel(incident.createdAt) },
                { label: 'Updated', value: formatDateTimeLabel(incident.updatedAt) },
                { label: 'Assigned to', value: incident.assignedTo || 'Unassigned' },
                {
                  label: 'Affected user',
                  value: incident.userId ? (
                    <Link
                      href={`/users/${incident.userId}`}
                      className="font-semibold text-[var(--mg-heading)] transition hover:text-[var(--mg-primary)]"
                    >
                      {incident.userName || incident.userEmail || incident.userId}
                    </Link>
                  ) : (
                    'Not linked'
                  ),
                },
              ]}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Ops controls</CardTitle>
              <CardDescription>
                Acknowledge, assign, and close the incident with a visible operational trail.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            {canManageIncident ? (
              <IncidentOpsForm
                incidentId={incident.id}
                currentStatus={
                  incident.status as
                    | 'open'
                    | 'acknowledged'
                    | 'in_progress'
                    | 'resolved'
                }
                currentAssignee={incident.assignedTo}
                currentNotes={incident.opsNotes}
              />
            ) : (
              <EmptyState
                title="Role cannot manage incident"
                description="This role can review incident evidence but cannot change ownership or status."
              />
            )}
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.85fr_1.15fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Operational notes</CardTitle>
              <CardDescription>
                Human review, impact summary, and workaround context for the case.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            {incident.opsNotes ? (
              <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-5">
                <p className="text-sm leading-7 text-[var(--mg-muted)]">{incident.opsNotes}</p>
              </div>
            ) : (
              <EmptyState
                title="No operational notes yet"
                description="Ops notes will appear here once a reviewer documents the incident response."
              />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Incident metadata</CardTitle>
              <CardDescription>
                Raw evidence preserved for trust-and-safety review and deeper backend debugging.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <pre className="overflow-x-auto rounded-[24px] border border-[var(--mg-border)] bg-[#0b2442] p-5 text-xs leading-6 text-[#eef7ff]">
              {JSON.stringify(incident.metadata, null, 2)}
            </pre>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
