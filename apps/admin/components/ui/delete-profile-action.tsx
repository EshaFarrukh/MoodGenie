'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlertTriangle, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { useToast } from '@/components/ui/toast-provider';

type DeleteProfileActionProps = {
  entityId: string;
  entityLabel: string;
  entityType: 'user' | 'therapist';
  redirectHref: string;
};

export function DeleteProfileAction({
  entityId,
  entityLabel,
  entityType,
  redirectHref,
}: DeleteProfileActionProps) {
  const router = useRouter();
  const { pushToast } = useToast();
  const [open, setOpen] = useState(false);
  const [confirmation, setConfirmation] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  async function handleDelete() {
    if (confirmation !== 'DELETE') {
      setError('Type DELETE to confirm profile removal.');
      return;
    }

    setIsDeleting(true);
    setError(null);

    try {
      const response = await fetch(
        entityType === 'user'
          ? `/api/admin/users/${entityId}`
          : `/api/admin/therapists/${entityId}`,
        {
          method: 'DELETE',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ confirmation }),
        },
      );
      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to remove profile.');
      }

      pushToast({
        title: `${entityType === 'user' ? 'User' : 'Therapist'} profile deleted`,
        description:
          'The profile and linked operational records were removed from the platform.',
        tone: 'success',
      });
      setOpen(false);
      setConfirmation('');
      router.replace(redirectHref);
      router.refresh();
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : 'Unable to remove profile.',
      );
    } finally {
      setIsDeleting(false);
    }
  }

  return (
    <>
      <Button
        type="button"
        variant="danger"
        size="sm"
        onClick={() => setOpen(true)}
      >
        <Trash2 className="h-4 w-4" />
        Delete profile
      </Button>
      <Dialog
        open={open}
        onClose={() => {
          if (isDeleting) return;
          setOpen(false);
          setError(null);
          setConfirmation('');
        }}
        title={`Delete ${entityType} profile`}
        description={`This permanently removes ${entityLabel}, linked appointments, therapist chats, call rooms, and account access. This cannot be undone.`}
        size="md"
        footer={
          <div className="flex items-center justify-end gap-3">
            <Button
              type="button"
              variant="ghost"
              onClick={() => {
                setOpen(false);
                setError(null);
                setConfirmation('');
              }}
              disabled={isDeleting}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="danger"
              onClick={handleDelete}
              disabled={isDeleting}
            >
              {isDeleting ? 'Deleting profile…' : 'Delete permanently'}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <div className="rounded-[24px] border border-[rgba(226,83,74,0.18)] bg-[rgba(226,83,74,0.06)] p-4">
            <div className="flex items-start gap-3">
              <div className="rounded-2xl bg-[rgba(226,83,74,0.12)] p-2.5 text-[var(--mg-danger)]">
                <AlertTriangle className="h-5 w-5" />
              </div>
              <div className="space-y-1">
                <p className="text-sm font-semibold text-[var(--mg-heading)]">
                  Permanent admin action
                </p>
                <p className="text-sm leading-6 text-[var(--mg-muted)]">
                  Use this only when the account must be removed from the platform.
                  The operation is audited immediately.
                </p>
              </div>
            </div>
          </div>

          <label className="field">
            <span>Type DELETE to confirm</span>
            <input
              value={confirmation}
              onChange={(event) => setConfirmation(event.target.value)}
              placeholder="DELETE"
            />
          </label>

          {error ? <div className="feedback">{error}</div> : null}
        </div>
      </Dialog>
    </>
  );
}
