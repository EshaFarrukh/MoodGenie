import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  buildAdminHealthSnapshot,
  hasApplicationDefaultCredentials,
  hasExplicitFirebaseAdminCredentials,
  hasRequiredPublicFirebaseConfig,
  resolveFirebaseAdminCredentialSource,
} from '../lib/local-health.ts';

const completePublicEnv = {
  NEXT_PUBLIC_FIREBASE_API_KEY: 'api-key',
  NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: 'moodgenie.firebaseapp.com',
  NEXT_PUBLIC_FIREBASE_PROJECT_ID: 'moodgenie-4fc46',
  NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET: 'moodgenie.firebasestorage.app',
  NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID: '123456789',
  NEXT_PUBLIC_FIREBASE_APP_ID: '1:123:web:abc',
};

test('public Firebase config readiness requires all web keys', () => {
  assert.equal(hasRequiredPublicFirebaseConfig(completePublicEnv), true);
  assert.equal(
    hasRequiredPublicFirebaseConfig({
      ...completePublicEnv,
      NEXT_PUBLIC_FIREBASE_APP_ID: '',
    }),
    false,
  );
});

test('credential source prefers explicit service account env', () => {
  const env = {
    ...completePublicEnv,
    FIREBASE_PROJECT_ID: 'moodgenie-4fc46',
    FIREBASE_CLIENT_EMAIL: 'firebase-adminsdk@test.invalid',
    FIREBASE_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n',
  };

  assert.equal(hasExplicitFirebaseAdminCredentials(env), true);
  assert.equal(resolveFirebaseAdminCredentialSource(env, '/tmp/nowhere'), 'service_account_env');
});

test('credential source accepts application default credentials file', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'moodgenie-admin-health-'));
  const credentialsPath = path.join(
    tempDir,
    'application_default_credentials.json',
  );
  fs.writeFileSync(credentialsPath, '{}');

  const env = {
    ...completePublicEnv,
    GOOGLE_APPLICATION_CREDENTIALS: credentialsPath,
  };

  assert.equal(hasApplicationDefaultCredentials(env, '/Users/ignored'), true);
  assert.equal(
    resolveFirebaseAdminCredentialSource(env, '/Users/ignored'),
    'application_default_credentials',
  );

  fs.rmSync(tempDir, { recursive: true, force: true });
});

test('admin health snapshot stays degraded without Firebase Admin readiness', () => {
  const payload = buildAdminHealthSnapshot({
    env: completePublicEnv,
    homeDir: '/tmp/nowhere',
    firebaseAdminInitialized: false,
  });

  assert.equal(payload.ok, false);
  assert.equal(payload.publicConfigReady, true);
  assert.equal(payload.firebaseAdminReady, false);
  assert.equal(payload.authMode, 'real');
});
