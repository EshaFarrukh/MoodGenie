'use client';

import { useState } from 'react';
import { AlertTriangle, ClipboardPenLine, Shield } from 'lucide-react';
import { Dialog } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { useToast } from '@/components/ui/toast-provider';

type ConfirmActionButtonProps = {
  triggerLabel: string;
  dialogTitle: string;
  dialogDescription: string;
  confirmationLabel: string;
  tone?: 'primary' | 'danger';
  successTitle: string;
  successDescription: string;
};

export function ConfirmActionButton({
  triggerLabel,
  dialogTitle,
  dialogDescription,
  confirmationLabel,
  tone = 'danger',
  successTitle,
  successDescription,
}: ConfirmActionButtonProps) {
  const [open, setOpen] = useState(false);
  const [notes, setNotes] = useState('');
  const { pushToast } = useToast();
  const requiresCarefulReview = tone === 'danger';

  return (
    <>
      <Button
        type="button"
        variant={tone === 'danger' ? 'danger' : 'secondary'}
        size="sm"
        onClick={() => setOpen(true)}
      >
        {triggerLabel}
      </Button>
      <Dialog
        open={open}
        onClose={() => setOpen(false)}
        title={dialogTitle}
        description={dialogDescription}
        size="md"
        footer={
          <div className="flex items-center justify-end gap-3">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              type="button"
              variant={tone === 'danger' ? 'danger' : 'primary'}
              onClick={() => {
                pushToast({
                  title: successTitle,
                  description: successDescription,
                  tone: 'success',
                });
                setOpen(false);
                setNotes('');
              }}
            >
              {confirmationLabel}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <div
            className={`rounded-[24px] border p-4 ${
              requiresCarefulReview
                ? 'border-[rgba(226,83,74,0.18)] bg-[rgba(226,83,74,0.06)]'
                : 'border-[var(--mg-border)] bg-[var(--mg-surface-subtle)]'
            }`}
          >
            <div className="flex items-start gap-3">
              <div
                className={`rounded-2xl p-2.5 ${
                  requiresCarefulReview
                    ? 'bg-[rgba(226,83,74,0.12)] text-[var(--mg-danger)]'
                    : 'bg-[var(--mg-primary-soft)] text-[var(--mg-primary)]'
                }`}
              >
                {requiresCarefulReview ? (
                  <AlertTriangle className="h-5 w-5" />
                ) : (
                  <Shield className="h-5 w-5" />
                )}
              </div>
              <div className="space-y-1">
                <p className="text-sm font-semibold text-[var(--mg-heading)]">
                  Capture the operator rationale before confirming.
                </p>
                <p className="text-sm leading-6 text-[var(--mg-muted)]">
                  Use the note below to document context, evidence, and follow-up ownership so
                  the action remains reviewable in operations history.
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-[24px] border border-[var(--mg-border)] bg-white p-5">
            <div className="mb-4 flex items-start gap-3">
              <div className="rounded-2xl bg-[var(--mg-surface-subtle)] p-2.5 text-[var(--mg-primary)]">
                <ClipboardPenLine className="h-5 w-5" />
              </div>
              <div>
                <p className="text-sm font-semibold text-[var(--mg-heading)]">Internal note</p>
                <p className="mt-1 text-sm leading-6 text-[var(--mg-muted)]">
                  Include reason, reviewer context, and the next checkpoint for the account or case.
                </p>
              </div>
            </div>
            <textarea
              className="min-h-[140px] w-full rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-3 text-sm text-[var(--mg-text)] outline-none transition focus:border-[var(--mg-primary)] focus:bg-white"
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              placeholder="Document context for the action, owner, and next review checkpoint."
            />
          </div>
        </div>
      </Dialog>
    </>
  );
}
