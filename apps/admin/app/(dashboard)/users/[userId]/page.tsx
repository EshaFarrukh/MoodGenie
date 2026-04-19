import Link from 'next/link';
import { buttonStyles } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DeleteProfileAction } from '@/components/ui/delete-profile-action';
import { DetailInfoGrid } from '@/components/ui/detail-info-grid';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getUserById } from '@/lib/dal';
import { formatDateLabel, formatDateTimeLabel } from '@/lib/utils';

type UserDetailPageProps = {
  params: Promise<{ userId: string }>;
};

export default async function UserDetailPage({ params }: UserDetailPageProps) {
  const admin = await requireAdminSession(['super_admin', 'support_ops', 'clinical_ops']);
  const { userId } = await params;
  const user = await getUserById(userId);

  if (!user) {
    return (
      <section>
        <Card>
          <CardHeader>
            <div>
              <CardTitle>User not found</CardTitle>
              <CardDescription>
                The requested account no longer exists or cannot be loaded.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <Link href="/users" className={buttonStyles({ variant: 'outline', size: 'sm' })}>
              Back to users
            </Link>
          </CardContent>
        </Card>
      </section>
    );
  }

  const heroKpis = [
    {
      label: 'Mood entries',
      value: user.metrics.moodEntries,
      helper: 'Saved mood check-ins currently associated with this profile.',
    },
    {
      label: 'Appointments',
      value: user.metrics.appointments,
      helper: 'Total sessions requested or completed through the platform.',
    },
    {
      label: 'Active sessions',
      value: user.metrics.activeAppointments,
      helper: 'Appointments still in requested or confirmed states.',
    },
    {
      label: 'Therapist shares',
      value: user.consentedTherapists.length,
      helper: 'Therapists currently approved to access this user’s shared data.',
    },
  ];

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden bg-[linear-gradient(180deg,#ffffff_0%,#f5faff_100%)]">
        <CardContent className="px-6 pb-6 pt-6">
          <div className="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[var(--mg-muted)]">
                <Link href="/users" className="transition hover:text-[var(--mg-primary)]">
                  Users
                </Link>
                <span>/</span>
                <span>{user.id}</span>
              </div>
              <div>
                <h2 className="text-[2rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                  {user.name}
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--mg-muted)]">
                  {user.email || user.id} • Registered {formatDateLabel(user.createdAt)} • Last active {formatDateTimeLabel(user.lastLoginAt)}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge status={user.role} />
                <StatusBadge status={user.consentAccepted ? 'active' : 'warning'} />
                <span className="rounded-full bg-[var(--mg-surface-muted)] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
                  UID {user.id.slice(0, 10)}
                </span>
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link href="/users" className={buttonStyles({ variant: 'outline', size: 'sm' })}>
                Back to users
              </Link>
            </div>
          </div>
        </CardContent>
      </Card>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {heroKpis.map((kpi) => (
          <KpiCard
            key={kpi.label}
            label={kpi.label}
            value={kpi.value}
            helper={kpi.helper}
          />
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Account context</CardTitle>
              <CardDescription>
                Trusted profile diagnostics, consent posture, and platform activity at a glance.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <DetailInfoGrid
              items={[
                {
                  label: 'Created',
                  value: formatDateTimeLabel(user.createdAt),
                },
                {
                  label: 'Last login',
                  value: formatDateTimeLabel(user.lastLoginAt),
                },
                {
                  label: 'Role',
                  value: <StatusBadge status={user.role} />,
                },
                {
                  label: 'Consent',
                  value: user.consentAccepted ? 'Consent on file' : 'Consent missing',
                },
                {
                  label: 'Mood entries',
                  value: user.metrics.moodEntries,
                },
                {
                  label: 'Active appointments',
                  value: user.metrics.activeAppointments,
                },
              ]}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Therapist shares</CardTitle>
              <CardDescription>
                Therapists who currently have a consent-backed sharing relationship with this user.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            {user.consentedTherapists.length === 0 ? (
              <EmptyState
                title="No therapist sharing relationships"
                description="This user has not granted therapist sharing access yet."
              />
            ) : (
              <div className="flex flex-wrap gap-3">
                {user.consentedTherapists.map((therapistId) => (
                  <Link
                    key={therapistId}
                    href={`/therapists/${therapistId}`}
                    className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white"
                  >
                    {therapistId}
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Recent privacy jobs</CardTitle>
              <CardDescription>
                Export and deletion workflows connected to this account.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {user.recentDataRightsJobs.length === 0 ? (
              <EmptyState
                title="No privacy jobs recorded"
                description="There are no export or deletion workflows linked to this account yet."
              />
            ) : (
              user.recentDataRightsJobs.map((job) => (
                <Link
                  href={`/support/data-requests/${job.id}`}
                  className="block rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 transition hover:border-[var(--mg-border-strong)] hover:bg-white"
                  key={job.id}
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {job.type.replace(/_/g, ' ')}
                      </div>
                      <div className="mt-1 text-sm text-[var(--mg-muted)]">
                        Ops state: {job.opsStatus.replace(/_/g, ' ')}
                      </div>
                    </div>
                    <StatusBadge status={job.status} />
                  </div>
                  <div className="mt-3 text-xs uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                    Opened {formatDateTimeLabel(job.createdAt)}
                  </div>
                </Link>
              ))
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Recent appointments</CardTitle>
              <CardDescription>
                Current booking visibility from the user perspective.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {user.recentAppointments.length === 0 ? (
              <EmptyState
                title="No recent appointments"
                description="This user has not booked any recent sessions in the current admin window."
              />
            ) : (
              user.recentAppointments.map((appointment) => (
                <Link
                  href={`/appointments/${appointment.id}`}
                  className="block rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 transition hover:border-[var(--mg-border-strong)] hover:bg-white"
                  key={appointment.id}
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {appointment.therapistName || appointment.therapistId || 'Unknown therapist'}
                      </div>
                      <div className="mt-1 text-sm text-[var(--mg-muted)]">
                        Appointment {appointment.id}
                      </div>
                    </div>
                    <StatusBadge status={appointment.status} />
                  </div>
                  <div className="mt-3 text-xs uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                    Scheduled {formatDateTimeLabel(appointment.scheduledAt)}
                  </div>
                </Link>
              ))
            )}
          </CardContent>
        </Card>
      </section>

      {admin.roles.includes('super_admin') ? (
        <section>
          <Card>
            <CardHeader>
              <div>
                <CardTitle>Danger zone</CardTitle>
                <CardDescription>
                  Permanently remove this user profile and linked platform records.
                </CardDescription>
              </div>
            </CardHeader>
            <CardContent className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <p className="max-w-3xl text-sm leading-6 text-[var(--mg-muted)]">
                This deletes the user account, related appointments, therapist chat rooms,
                call rooms, saved moods, AI chat history, and linked notification data.
              </p>
              <DeleteProfileAction
                entityId={user.id}
                entityLabel={user.name}
                entityType="user"
                redirectHref="/users"
              />
            </CardContent>
          </Card>
        </section>
      ) : null}
    </div>
  );
}
