const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildBackendHealthPayload,
  buildFirebaseAdminOptions,
  getLocalBypassUser,
  getStartupValidationErrors,
  isOllamaTimeoutError,
  ollamaTagMatchesConfiguredModel,
  toOllamaRequestError,
} = require('../server');

test('startup validation fails closed in production when origins are missing', () => {
  const errors = getStartupValidationErrors({
    isProduction: true,
    allowedOrigins: [],
    allowUnauthenticatedLocal: false,
    enableAdminBootstrap: false,
    firebaseAdminReady: true,
  });

  assert.ok(
    errors.includes(
      'ALLOWED_ORIGINS must be configured explicitly in production.',
    ),
  );
});

test('startup validation rejects unsafe production bypass flags', () => {
  const errors = getStartupValidationErrors({
    isProduction: true,
    allowedOrigins: ['https://admin.moodgenie.app'],
    allowUnauthenticatedLocal: true,
    enableAdminBootstrap: true,
    firebaseAdminReady: false,
  });

  assert.ok(
    errors.includes(
      'ALLOW_UNAUTHENTICATED_LOCAL cannot be enabled in production.',
    ),
  );
  assert.ok(
    errors.includes(
      'ENABLE_ADMIN_BOOTSTRAP must be disabled in production after initial provisioning.',
    ),
  );
  assert.ok(
    errors.includes(
      'Firebase Admin must initialize successfully before production startup.',
    ),
  );
});

test('startup validation rejects wildcard production origins', () => {
  const errors = getStartupValidationErrors({
    isProduction: true,
    allowedOrigins: ['*'],
    allowUnauthenticatedLocal: false,
    enableAdminBootstrap: false,
    firebaseAdminReady: true,
  });

  assert.ok(
    errors.includes(
      'ALLOWED_ORIGINS cannot contain wildcard entries in production.',
    ),
  );
});

test('startup validation allows safe non-production local development', () => {
  const errors = getStartupValidationErrors({
    isProduction: false,
    allowedOrigins: [],
    allowUnauthenticatedLocal: true,
    enableAdminBootstrap: true,
    firebaseAdminReady: false,
  });

  assert.deepEqual(errors, []);
});

test('local bypass user stays low privilege', () => {
  assert.deepEqual(getLocalBypassUser(), {
    uid: 'local-dev-user',
    role: 'user',
    adminRoles: [],
    email: 'local-dev@example.com',
    name: 'Local Development User',
  });
});

test('ollama model matching accepts default latest tags', () => {
  assert.equal(ollamaTagMatchesConfiguredModel('moodgenie:latest', 'moodgenie'), true);
  assert.equal(ollamaTagMatchesConfiguredModel('moodgenie', 'moodgenie:latest'), true);
  assert.equal(ollamaTagMatchesConfiguredModel('phi3:latest', 'moodgenie'), false);
});

test('backend health payload reports degraded state when model is missing', () => {
  process.env.POSTMARK_SERVER_TOKEN = '';
  process.env.POSTMARK_FROM_EMAIL = '';
  const payload = buildBackendHealthPayload({
    ollamaReachable: true,
    modelReady: false,
    turnConfigured: false,
    details: 'Configured model "moodgenie" is not installed in Ollama.',
  });

  assert.equal(payload.ok, false);
  assert.equal(payload.status, 'degraded');
  assert.equal(payload.chatMode, 'degraded');
  assert.equal(payload.ollama, 'connected');
  assert.equal(payload.modelReady, false);
  assert.equal(payload.backendAuthMode, 'real');
  assert.equal(payload.notificationPushReady, payload.firebaseAdminReady);
  assert.equal(payload.notificationEmailReady, false);
  assert.equal(payload.notificationJobsReady, false);
  assert.equal(payload.notificationProvidersReady, false);
});

test('firebase admin options stay undefined without service account env', () => {
  assert.equal(buildFirebaseAdminOptions({}), undefined);
});

test('firebase admin options use application default credentials when only project id is present', () => {
  const options = buildFirebaseAdminOptions({
    FIREBASE_PROJECT_ID: 'moodgenie-4fc46',
  });

  assert.equal(options.projectId, 'moodgenie-4fc46');
  assert.ok(options.credential);
});

test('ollama timeout detection recognizes abort timeout errors', () => {
  assert.equal(
    isOllamaTimeoutError({
      name: 'TimeoutError',
      message: 'The operation was aborted due to timeout',
      code: 23,
    }),
    true,
  );
  assert.equal(
    isOllamaTimeoutError({
      name: 'Error',
      message: 'connection refused',
    }),
    false,
  );
});

test('ollama request errors map timeouts to gateway timeout responses', () => {
  const error = toOllamaRequestError(
    {
      name: 'TimeoutError',
      message: 'The operation was aborted due to timeout',
      code: 23,
    },
    16001,
  );

  assert.equal(error.status, 504);
  assert.equal(error.code, 'ollama_timeout');
  assert.equal(error.details.elapsedMs, 16001);
});
