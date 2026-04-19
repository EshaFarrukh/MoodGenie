'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { Search, ShieldAlert } from 'lucide-react';
import type { IncidentRow } from '@/lib/types';
import { buildIncidentResolutionPreview } from '@/lib/admin-portal';
import { buttonStyles } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { DataTable } from '@/components/ui/data-table';
import { EmptyState } from '@/components/ui/empty-state';
import { FilterBar } from '@/components/ui/filter-bar';
import { StatusBadge } from '@/components/ui/status-badge';
import { formatDateTimeLabel } from '@/lib/utils';

export function IncidentsWorkspace({ incidents }: { incidents: IncidentRow[] }) {
  const [query, setQuery] = useState('');
  const [severity, setSeverity] = useState('all');
  const [status, setStatus] = useState('all');

  const filteredIncidents = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return incidents.filter((incident) => {
      const matchesQuery =
        normalized.length === 0 ||
        incident.title.toLowerCase().includes(normalized) ||
        (incident.category || '').toLowerCase().includes(normalized) ||
        incident.id.toLowerCase().includes(normalized);
      const matchesSeverity = severity === 'all' || incident.severity === severity;
      const matchesStatus = status === 'all' || incident.status === status;
      return matchesQuery && matchesSeverity && matchesStatus;
    });
  }, [incidents, query, severity, status]);

  const crisisAlerts = incidents.filter((incident) =>
    (incident.category || '').toLowerCase().includes('crisis'),
  ).length;
  const unsafeAi = incidents.filter((incident) =>
    !(incident.category || '').toLowerCase().includes('crisis') &&
    !(incident.category || '').toLowerCase().includes('complaint'),
  ).length;
  const complaints = incidents.filter((incident) =>
    (incident.category || '').toLowerCase().includes('complaint'),
  ).length;

  return (
    <div className="space-y-5">
      <div className="summary-grid-4">
        {[
          ['Crisis alerts', crisisAlerts],
          ['Unsafe AI', unsafeAi],
          ['Manual complaints', complaints],
          ['Open flags', incidents.filter((incident) => incident.status !== 'resolved').length],
        ].map(([label, value]) => (
          <Card key={label}>
            <CardContent className="p-4">
              <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                {label}
              </div>
              <div className="mt-2 text-[1.8rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                {value}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <FilterBar>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Search
          </span>
          <div className="relative">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--mg-muted)]" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search incident title, category, or ID"
              className="pl-11"
            />
          </div>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Severity
          </span>
          <select value={severity} onChange={(event) => setSeverity(event.target.value)}>
            <option value="all">All severities</option>
            <option value="critical">Critical</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Workflow status
          </span>
          <select value={status} onChange={(event) => setStatus(event.target.value)}>
            <option value="all">All statuses</option>
            <option value="open">Open</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="in_progress">In progress</option>
            <option value="resolved">Resolved</option>
          </select>
        </label>
      </FilterBar>

      <DataTable
        title="Incident flags"
        description="Severity-driven review flow for crisis alerts, unsafe AI interactions, and manual complaints."
      >
        {filteredIncidents.length === 0 ? (
          <div className="p-5">
            <EmptyState
              title="No incident flags match this filter"
              description="Try a broader severity or status scope to restore the live incident queue."
            />
          </div>
        ) : (
          <table className="table min-w-[1180px]">
            <thead>
              <tr>
                <th>Flag</th>
                <th>Severity</th>
                <th>Status</th>
                <th>Reviewer</th>
                <th>Created</th>
                <th>Resolution notes</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredIncidents.map((incident) => (
                <tr key={incident.id}>
                  <td>
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <ShieldAlert className="h-4 w-4 text-[var(--mg-primary)]" />
                        <span className="text-sm font-semibold text-[var(--mg-heading)]">
                          {incident.title}
                        </span>
                      </div>
                      <div className="text-sm text-[var(--mg-muted)]">
                        {incident.category || 'General'} • {incident.source || 'System'}
                      </div>
                    </div>
                  </td>
                  <td>
                    <StatusBadge status={incident.severity} />
                  </td>
                  <td>
                    <StatusBadge status={incident.status} />
                  </td>
                  <td>
                    <div className="text-sm font-medium text-[var(--mg-heading)]">
                      {incident.assignedTo || 'Unassigned'}
                    </div>
                    <div className="text-xs text-[var(--mg-muted)]">
                      user {incident.userId || 'unlinked'}
                    </div>
                  </td>
                  <td>{formatDateTimeLabel(incident.createdAt)}</td>
                  <td>
                    <div className="max-w-xs text-sm leading-6 text-[var(--mg-muted)]">
                      {buildIncidentResolutionPreview(incident)}
                    </div>
                  </td>
                  <td>
                    <Link
                      href={`/ai-ops/incidents/${incident.id}`}
                      className={buttonStyles({ variant: 'outline', size: 'sm' })}
                    >
                      Review case
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </DataTable>
    </div>
  );
}
