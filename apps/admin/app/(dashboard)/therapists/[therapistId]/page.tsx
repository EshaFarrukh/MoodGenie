import Link from 'next/link';
import { TherapistDecisionForm } from '@/components/therapists/decision-form';
import { buttonStyles } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DeleteProfileAction } from '@/components/ui/delete-profile-action';
import { DetailInfoGrid } from '@/components/ui/detail-info-grid';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getTherapistById } from '@/lib/dal';
import { formatDateLabel, formatDateTimeLabel } from '@/lib/utils';

type TherapistDetailPageProps = {
  params: Promise<{ therapistId: string }>;
};

export default async function TherapistDetailPage({
  params,
}: TherapistDetailPageProps) {
  const admin = await requireAdminSession([
    'super_admin',
    'clinical_ops',
    'support_ops',
  ]);
  const { therapistId } = await params;
  const therapist = await getTherapistById(therapistId);

  if (!therapist) {
    return (
      <Card>
        <CardHeader>
          <div>
            <CardTitle>Therapist not found</CardTitle>
            <CardDescription>
              The requested therapist profile no longer exists or cannot be loaded.
            </CardDescription>
          </div>
        </CardHeader>
      </Card>
    );
  }

  const canReview = admin.roles.some((role) =>
    ['super_admin', 'clinical_ops'].includes(role),
  );
  const canViewCredentialDetails = admin.roles.some((role) =>
    ['super_admin', 'clinical_ops'].includes(role),
  );
  const heroKpis = [
    {
      label: 'Appointments',
      value: therapist.metrics.appointments,
      helper: 'Total tracked sessions associated with this therapist.',
    },
    {
      label: 'Confirmed',
      value: therapist.metrics.confirmedAppointments,
      helper: 'Sessions confirmed and waiting on completion.',
    },
    {
      label: 'Completed',
      value: therapist.metrics.completedAppointments,
      helper: 'Completed sessions already closed out operationally.',
    },
    {
      label: 'Approval blockers',
      value: therapist.approvalBlockers.length,
      helper: 'Credential fields still missing before approval can clear.',
    },
  ];

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden bg-[linear-gradient(180deg,#ffffff_0%,#f5faff_100%)]">
        <CardContent className="px-6 pb-6 pt-6">
          <div className="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[var(--mg-muted)]">
                <Link href="/therapists/review-queue" className="transition hover:text-[var(--mg-primary)]">
                  Therapist review
                </Link>
                <span>/</span>
                <span>{therapist.id}</span>
              </div>
              <div>
                <h2 className="text-[2rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                  {therapist.name}
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--mg-muted)]">
                  {therapist.email || 'No email on file'} • {therapist.professionalTitle || 'Professional title not provided'} • {therapist.specialty || 'Specialty not provided'} • {therapist.yearsExperience ?? 'Experience not provided'} years
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge status={therapist.reviewStatus} />
                <StatusBadge status={therapist.accountStatus} />
                <StatusBadge status={therapist.credentialVerificationStatus} />
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link
                href="/therapists/review-queue"
                className={buttonStyles({ variant: 'outline', size: 'sm' })}
              >
                Back to queue
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
              <CardTitle>Operational profile</CardTitle>
              <CardDescription>
                Review posture, account readiness, and provider-facing presentation from one surface.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-6">
            <DetailInfoGrid
              items={[
                { label: 'Created', value: formatDateTimeLabel(therapist.createdAt) },
                { label: 'Last reviewed', value: formatDateTimeLabel(therapist.reviewedAt) },
                { label: 'Reviewed by', value: therapist.reviewedBy || 'Unassigned' },
                { label: 'Accepting new patients', value: therapist.acceptingNewPatients ? 'Yes' : 'No' },
                { label: 'Verification method', value: therapist.verificationMethod || 'Missing' },
                { label: 'Verification reference', value: therapist.verificationReference || 'Missing' },
              ]}
            />

            <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-5">
              <div className="text-sm font-semibold text-[var(--mg-heading)]">Current review note</div>
              <p className="mt-3 text-sm leading-6 text-[var(--mg-muted)]">
                {therapist.reviewNotes || 'No operational review note has been saved for this therapist yet.'}
              </p>
            </div>

            <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-5">
              <div className="text-sm font-semibold text-[var(--mg-heading)]">Public profile snapshot</div>
              <div className="mt-4 grid gap-3">
                <div>
                  <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                    Display name
                  </div>
                  <div className="mt-1 text-sm font-semibold text-[var(--mg-heading)]">
                    {therapist.displayName || therapist.name}
                  </div>
                </div>
                <div>
                  <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                    Professional title
                  </div>
                  <div className="mt-1 text-sm font-semibold text-[var(--mg-heading)]">
                    {therapist.professionalTitle || 'Not provided'}
                  </div>
                </div>
                <div>
                  <div className="text-[11px] font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                    Bio
                  </div>
                  <p className="mt-1 text-sm leading-6 text-[var(--mg-muted)]">
                    {therapist.bio || 'Not provided'}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <div className="space-y-6">
          {canReview ? (
            <Card>
              <CardHeader>
                <div>
                  <CardTitle>Review decision</CardTitle>
                  <CardDescription>
                    Approvals, rejections, and suspensions are audited immediately and change the therapist’s public posture.
                  </CardDescription>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                {therapist.approvalBlockers.length > 0 ? (
                  <div className="rounded-[22px] border border-[rgba(245,158,11,0.26)] bg-[rgba(245,158,11,0.08)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]">
                    Approval is blocked until these credential fields are complete: {therapist.approvalBlockers.join(', ')}.
                  </div>
                ) : (
                  <div className="rounded-[22px] border border-[rgba(48,163,115,0.22)] bg-[rgba(48,163,115,0.08)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]">
                    Credential review requirements are complete. Add your reviewer note and verification reference to finalize the decision.
                  </div>
                )}
                <TherapistDecisionForm therapistId={therapist.id} />
              </CardContent>
            </Card>
          ) : null}

          <Card>
            <CardHeader>
              <div>
                <CardTitle>Credential review file</CardTitle>
                <CardDescription>
                  License evidence and verification trail for clinician-facing reviewers.
                </CardDescription>
              </div>
            </CardHeader>
            <CardContent>
              {canViewCredentialDetails ? (
                <DetailInfoGrid
                  items={[
                    { label: 'License number', value: therapist.licenseNumber || 'Missing' },
                    { label: 'Licensing authority', value: therapist.licenseIssuingAuthority || 'Missing' },
                    { label: 'License region', value: therapist.licenseRegion || 'Missing' },
                    { label: 'License expiry', value: formatDateLabel(therapist.licenseExpiresAt) },
                    { label: 'Submitted', value: formatDateTimeLabel(therapist.credentialSubmittedAt) },
                    { label: 'Verified at', value: formatDateTimeLabel(therapist.credentialVerifiedAt) },
                    { label: 'Verified by', value: therapist.credentialVerifiedBy || 'Unassigned' },
                    { label: 'Evidence summary', value: therapist.credentialEvidenceSummary || 'Missing' },
                  ]}
                />
              ) : (
                <EmptyState
                  title="Credential details restricted"
                  description="These details are limited to clinical reviewers and super-admins."
                />
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div>
                <CardTitle>Review history</CardTitle>
                <CardDescription>
                  Durable decision trail across prior approvals, rejections, and operational suspensions.
                </CardDescription>
              </div>
            </CardHeader>
            <CardContent className="space-y-3">
              {therapist.history.length === 0 ? (
                <EmptyState
                  title="No review events recorded"
                  description="Review history will appear here once operational decisions are saved."
                />
              ) : (
                therapist.history.map((entry) => (
                  <div
                    className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4"
                    key={entry.id}
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <div className="text-sm font-semibold text-[var(--mg-heading)]">
                          {entry.reviewedBy || 'Unknown reviewer'}
                        </div>
                        <div className="mt-1 text-sm text-[var(--mg-muted)]">
                          {entry.reviewerRoles.join(', ') || 'Unknown roles'}
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-2">
                        <StatusBadge status={entry.decision} />
                        <span className="text-xs uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                          {formatDateTimeLabel(entry.reviewedAt)}
                        </span>
                      </div>
                    </div>
                    <p className="mt-3 text-sm leading-6 text-[var(--mg-muted)]">
                      {entry.notes || 'No notes provided.'}
                    </p>
                  </div>
                ))
              )}
            </CardContent>
          </Card>

          {admin.roles.includes('super_admin') ? (
            <Card>
              <CardHeader>
                <div>
                  <CardTitle>Danger zone</CardTitle>
                  <CardDescription>
                    Permanently remove this therapist profile and linked operational records.
                  </CardDescription>
                </div>
              </CardHeader>
              <CardContent className="flex flex-col gap-4">
                <p className="text-sm leading-6 text-[var(--mg-muted)]">
                  This removes the therapist account, public directory profile, appointments,
                  therapist chats, call rooms, availability slots, and linked user profile data.
                </p>
                <div className="flex justify-end">
                  <DeleteProfileAction
                    entityId={therapist.id}
                    entityLabel={therapist.name}
                    entityType="therapist"
                    redirectHref="/therapists/review-queue"
                  />
                </div>
              </CardContent>
            </Card>
          ) : null}
        </div>
      </section>
    </div>
  );
}
