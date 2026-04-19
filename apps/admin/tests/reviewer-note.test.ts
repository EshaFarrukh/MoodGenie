import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildSuggestedTherapistDecisionNote,
  meetsReviewNoteMinimum,
  MIN_REVIEW_NOTE_LENGTH,
} from '../lib/reviewer-note.ts';

test('approval note helper builds a durable note from verification details', () => {
  const note = buildSuggestedTherapistDecisionNote({
    decision: 'approve',
    verificationMethod: 'manual_reference_check',
    verificationReference: '0132453',
  });

  assert.equal(
    note,
    'Approved after manual reference check. Reference: 0132453.',
  );
  assert.equal(meetsReviewNoteMinimum(note), true);
});

test('review note helper still enforces the minimum length', () => {
  assert.equal(meetsReviewNoteMinimum('accepted'), false);
  assert.equal(meetsReviewNoteMinimum('a'.repeat(MIN_REVIEW_NOTE_LENGTH)), true);
});
