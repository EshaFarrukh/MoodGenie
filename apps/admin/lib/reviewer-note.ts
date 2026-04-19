const MIN_REVIEW_NOTE_LENGTH = 12;

function normalizeVerificationMethod(method: string) {
  switch (method.trim()) {
    case 'license_registry':
      return 'license registry review';
    case 'document_review':
      return 'document review';
    case 'manual_reference_check':
      return 'manual reference check';
    default:
      return 'credential review';
  }
}

export function meetsReviewNoteMinimum(note: string) {
  return note.trim().length >= MIN_REVIEW_NOTE_LENGTH;
}

export function buildSuggestedTherapistDecisionNote(params: {
  decision: 'approve' | 'reject' | 'suspend';
  verificationMethod?: string;
  verificationReference?: string;
}) {
  const verificationMethod = params.verificationMethod?.trim() || '';
  const verificationReference = params.verificationReference?.trim() || '';

  if (
    params.decision === 'approve' &&
    verificationMethod &&
    verificationReference
  ) {
    return `Approved after ${normalizeVerificationMethod(verificationMethod)}. Reference: ${verificationReference}.`;
  }

  if (params.decision === 'reject') {
    return 'Rejected after reviewer assessment. Additional rationale required.';
  }

  if (params.decision === 'suspend') {
    return 'Suspended after reviewer assessment. Additional rationale required.';
  }

  return '';
}

export { MIN_REVIEW_NOTE_LENGTH };
