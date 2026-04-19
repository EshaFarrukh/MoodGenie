'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { CalendarDays, LayoutList, Search } from 'lucide-react';
import type { AppointmentRow } from '@/lib/types';
import { buildSessionStatusCounts } from '@/lib/admin-portal';
import { Button, buttonStyles } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { DataTable } from '@/components/ui/data-table';
import { Dialog } from '@/components/ui/dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { FilterBar } from '@/components/ui/filter-bar';
import { StatusBadge } from '@/components/ui/status-badge';
import { formatDateTimeLabel } from '@/lib/utils';

type BookingsWorkspaceProps = {
  appointments: AppointmentRow[];
};

export function BookingsWorkspace({ appointments }: BookingsWorkspaceProps) {
  const [view, setView] = useState<'list' | 'calendar'>('list');
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState<AppointmentRow | null>(null);

  const filteredAppointments = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return appointments.filter((appointment) => {
      if (!normalized) {
        return true;
      }
      return [appointment.id, appointment.userName, appointment.userId, appointment.therapistName, appointment.therapistId]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(normalized));
    });
  }, [appointments, query]);

  const counts = buildSessionStatusCounts(appointments);
  const groupedByDay = useMemo(() => {
    const groups = new Map<string, AppointmentRow[]>();

    filteredAppointments.forEach((appointment) => {
      const key = appointment.scheduledAt
        ? formatDateTimeLabel(appointment.scheduledAt).split(',')[0]
        : 'Unscheduled';
      groups.set(key, [...(groups.get(key) || []), appointment]);
    });

    return Array.from(groups.entries());
  }, [filteredAppointments]);

  return (
    <div className="space-y-5">
      <div className="summary-grid-6">
        {[
          ['Requested', counts.requested],
          ['Confirmed', counts.confirmed],
          ['Completed', counts.completed],
          ['Cancelled', counts.cancelled],
          ['Rejected', counts.rejected],
          ['No show', counts.noShow],
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

      <FilterBar
        actions={
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant={view === 'list' ? 'primary' : 'outline'}
              size="sm"
              onClick={() => setView('list')}
            >
              <LayoutList className="h-4 w-4" />
              List
            </Button>
            <Button
              type="button"
              variant={view === 'calendar' ? 'primary' : 'outline'}
              size="sm"
              onClick={() => setView('calendar')}
            >
              <CalendarDays className="h-4 w-4" />
              Calendar
            </Button>
          </div>
        }
      >
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Search bookings
          </span>
          <div className="relative">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--mg-muted)]" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search therapist, user, or session ID"
              className="pl-11"
            />
          </div>
        </label>
      </FilterBar>

      {filteredAppointments.length === 0 ? (
        <EmptyState
          title="No bookings match this view"
          description="Try another search term or switch status filters to broaden the operational timeline."
        />
      ) : view === 'list' ? (
        <DataTable
          title="Bookings and sessions"
          description="Visibility into upcoming sessions, cancellations, completion flow, and communication readiness."
        >
          <table className="table min-w-[1120px]">
            <thead>
              <tr>
                <th>Session</th>
                <th>Status</th>
                <th>Scheduled</th>
                <th>User</th>
                <th>Therapist</th>
                <th>Room</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredAppointments.map((appointment) => (
                <tr key={appointment.id}>
                  <td>
                    <div className="space-y-1">
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {appointment.id}
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">
                        Updated {formatDateTimeLabel(appointment.updatedAt)}
                      </div>
                    </div>
                  </td>
                  <td>
                    <StatusBadge status={appointment.status} />
                  </td>
                  <td>{formatDateTimeLabel(appointment.scheduledAt)}</td>
                  <td>{appointment.userName || appointment.userId || 'Unknown user'}</td>
                  <td>
                    {appointment.therapistName || appointment.therapistId || 'Unknown therapist'}
                  </td>
                  <td>{appointment.meetingRoomId || 'Not prepared'}</td>
                  <td>
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        className={buttonStyles({ variant: 'outline', size: 'sm' })}
                        onClick={() => setSelected(appointment)}
                      >
                        View details
                      </button>
                      <Link
                        href={`/appointments/${appointment.id}`}
                        className={buttonStyles({ variant: 'ghost', size: 'sm' })}
                      >
                        Open record
                      </Link>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </DataTable>
      ) : (
        <div className="grid gap-3.5 xl:grid-cols-3">
          {groupedByDay.map(([day, items]) => (
            <Card key={day}>
              <CardContent className="space-y-4 p-4">
                <div>
                  <div className="text-sm font-semibold text-[var(--mg-heading)]">{day}</div>
                  <div className="text-xs text-[var(--mg-muted)]">
                    {items.length} scheduled sessions
                  </div>
                </div>
                {items.map((appointment) => (
                  <button
                    key={appointment.id}
                    type="button"
                    className="w-full rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-left transition hover:border-[var(--mg-border-strong)] hover:bg-white"
                    onClick={() => setSelected(appointment)}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-[var(--mg-heading)]">
                          {appointment.therapistName || appointment.id}
                        </div>
                        <div className="mt-1 text-sm text-[var(--mg-muted)]">
                          {appointment.userName || appointment.userId || 'Unknown user'}
                        </div>
                      </div>
                      <StatusBadge status={appointment.status} />
                    </div>
                    <div className="mt-3 text-xs text-[var(--mg-muted)]">
                      {formatDateTimeLabel(appointment.scheduledAt)}
                    </div>
                  </button>
                ))}
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Dialog
        open={selected !== null}
        onClose={() => setSelected(null)}
        title={selected ? `Booking ${selected.id}` : 'Booking detail'}
        description="Inspect the session state, assigned participants, and room readiness from a lightweight modal view."
        size="md"
      >
        {selected ? (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4">
                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                  Status
                </div>
                <div className="mt-3">
                  <StatusBadge status={selected.status} />
                </div>
              </div>
              <div className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4">
                <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                  Meeting room
                </div>
                <div className="mt-3 text-sm font-semibold text-[var(--mg-heading)]">
                  {selected.meetingRoomId || 'Not prepared'}
                </div>
              </div>
            </div>
            <div className="detail-list">
              <div>
                <span className="muted">Scheduled at</span>
                <strong>{formatDateTimeLabel(selected.scheduledAt)}</strong>
              </div>
              <div>
                <span className="muted">User</span>
                <strong>{selected.userName || selected.userId || 'Unknown user'}</strong>
              </div>
              <div>
                <span className="muted">Therapist</span>
                <strong>
                  {selected.therapistName || selected.therapistId || 'Unknown therapist'}
                </strong>
              </div>
            </div>
            <div className="flex justify-end">
              <Link
                href={`/appointments/${selected.id}`}
                className={buttonStyles({ variant: 'primary', size: 'sm' })}
              >
                Open full session record
              </Link>
            </div>
          </div>
        ) : null}
      </Dialog>
    </div>
  );
}
