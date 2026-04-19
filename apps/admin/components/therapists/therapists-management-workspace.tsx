'use client';

import Link from 'next/link';
import { Search } from 'lucide-react';
import type { TherapistReviewRow } from '@/lib/types';
import { buildTherapistScore } from '@/lib/admin-portal';
import { buttonStyles } from '@/components/ui/button';
import { DataTable } from '@/components/ui/data-table';
import { EmptyState } from '@/components/ui/empty-state';
import { FilterBar } from '@/components/ui/filter-bar';
import { MetricCard } from '@/components/ui/metric-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { TherapistReviewDialog } from '@/components/therapists/therapist-review-dialog';
import { formatDateLabel } from '@/lib/utils';

export function TherapistsManagementWorkspace({
  therapists,
}: {
  therapists: TherapistReviewRow[];
}) {
  const pendingApprovals = therapists.filter(
    (therapist) => therapist.reviewStatus === 'pending',
  ).length;
  const accepting = therapists.filter((therapist) => therapist.acceptingNewPatients).length;
  const needsVerification = therapists.filter(
    (therapist) => therapist.credentialVerificationStatus !== 'verified',
  ).length;

  return (
    <div className="space-y-5">
      <div className="summary-grid-3">
        <MetricCard
          label="Pending approvals"
          value={pendingApprovals}
          caption="Therapists still waiting on operational review and credential decisioning."
        />
        <MetricCard
          label="Accepting new patients"
          value={accepting}
          caption="Providers whose public profile is still open for intake."
        />
        <MetricCard
          label="Credential follow-up"
          value={needsVerification}
          caption="Providers missing verified credential readiness for marketplace approval."
        />
      </div>

      <FilterBar>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Search
          </span>
          <div className="relative">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--mg-muted)]" />
            <input placeholder="Search by therapist name, email, or specialty" className="pl-11" />
          </div>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Verification
          </span>
          <select defaultValue="all">
            <option value="all">All verification states</option>
            <option value="pending_review">Pending review</option>
            <option value="verified">Verified</option>
            <option value="rejected">Rejected</option>
          </select>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Intake status
          </span>
          <select defaultValue="all">
            <option value="all">All providers</option>
            <option value="accepting">Accepting patients</option>
            <option value="paused">Paused intake</option>
          </select>
        </label>
      </FilterBar>

      <DataTable
        title="Therapist approvals"
        description="Enterprise-grade provider review with credential readiness, operational context, and direct review actions."
      >
        {therapists.length === 0 ? (
          <div className="p-5">
            <EmptyState
              title="No therapists in queue"
              description="The review queue is clear. New provider applications will appear here once submitted."
            />
          </div>
        ) : (
          <table className="table min-w-[1160px]">
            <thead>
              <tr>
                <th>Therapist</th>
                <th>Verification</th>
                <th>Review status</th>
                <th>Sessions</th>
                <th>Rating</th>
                <th>Utilization</th>
                <th>Last review</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {therapists.map((therapist) => {
                const score = buildTherapistScore(therapist);
                return (
                  <tr key={therapist.id}>
                    <td>
                      <div className="space-y-1">
                        <div className="text-sm font-semibold text-[var(--mg-heading)]">
                          {therapist.name}
                        </div>
                        <div className="text-sm text-[var(--mg-muted)]">
                          {therapist.email || 'No email'} •{' '}
                          {therapist.specialty || 'Specialty pending'}
                        </div>
                        <div className="text-xs text-[var(--mg-muted)]">
                          {therapist.yearsExperience ?? 'Experience not provided'} years •{' '}
                          {therapist.acceptingNewPatients ? 'Accepting patients' : 'Intake paused'}
                        </div>
                      </div>
                    </td>
                    <td>
                      <StatusBadge status={therapist.credentialVerificationStatus} />
                    </td>
                    <td>
                      <StatusBadge status={therapist.reviewStatus} />
                    </td>
                    <td>
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {score.sessions}
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">recent sessions</div>
                    </td>
                    <td>
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {score.rating}
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">patient satisfaction</div>
                    </td>
                    <td>
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {score.utilization}%
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">calendar utilization</div>
                    </td>
                    <td>
                      <div className="text-sm font-medium text-[var(--mg-heading)]">
                        {formatDateLabel(therapist.reviewedAt)}
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">
                        by {therapist.reviewedBy || 'Unassigned'}
                      </div>
                    </td>
                    <td>
                      <div className="flex flex-wrap gap-2">
                        <Link
                          href={`/therapists/${therapist.id}`}
                          className={buttonStyles({ variant: 'outline', size: 'sm' })}
                        >
                          License details
                        </Link>
                        <TherapistReviewDialog
                          therapistId={therapist.id}
                          therapistName={therapist.name}
                        />
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </DataTable>
    </div>
  );
}
