import Link from 'next/link';
import { notFound } from 'next/navigation';
import { buttonStyles } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DetailInfoGrid } from '@/components/ui/detail-info-grid';
import { EmptyState } from '@/components/ui/empty-state';
import { KpiCard } from '@/components/ui/kpi-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { requireAdminSession } from '@/lib/auth';
import { getAppointmentById } from '@/lib/dal';
import { formatDateTimeLabel } from '@/lib/utils';

type AppointmentDetailPageProps = {
  params: Promise<{ appointmentId: string }>;
};

export default async function AppointmentDetailPage({
  params,
}: AppointmentDetailPageProps) {
  await requireAdminSession([
    'super_admin',
    'support_ops',
    'clinical_ops',
  ]);
  const { appointmentId } = await params;
  const appointment = await getAppointmentById(appointmentId);

  if (!appointment) {
    notFound();
  }

  const heroKpis = [
    {
      label: 'Call readiness',
      value: appointment.canCall ? 'Ready' : 'Blocked',
      helper: 'Whether the session is currently eligible to open a call experience.',
    },
    {
      label: 'Timeline events',
      value: appointment.timeline.length,
      helper: 'Recorded lifecycle events available for operational diagnostics.',
    },
    {
      label: 'Caller ICE',
      value: appointment.communication.callerCandidates,
      helper: 'Collected caller ICE candidates for this session room.',
    },
    {
      label: 'Callee ICE',
      value: appointment.communication.calleeCandidates,
      helper: 'Collected callee ICE candidates for this session room.',
    },
  ];

  return (
    <div className="space-y-6">
      <Card className="overflow-hidden bg-[linear-gradient(180deg,#ffffff_0%,#f5faff_100%)]">
        <CardContent className="px-6 pb-6 pt-6">
          <div className="flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
            <div className="space-y-4">
              <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[var(--mg-muted)]">
                <Link href="/appointments" className="transition hover:text-[var(--mg-primary)]">
                  Bookings
                </Link>
                <span>/</span>
                <span>{appointment.id}</span>
              </div>
              <div>
                <h2 className="text-[2rem] font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                  Appointment overview
                </h2>
                <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--mg-muted)]">
                  Diagnose booking visibility, room readiness, and communication state from one high-trust operational surface.
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge status={appointment.status} />
                <StatusBadge status={appointment.canCall ? 'active' : 'warning'} />
                <span className="rounded-full bg-[var(--mg-surface-muted)] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
                  Scheduled {formatDateTimeLabel(appointment.scheduledAt)}
                </span>
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <Link href="/appointments" className={buttonStyles({ variant: 'outline', size: 'sm' })}>
                Back to bookings
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
              <CardTitle>Booking and participant context</CardTitle>
              <CardDescription>
                Core lifecycle facts, ownership, and participant linking for this appointment.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-6">
            <DetailInfoGrid
              items={[
                { label: 'Appointment ID', value: appointment.id },
                { label: 'Status', value: <StatusBadge status={appointment.status} /> },
                { label: 'Scheduled', value: formatDateTimeLabel(appointment.scheduledAt) },
                { label: 'Created', value: formatDateTimeLabel(appointment.createdAt) },
                { label: 'Last updated', value: formatDateTimeLabel(appointment.updatedAt) },
                { label: 'Updated by', value: appointment.statusUpdatedBy || 'Unknown' },
              ]}
            />
            <div className="grid gap-4 lg:grid-cols-2">
              <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4">
                <div className="text-sm font-semibold text-[var(--mg-heading)]">User</div>
                <div className="mt-3 text-sm leading-6 text-[var(--mg-muted)]">
                  {appointment.userId ? (
                    <Link
                      href={`/users/${appointment.userId}`}
                      className="font-semibold text-[var(--mg-heading)] transition hover:text-[var(--mg-primary)]"
                    >
                      {appointment.userName || appointment.userEmail || appointment.userId}
                    </Link>
                  ) : (
                    'Unknown'
                  )}
                </div>
              </div>
              <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4">
                <div className="text-sm font-semibold text-[var(--mg-heading)]">Therapist</div>
                <div className="mt-3 text-sm leading-6 text-[var(--mg-muted)]">
                  {appointment.therapistId ? (
                    <Link
                      href={`/therapists/${appointment.therapistId}`}
                      className="font-semibold text-[var(--mg-heading)] transition hover:text-[var(--mg-primary)]"
                    >
                      {appointment.therapistName || appointment.therapistEmail || appointment.therapistId}
                    </Link>
                  ) : (
                    'Unknown'
                  )}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Communication diagnostics</CardTitle>
              <CardDescription>
                Validate chat relationship state, room readiness, and WebRTC coordination without digging through raw documents.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            <DetailInfoGrid
              items={[
                { label: 'Relationship type', value: appointment.relationshipType || 'No chat room yet' },
                { label: 'Can call', value: appointment.canCall ? 'Yes' : 'No' },
                { label: 'Chat room', value: appointment.communication.chatRoomId || 'Not created' },
                { label: 'Chat updated', value: formatDateTimeLabel(appointment.communication.chatUpdatedAt) },
                { label: 'Call room', value: appointment.communication.callRoomId || 'Not prepared' },
                { label: 'Call status', value: appointment.communication.callStatus || 'Not prepared' },
                { label: 'Audio only', value: appointment.communication.audioOnly ? 'Yes' : 'No' },
                { label: 'Caller ID', value: appointment.communication.callerId || 'Not started' },
                { label: 'Caller ICE candidates', value: appointment.communication.callerCandidates },
                { label: 'Callee ICE candidates', value: appointment.communication.calleeCandidates },
              ]}
            />
          </CardContent>
        </Card>
      </section>

      <Card>
        <CardHeader>
          <div>
            <CardTitle>Appointment timeline</CardTitle>
            <CardDescription>
              Review the full state progression before debugging mismatched user and therapist visibility.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent className="space-y-3">
          {appointment.timeline.length === 0 ? (
            <EmptyState
              title="No appointment events recorded"
              description="Timeline entries will appear here once lifecycle events are written for this booking."
            />
          ) : (
            appointment.timeline.map((event) => (
              <div
                className="flex items-center justify-between gap-4 rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4"
                key={event.id}
              >
                <div className="text-sm font-semibold text-[var(--mg-heading)]">{event.label}</div>
                <div className="text-xs uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                  {formatDateTimeLabel(event.at)}
                </div>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
