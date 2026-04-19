import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { buildFirebaseAdminOptions } from '../lib/firebase-admin.ts';

test('firebase admin options use explicit service account when provided', () => {
  const { privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const options = buildFirebaseAdminOptions({
    FIREBASE_PROJECT_ID: 'moodgenie-4fc46',
    FIREBASE_CLIENT_EMAIL: 'firebase-adminsdk@test.invalid',
    FIREBASE_PRIVATE_KEY: privateKey.export({
      type: 'pkcs8',
      format: 'pem',
    }).replace(/\n/g, '\\n'),
  });

  assert.equal(options?.projectId, 'moodgenie-4fc46');
  assert.ok(options?.credential);
});

test('firebase admin options use ADC when only project id is available', () => {
  const options = buildFirebaseAdminOptions({
    FIREBASE_PROJECT_ID: 'moodgenie-4fc46',
  });

  assert.equal(options?.projectId, 'moodgenie-4fc46');
  assert.ok(options?.credential);
});
