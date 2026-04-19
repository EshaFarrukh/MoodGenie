'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  buildSuggestedTherapistDecisionNote,
  meetsReviewNoteMinimum,
  MIN_REVIEW_NOTE_LENGTH,
} from '@/lib/reviewer-note';
import { Button } from '@/components/ui/button';

type TherapistDecisionFormProps = {
  therapistId: string;
};

export function TherapistDecisionForm({
  therapistId,
}: TherapistDecisionFormProps) {
  const router = useRouter();
  const [decision, setDecision] = useState<'approve' | 'reject' | 'suspend'>(
    'approve',
  );
  const [notes, setNotes] = useState('');
  const [verificationMethod, setVerificationMethod] = useState('license_registry');
  const [verificationReference, setVerificationReference] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit() {
    let submissionNotes = notes.trim();

    if (!confirmed) {
      setError('Confirm the decision before applying it.');
      return;
    }

    if (
      decision === 'approve' &&
      (verificationMethod.trim().length === 0 ||
        verificationReference.trim().length < 6)
    ) {
      setError(
        'Approvals require a verification method and reference to support the credential review.',
      );
      return;
    }

    if (!meetsReviewNoteMinimum(submissionNotes) && decision === 'approve') {
      submissionNotes = buildSuggestedTherapistDecisionNote({
        decision,
        verificationMethod,
        verificationReference,
      });
      if (submissionNotes) {
        setNotes(submissionNotes);
      }
    }

    if (!meetsReviewNoteMinimum(submissionNotes)) {
      setError(
        `Reviewer notes must be at least ${MIN_REVIEW_NOTE_LENGTH} characters. Example: "Approved after manual reference check. Reference: 0132453."`,
      );
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      const response = await fetch(`/api/admin/therapists/${therapistId}/decision`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          decision,
          notes: submissionNotes,
          verificationMethod: decision === 'approve' ? verificationMethod : '',
          verificationReference:
            decision === 'approve' ? verificationReference : '',
        }),
      });
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to save therapist decision.');
      }
      setNotes('');
      setVerificationReference('');
      setConfirmed(false);
      router.refresh();
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : 'Unable to save therapist decision.',
      );
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <div className="space-y-5">
      <div className="grid gap-5 lg:grid-cols-[0.9fr_1.1fr]">
        <div className="space-y-5">
          <div className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-5">
            <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
              Decision
            </div>
            <div className="mt-4 grid gap-2">
              {(['approve', 'reject', 'suspend'] as const).map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => setDecision(option)}
                  className={`rounded-[20px] border px-4 py-3 text-left text-sm font-semibold capitalize transition ${
                    decision === option
                      ? 'border-[rgba(27,116,216,0.22)] bg-[var(--mg-primary-soft)] text-[var(--mg-primary-strong)]'
                      : 'border-[var(--mg-border)] bg-white text-[var(--mg-text)] hover:bg-[var(--mg-surface-muted)]'
                  }`}
                >
                  {option}
                </button>
              ))}
            </div>
          </div>

          {decision === 'approve' ? (
            <div className="rounded-[24px] border border-[var(--mg-border)] bg-white p-5">
              <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
                Verification
              </div>
              <div className="mt-4 grid gap-4">
                <label className="field">
                  <span>Verification method</span>
                  <select
                    value={verificationMethod}
                    onChange={(event) => setVerificationMethod(event.target.value)}
                  >
                    <option value="license_registry">License registry</option>
                    <option value="document_review">Document review</option>
                    <option value="manual_reference_check">Manual reference check</option>
                  </select>
                </label>
                <label className="field">
                  <span>Verification reference</span>
                  <input
                    placeholder="Reference or case number"
                    value={verificationReference}
                    onChange={(event) => setVerificationReference(event.target.value)}
                  />
                </label>
              </div>
            </div>
          ) : null}
        </div>

        <div className="space-y-5">
          <div className="rounded-[24px] border border-[var(--mg-border)] bg-white p-5">
            <div className="text-xs font-semibold uppercase tracking-[0.16em] text-[var(--mg-muted)]">
              Reviewer note
            </div>
            <label className="field mt-4">
              <span>Durable rationale</span>
              <textarea
                placeholder="Document the decision, evidence reviewed, and any follow-up obligations."
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
              />
            </label>
            <p className="mt-3 text-sm leading-6 text-[var(--mg-muted)]">
              For approvals, if the note is too short, we will convert the verification details into a durable audited note automatically.
            </p>
          </div>

          <label className="checkbox-row rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4">
            <input
              type="checkbox"
              checked={confirmed}
              onChange={(event) => setConfirmed(event.target.checked)}
            />
            <span>
              I verified the credential decision details and understand that this action is audited immediately.
            </span>
          </label>
        </div>
      </div>

      {error ? <div className="feedback">{error}</div> : null}

      <div className="flex items-center justify-end gap-3">
        <Button
          type="button"
          variant={decision === 'approve' ? 'primary' : 'danger'}
          onClick={handleSubmit}
          disabled={isSaving}
        >
          {isSaving ? 'Saving decision…' : 'Apply decision'}
        </Button>
      </div>
    </div>
  );
}
