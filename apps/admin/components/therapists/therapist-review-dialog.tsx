'use client';

import { useState } from 'react';
import { Dialog } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { TherapistDecisionForm } from '@/components/therapists/decision-form';

export function TherapistReviewDialog({
  therapistId,
  therapistName,
}: {
  therapistId: string;
  therapistName: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <Button type="button" variant="secondary" size="sm" onClick={() => setOpen(true)}>
        Review
      </Button>
      <Dialog
        open={open}
        onClose={() => setOpen(false)}
        title={`Review ${therapistName}`}
        description="Approve, reject, or suspend the provider with a durable operational note and verification trail."
        size="lg"
      >
        <TherapistDecisionForm therapistId={therapistId} />
      </Dialog>
    </>
  );
}
