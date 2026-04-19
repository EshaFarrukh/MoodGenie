'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';

type PrivacyJobOpsFormProps = {
  jobId: string;
  initialStatus: 'open' | 'acknowledged' | 'in_progress' | 'closed';
  initialOwner?: string | null;
  initialNotes?: string | null;
};

export function PrivacyJobOpsForm({
  jobId,
  initialStatus,
  initialOwner,
  initialNotes,
}: PrivacyJobOpsFormProps) {
  const router = useRouter();
  const [opsStatus, setOpsStatus] = useState(initialStatus);
  const [opsOwner, setOpsOwner] = useState(initialOwner || '');
  const [opsNotes, setOpsNotes] = useState(initialNotes || '');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit() {
    setIsSaving(true);
    setError(null);

    try {
      const response = await fetch(`/api/admin/privacy-jobs/${jobId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          opsStatus,
          opsOwner,
          opsNotes,
        }),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to update privacy job.');
      }
      router.refresh();
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : 'Unable to update privacy job.',
      );
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4 md:grid-cols-2">
        <label className="field">
          <span>Ops status</span>
          <select
            id="opsStatus"
            value={opsStatus}
            onChange={(event) =>
              setOpsStatus(
                event.target.value as
                  | 'open'
                  | 'acknowledged'
                  | 'in_progress'
                  | 'closed',
              )
            }
          >
            <option value="open">Open</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="in_progress">In progress</option>
            <option value="closed">Closed</option>
          </select>
        </label>
        <label className="field">
          <span>Owner</span>
          <input
            id="opsOwner"
            value={opsOwner}
            onChange={(event) => setOpsOwner(event.target.value)}
            placeholder="support-ops uid or email alias"
          />
        </label>
      </div>
      <label className="field">
        <span>Ops notes</span>
        <textarea
          id="opsNotes"
          value={opsNotes}
          onChange={(event) => setOpsNotes(event.target.value)}
          rows={5}
          placeholder="Capture reviewer context, follow-up work, or customer communications."
        />
      </label>
      {error ? (
        <div className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3 text-sm text-[var(--mg-muted)]">
          {error}
        </div>
      ) : null}
      <div className="flex justify-end">
        <Button
          type="button"
          onClick={handleSubmit}
          disabled={isSaving}
        >
          {isSaving ? 'Saving…' : 'Update privacy job'}
        </Button>
      </div>
    </div>
  );
}
