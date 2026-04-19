import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { PaginationControls } from '@/components/ui/pagination-controls';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getAuditEntries } from '@/lib/dal';
import { formatDateTimeLabel } from '@/lib/utils';

type AuditLogPageProps = {
  searchParams?: Promise<{ page?: string }>;
};

export default async function AuditLogPage({
  searchParams,
}: AuditLogPageProps) {
  await requireAdminSession([
    'super_admin',
    'support_ops',
    'clinical_ops',
    'trust_safety',
  ]);
  const params = searchParams ? await searchParams : {};
  const page = Math.max(1, Number(params.page || '1') || 1);
  const result = await getAuditEntries(page);
  const entries = result.items;
  const kpis = [
    {
      label: 'Privileged actions',
      value: entries.length,
      helper: 'Audit records included in the current admin page window.',
    },
    {
      label: 'Actor roles logged',
      value: entries.filter((entry) => entry.actorRoles.length > 0).length,
      helper: 'Entries that recorded at least one actor role for context.',
    },
    {
      label: 'Targeted records',
      value: entries.filter((entry) => entry.targetId).length,
      helper: 'Actions tied to a concrete object ID or operational target.',
    },
    {
      label: 'Metadata-rich',
      value: entries.filter((entry) => Object.keys(entry.metadata).length > 0).length,
      helper: 'Entries that preserved supporting structured context.',
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
            <CardTitle>Audit log</CardTitle>
            <CardDescription>
              Every privileged action should leave a durable paper trail for operational accountability, compliance review, and launch confidence.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          {entries.length === 0 ? (
            <div className="p-6">
              <EmptyState
                title="No audit entries yet"
                description="Privileged operations will appear here as they are recorded by the admin control plane."
              />
            </div>
          ) : (
            <div className="table-wrap">
              <table className="table">
          <thead>
            <tr>
              <th>Action</th>
              <th>Actor</th>
              <th>Target</th>
              <th>Context</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry) => (
              <tr key={entry.id}>
                <td>
                  <strong>{entry.action || 'Unknown action'}</strong>
                  <div className="muted">{entry.id}</div>
                </td>
                <td>
                  {entry.actorEmail || entry.actorId || 'Unknown actor'}
                  <div className="muted">
                    {entry.actorRoles.length ? (
                      <StatusBadge status={entry.actorRoles[0]} />
                    ) : (
                      'No roles recorded'
                    )}
                  </div>
                </td>
                <td>
                  {entry.targetType || 'Unknown'} / {entry.targetId || 'Unknown'}
                </td>
                <td className="muted">
                  <pre className="m-0 whitespace-pre-wrap text-xs leading-6">
                    {JSON.stringify(entry.metadata, null, 2)}
                  </pre>
                </td>
                <td>{formatDateTimeLabel(entry.createdAt)}</td>
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
