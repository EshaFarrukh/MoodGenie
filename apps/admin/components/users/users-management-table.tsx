'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { Search, SlidersHorizontal } from 'lucide-react';
import type { UserRow } from '@/lib/types';
import { buildUserMoodActivity } from '@/lib/admin-portal';
import { Button, buttonStyles } from '@/components/ui/button';
import { ConfirmActionButton } from '@/components/ui/confirm-action-button';
import { DataTable } from '@/components/ui/data-table';
import { EmptyState } from '@/components/ui/empty-state';
import { FilterBar } from '@/components/ui/filter-bar';
import { MetricCard } from '@/components/ui/metric-card';
import { StatusBadge } from '@/components/ui/status-badge';
import { formatDateLabel } from '@/lib/utils';

type UsersManagementTableProps = {
  users: UserRow[];
};

export function UsersManagementTable({ users }: UsersManagementTableProps) {
  const [query, setQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [consentFilter, setConsentFilter] = useState('all');

  const filteredUsers = useMemo(() => {
    return users.filter((user) => {
      const normalizedQuery = query.trim().toLowerCase();
      const matchesQuery =
        normalizedQuery.length === 0 ||
        user.name.toLowerCase().includes(normalizedQuery) ||
        (user.email || '').toLowerCase().includes(normalizedQuery) ||
        user.id.toLowerCase().includes(normalizedQuery);

      const matchesRole =
        roleFilter === 'all' || user.role.toLowerCase() === roleFilter.toLowerCase();
      const matchesConsent =
        consentFilter === 'all' ||
        (consentFilter === 'accepted' ? user.consentAccepted : !user.consentAccepted);

      return matchesQuery && matchesRole && matchesConsent;
    });
  }, [consentFilter, query, roleFilter, users]);

  const activeUsers = users.filter((user) => buildUserMoodActivity(user).weeklyLogs >= 4).length;

  return (
    <div className="space-y-5">
      <div className="summary-grid-3">
        <MetricCard
          label="Total profiles"
          value={users.length}
          caption="Accounts available in the current admin result set."
        />
        <MetricCard
          label="Active mood logging"
          value={activeUsers}
          caption="Users showing healthy mood check-in cadence this week."
        />
        <MetricCard
          label="Consent missing"
          value={users.filter((user) => !user.consentAccepted).length}
          caption="Profiles that still need privacy consent attention before therapist sharing."
        />
      </div>

      <FilterBar
        actions={
          <Button type="button" variant="outline" size="sm">
            <SlidersHorizontal className="h-4 w-4" />
            Filters applied
          </Button>
        }
      >
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Search
          </span>
          <div className="relative">
            <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--mg-muted)]" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search name, email, or UID"
              className="pl-11"
            />
          </div>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Role
          </span>
          <select value={roleFilter} onChange={(event) => setRoleFilter(event.target.value)}>
            <option value="all">All roles</option>
            <option value="user">User</option>
            <option value="therapist">Therapist</option>
            <option value="admin">Admin</option>
          </select>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Consent
          </span>
          <select
            value={consentFilter}
            onChange={(event) => setConsentFilter(event.target.value)}
          >
            <option value="all">All</option>
            <option value="accepted">Accepted</option>
            <option value="missing">Missing</option>
          </select>
        </label>
      </FilterBar>

      <DataTable
        title="User management"
        description="Premium, high-trust user oversight with clear activity summaries, consent posture, and moderation actions."
      >
        {filteredUsers.length === 0 ? (
          <div className="p-5">
            <EmptyState
              title="No users match these filters"
              description="Try widening the search or resetting the current role and consent filters."
            />
          </div>
        ) : (
          <table className="table min-w-[1080px]">
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Status</th>
                <th>Registration</th>
                <th>Mood activity</th>
                <th>Therapist shares</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((user) => {
                const moodActivity = buildUserMoodActivity(user);
                return (
                  <tr key={user.id}>
                    <td>
                      <div className="space-y-1">
                        <Link
                          href={`/users/${user.id}`}
                          className="text-sm font-semibold text-[var(--mg-heading)] hover:text-[var(--mg-primary)]"
                        >
                          {user.name}
                        </Link>
                        <div className="text-sm text-[var(--mg-muted)]">
                          {user.email || user.id}
                        </div>
                      </div>
                    </td>
                    <td>
                      <StatusBadge status={user.role} />
                    </td>
                    <td>
                      <div className="space-y-2">
                        <StatusBadge status={user.consentAccepted ? 'active' : 'warning'} />
                        <div className="text-xs text-[var(--mg-muted)]">
                          {user.consentAccepted ? 'Consent on file' : 'Consent missing'}
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="text-sm font-medium text-[var(--mg-heading)]">
                        {formatDateLabel(user.createdAt)}
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">
                        Last login {formatDateLabel(user.lastLoginAt)}
                      </div>
                    </td>
                    <td>
                      <div className="space-y-1">
                        <div className="text-sm font-semibold text-[var(--mg-heading)]">
                          {moodActivity.weeklyLogs} logs / week
                        </div>
                        <div className="text-xs text-[var(--mg-muted)]">
                          {moodActivity.streak}-day streak • {moodActivity.sentiment}
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="text-sm font-semibold text-[var(--mg-heading)]">
                        {user.consentedTherapistsCount}
                      </div>
                      <div className="text-xs text-[var(--mg-muted)]">shared therapists</div>
                    </td>
                    <td>
                      <div className="flex flex-wrap gap-2">
                        <Link
                          href={`/users/${user.id}`}
                          className={buttonStyles({ variant: 'outline', size: 'sm' })}
                        >
                          View profile
                        </Link>
                        <ConfirmActionButton
                          triggerLabel="Suspend"
                          dialogTitle={`Suspend ${user.name}?`}
                          dialogDescription="Use this for high-confidence misuse, repeated policy evasion, or a compromised account while the backend moderation action is being wired."
                          confirmationLabel="Confirm suspend"
                          successTitle="Suspend flow prepared"
                          successDescription="The UI interaction completed successfully and is ready for backend moderation wiring."
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
