'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { EmptyState } from '@/components/ui/empty-state';
import { FilterBar } from '@/components/ui/filter-bar';
import { StatusBadge } from '@/components/ui/status-badge';
import type { SupportCase } from '@/lib/types';
import { formatDateTimeLabel } from '@/lib/utils';

type SupportCaseWorkspaceProps = {
  cases: SupportCase[];
};

const PRIORITIES = ['low', 'normal', 'high', 'urgent'] as const;
const STATUSES = [
  'open',
  'in_progress',
  'waiting_on_user',
  'resolved',
  'closed',
] as const;

type SupportCaseDraft = {
  status: (typeof STATUSES)[number];
  priority: (typeof PRIORITIES)[number];
  owner: string;
  summary: string;
};

export function SupportCaseWorkspace({
  cases,
}: SupportCaseWorkspaceProps) {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] =
    useState<'all' | (typeof STATUSES)[number]>('all');
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('user_support');
  const [priority, setPriority] = useState<(typeof PRIORITIES)[number]>('normal');
  const [summary, setSummary] = useState('');
  const [requesterId, setRequesterId] = useState('');
  const [savingCaseId, setSavingCaseId] = useState<string | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Record<string, SupportCaseDraft>>({});

  useEffect(() => {
    setDrafts((current) =>
      Object.fromEntries(
        cases.map((supportCase) => [
          supportCase.id,
          {
            status:
              current[supportCase.id]?.status ||
              (supportCase.status as (typeof STATUSES)[number]) ||
              'open',
            priority:
              current[supportCase.id]?.priority ||
              (supportCase.priority as (typeof PRIORITIES)[number]) ||
              'normal',
            owner: current[supportCase.id]?.owner ?? supportCase.owner ?? '',
            summary: current[supportCase.id]?.summary ?? supportCase.summary ?? '',
          },
        ]),
      ),
    );
  }, [cases]);

  const filteredCases = useMemo(() => {
    return cases.filter((supportCase) => {
      const normalizedQuery = query.trim().toLowerCase();
      const matchesQuery =
        normalizedQuery.length === 0 ||
        supportCase.title.toLowerCase().includes(normalizedQuery) ||
        supportCase.id.toLowerCase().includes(normalizedQuery) ||
        (supportCase.requesterId || '').toLowerCase().includes(normalizedQuery) ||
        (supportCase.category || '').toLowerCase().includes(normalizedQuery);

      const matchesStatus =
        statusFilter === 'all' || supportCase.status === statusFilter;

      return matchesQuery && matchesStatus;
    });
  }, [cases, query, statusFilter]);

  const summaryCards = [
    {
      label: 'Open cases',
      value: cases.filter((supportCase) => supportCase.status === 'open').length,
      helper: 'Fresh issues waiting on first owner response.',
    },
    {
      label: 'In progress',
      value: cases.filter((supportCase) => supportCase.status === 'in_progress').length,
      helper: 'Cases currently being worked by support or clinical ops.',
    },
    {
      label: 'Urgent',
      value: cases.filter((supportCase) => supportCase.priority === 'urgent').length,
      helper: 'Highest priority cases that deserve same-day movement.',
    },
    {
      label: 'Resolved',
      value: cases.filter((supportCase) =>
        ['resolved', 'closed'].includes(supportCase.status),
      ).length,
      helper: 'Cases already documented as resolved or closed.',
    },
  ];

  function updateDraft(
    caseId: string,
    patch: Partial<SupportCaseDraft>,
  ) {
    setDrafts((current) => ({
      ...current,
      [caseId]: {
        ...current[caseId],
        ...patch,
      },
    }));
  }

  async function handleCreate() {
    if (title.trim().length < 6) {
      setFeedback('Create a support case with a clearer title.');
      return;
    }

    setIsCreating(true);
    setFeedback(null);
    try {
      const response = await fetch('/api/admin/support-cases', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title,
          category,
          priority,
          summary,
          requesterId,
        }),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to create support case.');
      }
      setTitle('');
      setSummary('');
      setRequesterId('');
      setPriority('normal');
      setCategory('user_support');
      router.refresh();
    } catch (error) {
      setFeedback(
        error instanceof Error ? error.message : 'Unable to create support case.',
      );
    } finally {
      setIsCreating(false);
    }
  }

  async function handleUpdate(caseId: string) {
    const draft = drafts[caseId];
    if (!draft) return;
    setSavingCaseId(caseId);
    setFeedback(null);
    try {
      const response = await fetch(`/api/admin/support-cases/${caseId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(draft),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to update support case.');
      }
      router.refresh();
    } catch (error) {
      setFeedback(
        error instanceof Error ? error.message : 'Unable to update support case.',
      );
    } finally {
      setSavingCaseId(null);
    }
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {summaryCards.map((card) => (
          <Card key={card.label}>
            <CardContent className="p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                {card.label}
              </div>
              <div className="mt-3 text-3xl font-semibold tracking-[-0.05em] text-[var(--mg-heading)]">
                {card.value}
              </div>
              <p className="mt-2 text-sm leading-6 text-[var(--mg-muted)]">
                {card.helper}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardContent className="p-6">
          <div className="mb-5">
            <div className="text-lg font-semibold tracking-[-0.03em] text-[var(--mg-heading)]">
              Create support case
            </div>
            <p className="mt-1 text-sm leading-6 text-[var(--mg-muted)]">
              Centralize product issues, user escalations, therapist follow-up, and trust-sensitive support work without losing ownership.
            </p>
          </div>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <label className="field">
              <span>Title</span>
              <input
                id="support-case-title"
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                placeholder="User cannot complete therapist booking"
              />
            </label>
            <label className="field">
              <span>Category</span>
              <select
                id="support-case-category"
                value={category}
                onChange={(event) => setCategory(event.target.value)}
              >
                <option value="user_support">User support</option>
                <option value="therapist_ops">Therapist ops</option>
                <option value="privacy_request">Privacy request</option>
                <option value="appointment_issue">Appointment issue</option>
                <option value="trust_safety">Trust &amp; safety</option>
              </select>
            </label>
            <label className="field">
              <span>Priority</span>
              <select
                id="support-case-priority"
                value={priority}
                onChange={(event) =>
                  setPriority(event.target.value as (typeof PRIORITIES)[number])
                }
              >
                {PRIORITIES.map((entry) => (
                  <option key={entry} value={entry}>
                    {entry}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Requester UID</span>
              <input
                id="support-case-requester"
                value={requesterId}
                onChange={(event) => setRequesterId(event.target.value)}
                placeholder="Optional user or therapist UID"
              />
            </label>
            <label className="field md:col-span-2 xl:col-span-4">
              <span>Summary</span>
              <textarea
                id="support-case-summary"
                rows={3}
                value={summary}
                onChange={(event) => setSummary(event.target.value)}
                placeholder="Capture the issue, affected flow, and any immediate workaround."
              />
            </label>
          </div>
          <div className="mt-4 flex justify-end">
            <Button type="button" onClick={handleCreate} disabled={isCreating}>
              {isCreating ? 'Creating…' : 'Create support case'}
            </Button>
          </div>
        </CardContent>
      </Card>

      {feedback ? (
        <div className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3 text-sm text-[var(--mg-muted)]">
          {feedback}
        </div>
      ) : null}

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
              placeholder="Search case title, ID, requester, or category"
              className="pl-11"
            />
          </div>
        </label>
        <label className="field">
          <span className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
            Status
          </span>
          <select
            value={statusFilter}
            onChange={(event) =>
              setStatusFilter(event.target.value as 'all' | (typeof STATUSES)[number])
            }
          >
            <option value="all">All statuses</option>
            {STATUSES.map((status) => (
              <option key={status} value={status}>
                {status.replace(/_/g, ' ')}
              </option>
            ))}
          </select>
        </label>
      </FilterBar>

      {filteredCases.length === 0 ? (
        <Card>
          <CardContent className="p-6">
            <EmptyState
              title={
                cases.length === 0
                  ? 'No support cases yet'
                  : 'No support cases match these filters'
              }
              description={
                cases.length === 0
                  ? 'Create the first operational support case above to start centralizing issue handling.'
                  : 'Try widening the search or resetting the current status filter.'
              }
            />
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {filteredCases.map((supportCase) => {
            const draft = drafts[supportCase.id];
            if (!draft) {
              return null;
            }

            return (
              <Card key={supportCase.id}>
                <CardContent className="p-6">
                  <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                    <div>
                      <h3 className="text-lg font-semibold tracking-[-0.03em] text-[var(--mg-heading)]">
                        {supportCase.title}
                      </h3>
                      <p className="mt-1 text-sm leading-6 text-[var(--mg-muted)]">
                        {supportCase.category || 'General'} • {supportCase.id}
                      </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <StatusBadge status={supportCase.status} />
                      <StatusBadge status={supportCase.priority} />
                    </div>
                  </div>
                  <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                    <label className="field">
                      <span>Status</span>
                      <select
                        id={`${supportCase.id}-status`}
                        value={draft.status}
                        onChange={(event) =>
                          updateDraft(supportCase.id, {
                            status: event.target.value as (typeof STATUSES)[number],
                          })
                        }
                      >
                        {STATUSES.map((status) => (
                          <option key={status} value={status}>
                            {status.replace(/_/g, ' ')}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="field">
                      <span>Priority</span>
                      <select
                        id={`${supportCase.id}-priority`}
                        value={draft.priority}
                        onChange={(event) =>
                          updateDraft(supportCase.id, {
                            priority:
                              event.target.value as (typeof PRIORITIES)[number],
                          })
                        }
                      >
                        {PRIORITIES.map((entry) => (
                          <option key={entry} value={entry}>
                            {entry}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="field">
                      <span>Owner</span>
                      <input
                        id={`${supportCase.id}-owner`}
                        value={draft.owner}
                        onChange={(event) =>
                          updateDraft(supportCase.id, { owner: event.target.value })
                        }
                      />
                    </label>
                    <label className="field md:col-span-2 xl:col-span-4">
                      <span>Summary</span>
                      <textarea
                        id={`${supportCase.id}-summary`}
                        rows={3}
                        value={draft.summary}
                        onChange={(event) =>
                          updateDraft(supportCase.id, { summary: event.target.value })
                        }
                      />
                    </label>
                  </div>
                  <div className="mt-4 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
                    <div className="text-sm leading-6 text-[var(--mg-muted)]">
                      Requester: {supportCase.requesterId || 'Not linked'} • Created{' '}
                      {formatDateTimeLabel(supportCase.createdAt)} • Updated{' '}
                      {formatDateTimeLabel(supportCase.updatedAt)}
                    </div>
                    <div className="flex justify-end">
                      <Button
                        type="button"
                        disabled={savingCaseId === supportCase.id}
                        onClick={() => handleUpdate(supportCase.id)}
                      >
                        {savingCaseId === supportCase.id ? 'Saving…' : 'Save case'}
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
