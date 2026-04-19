'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';

type IncidentOpsFormProps = {
  incidentId: string;
  currentStatus: 'open' | 'acknowledged' | 'in_progress' | 'resolved';
  currentAssignee?: string | null;
  currentNotes?: string | null;
};

export function IncidentOpsForm({
  incidentId,
  currentStatus,
  currentAssignee,
  currentNotes,
}: IncidentOpsFormProps) {
  const router = useRouter();
  const [status, setStatus] = useState<
    'open' | 'acknowledged' | 'in_progress' | 'resolved'
  >(currentStatus);
  const [assignedTo, setAssignedTo] = useState(currentAssignee || '');
  const [opsNotes, setOpsNotes] = useState(currentNotes || '');
  const [isSaving, setIsSaving] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);

  async function handleSubmit() {
    setIsSaving(true);
    setFeedback(null);

    try {
      const response = await fetch(`/api/admin/ai-incidents/${incidentId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status,
          assignedTo,
          opsNotes,
        }),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to update AI incident.');
      }
      setFeedback('Incident operations state updated.');
      router.refresh();
    } catch (error) {
      setFeedback(
        error instanceof Error ? error.message : 'Unable to update AI incident.',
      );
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <div className="space-y-4">
      {feedback ? (
        <div className="rounded-[20px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3 text-sm text-[var(--mg-muted)]">
          {feedback}
        </div>
      ) : null}
      <div className="grid gap-4 md:grid-cols-2">
        <label className="field">
          <span>Ops status</span>
          <select
            id={`${incidentId}-status`}
            value={status}
            onChange={(event) =>
              setStatus(
                event.target.value as
                  | 'open'
                  | 'acknowledged'
                  | 'in_progress'
                  | 'resolved',
              )
            }
          >
            <option value="open">Open</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="in_progress">In progress</option>
            <option value="resolved">Resolved</option>
          </select>
        </label>
        <label className="field">
          <span>Assigned reviewer</span>
          <input
            id={`${incidentId}-assignee`}
            value={assignedTo}
            onChange={(event) => setAssignedTo(event.target.value)}
            placeholder="Admin UID, email, or queue owner"
          />
        </label>
      </div>
      <label className="field">
        <span>Resolution notes</span>
        <textarea
          id={`${incidentId}-notes`}
          value={opsNotes}
          onChange={(event) => setOpsNotes(event.target.value)}
          rows={5}
          placeholder="Summarize impact, mitigation, customer risk, and the next action."
        />
      </label>
      <div className="flex justify-end">
        <Button
          type="button"
          onClick={handleSubmit}
          disabled={isSaving}
        >
          {isSaving ? 'Saving…' : 'Save incident state'}
        </Button>
      </div>
    </div>
  );
}
