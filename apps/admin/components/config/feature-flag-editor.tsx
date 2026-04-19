'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import type { FeatureFlag } from '@/lib/types';
import { Button } from '@/components/ui/button';
import { StatusBadge } from '@/components/ui/status-badge';

type FeatureFlagEditorProps = {
  flags: FeatureFlag[];
};

export function FeatureFlagEditor({ flags }: FeatureFlagEditorProps) {
  const router = useRouter();
  const [drafts, setDrafts] = useState<Record<string, FeatureFlag>>({});
  const [changeReasons, setChangeReasons] = useState<Record<string, string>>({});
  const [confirmations, setConfirmations] = useState<Record<string, boolean>>({});
  const [feedback, setFeedback] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState<string | null>(null);

  useEffect(() => {
    setDrafts(Object.fromEntries(flags.map((flag) => [flag.id, flag])));
    setChangeReasons((current) =>
      Object.fromEntries(flags.map((flag) => [flag.id, current[flag.id] || ''])),
    );
    setConfirmations((current) =>
      Object.fromEntries(flags.map((flag) => [flag.id, current[flag.id] || false])),
    );
  }, [flags]);

  const orderedFlags = useMemo(
    () => flags.map((flag) => drafts[flag.id] || flag),
    [drafts, flags],
  );

  function updateDraft(id: string, patch: Partial<FeatureFlag>) {
    setDrafts((current) => ({
      ...current,
      [id]: {
        ...current[id],
        ...patch,
      },
    }));
  }

  async function saveFlag(id: string) {
    const flag = drafts[id];
    if (!flag) return;
    const changeReason = changeReasons[id]?.trim() || '';

    if (changeReason.length < 12) {
      setFeedback('Document why this flag is changing before saving it.');
      return;
    }

    if (!confirmations[id]) {
      setFeedback('Confirm that you want to roll this flag change out.');
      return;
    }

    setIsSaving(id);
    setFeedback(null);

    try {
      const response = await fetch('/api/admin/feature-flags', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...flag,
          changeReason,
        }),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to save feature flag.');
      }
      setFeedback(`Saved "${flag.id}" successfully.`);
      setChangeReasons((current) => ({ ...current, [flag.id]: '' }));
      setConfirmations((current) => ({ ...current, [flag.id]: false }));
      router.refresh();
    } catch (error) {
      setFeedback(error instanceof Error ? error.message : 'Unable to save flag.');
    } finally {
      setIsSaving(null);
    }
  }

  return (
    <div className="space-y-5">
      {feedback ? (
        <div className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3 text-sm text-[var(--mg-muted)]">
          {feedback}
        </div>
      ) : null}
      {orderedFlags.map((flag) => (
        <div
          className="rounded-[28px] border border-[var(--mg-border)] bg-white p-5 shadow-[0_10px_30px_rgba(0,59,115,0.06)]"
          key={flag.id}
        >
          <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                Feature flag
              </div>
              <h3 className="mt-2 text-lg font-semibold tracking-[-0.03em] text-[var(--mg-heading)]">
                {flag.id}
              </h3>
              <p className="mt-1 text-sm leading-6 text-[var(--mg-muted)]">
                Change rollout behavior without shipping a new mobile binary.
              </p>
            </div>
            <div className="flex items-center gap-3">
              <StatusBadge status={flag.enabled ? 'enabled' : 'disabled'} />
              <div className="rounded-full bg-[var(--mg-surface-muted)] px-3 py-1 text-xs font-semibold uppercase tracking-[0.14em] text-[var(--mg-muted)]">
                {flag.rollout}% rollout
              </div>
            </div>
          </div>

          <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <label className="field">
              <span>Description</span>
              <input
                value={flag.description}
                onChange={(event) =>
                  updateDraft(flag.id, { description: event.target.value })
                }
              />
            </label>
            <label className="field">
              <span>Audience</span>
              <input
                value={flag.audience}
                onChange={(event) =>
                  updateDraft(flag.id, { audience: event.target.value })
                }
              />
            </label>
            <label className="field">
              <span>Rollout %</span>
              <input
                type="number"
                min={0}
                max={100}
                value={flag.rollout}
                onChange={(event) =>
                  updateDraft(flag.id, { rollout: Number(event.target.value || '0') })
                }
              />
            </label>
            <label className="field">
              <span>State</span>
              <select
                value={flag.enabled ? 'enabled' : 'disabled'}
                onChange={(event) =>
                  updateDraft(flag.id, { enabled: event.target.value === 'enabled' })
                }
              >
                <option value="enabled">Enabled</option>
                <option value="disabled">Disabled</option>
              </select>
            </label>
            <label className="field md:col-span-2 xl:col-span-4">
              <span>Reason for change</span>
              <textarea
                rows={3}
                value={changeReasons[flag.id] || ''}
                onChange={(event) =>
                  setChangeReasons((current) => ({
                    ...current,
                    [flag.id]: event.target.value,
                  }))
                }
                placeholder="Explain the rollout reason, expected impact, and rollback owner."
              />
            </label>
          </div>

          <label className="checkbox-row mt-4 rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3">
            <input
              type="checkbox"
              checked={confirmations[flag.id] || false}
              onChange={(event) =>
                setConfirmations((current) => ({
                  ...current,
                  [flag.id]: event.target.checked,
                }))
              }
            />
            <span>
              I understand this flag change is audited and can immediately affect live production behavior.
            </span>
          </label>

          <div className="mt-4 flex justify-end">
            <Button
              type="button"
              onClick={() => saveFlag(flag.id)}
              disabled={isSaving === flag.id}
            >
              {isSaving === flag.id ? 'Saving…' : 'Save flag'}
            </Button>
          </div>
        </div>
      ))}
    </div>
  );
}
