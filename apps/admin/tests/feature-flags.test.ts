import test from 'node:test';
import assert from 'node:assert/strict';
import {
  DEFAULT_NOTIFICATION_FEATURE_FLAGS,
  mergeFeatureFlags,
} from '../lib/feature-flags.ts';
import type { FeatureFlag } from '../lib/types.ts';

test('notification feature flags are seeded for the admin dashboard', () => {
  assert.deepEqual(
    DEFAULT_NOTIFICATION_FEATURE_FLAGS.map((flag) => flag.id),
    [
      'predictive_mood_notifications',
      'ai_generated_notification_copy',
      'appointment_emails',
      'therapist_push_ops',
    ],
  );
});

test('mergeFeatureFlags overlays persisted values onto seeded defaults', () => {
  const merged = mergeFeatureFlags([
    {
      id: 'appointment_emails',
      description: 'Custom persisted description',
      enabled: false,
      rollout: 25,
      audience: 'all',
      updatedAt: '2026-04-13T00:00:00.000Z',
    },
  ] satisfies FeatureFlag[]);

  const appointmentEmails = merged.find((flag) => flag.id === 'appointment_emails');
  assert.ok(appointmentEmails);
  assert.equal(appointmentEmails.enabled, false);
  assert.equal(appointmentEmails.rollout, 25);
  assert.equal(appointmentEmails.description, 'Custom persisted description');
  assert.equal(appointmentEmails.updatedAt, '2026-04-13T00:00:00.000Z');
});

test('mergeFeatureFlags keeps seeded descriptions when a persisted flag is sparse', () => {
  const merged = mergeFeatureFlags([
    {
      id: 'therapist_push_ops',
      description: '',
      enabled: true,
      rollout: 100,
      audience: '',
      updatedAt: null,
    },
  ] satisfies FeatureFlag[]);

  const therapistPushOps = merged.find((flag) => flag.id === 'therapist_push_ops');
  assert.ok(therapistPushOps);
  assert.match(therapistPushOps.description, /therapist-facing push/i);
  assert.equal(therapistPushOps.audience, 'therapists');
});
