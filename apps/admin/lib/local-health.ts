import fs from 'node:fs';

const REQUIRED_PUBLIC_FIREBASE_KEYS = [
  'NEXT_PUBLIC_FIREBASE_API_KEY',
  'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN',
  'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
  'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
  'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID',
  'NEXT_PUBLIC_FIREBASE_APP_ID',
] as const;

type EnvMap = NodeJS.ProcessEnv;

function hasNonEmptyValue(value: string | undefined) {
  return typeof value === 'string' && value.trim().length > 0;
}

function resolveHomeDirectory(env: EnvMap, homeDir?: string) {
  if (hasNonEmptyValue(homeDir)) {
    return homeDir!.trim();
  }

  return env.HOME?.trim() || env.USERPROFILE?.trim() || '';
}

export function hasRequiredPublicFirebaseConfig(env: EnvMap = process.env) {
  return REQUIRED_PUBLIC_FIREBASE_KEYS.every((key) => hasNonEmptyValue(env[key]));
}

export function hasExplicitFirebaseAdminCredentials(
  env: EnvMap = process.env,
) {
  return (
    hasNonEmptyValue(env.FIREBASE_PROJECT_ID) &&
    hasNonEmptyValue(env.FIREBASE_CLIENT_EMAIL) &&
    hasNonEmptyValue(env.FIREBASE_PRIVATE_KEY)
  );
}

export function resolveApplicationDefaultCredentialsPath(
  env: EnvMap = process.env,
  homeDir?: string,
) {
  if (hasNonEmptyValue(env.GOOGLE_APPLICATION_CREDENTIALS)) {
    return env.GOOGLE_APPLICATION_CREDENTIALS!.trim();
  }

  const resolvedHomeDir = resolveHomeDirectory(env, homeDir);
  if (!resolvedHomeDir) {
    return '';
  }

  const normalizedHomeDir = resolvedHomeDir.replace(/[\\/]+$/, '');
  return `${normalizedHomeDir}/.config/gcloud/application_default_credentials.json`;
}

export function hasApplicationDefaultCredentials(
  env: EnvMap = process.env,
  homeDir?: string,
) {
  const credentialsPath = resolveApplicationDefaultCredentialsPath(env, homeDir);
  return Boolean(credentialsPath) && fs.existsSync(credentialsPath);
}

export function resolveFirebaseAdminCredentialSource(
  env: EnvMap = process.env,
  homeDir?: string,
) {
  if (hasExplicitFirebaseAdminCredentials(env)) {
    return 'service_account_env';
  }

  if (hasApplicationDefaultCredentials(env, homeDir)) {
    return 'application_default_credentials';
  }

  return 'unavailable';
}

export function buildAdminHealthSnapshot(
  options: {
    env?: EnvMap;
    homeDir?: string;
    firebaseAdminInitialized?: boolean;
  } = {},
) {
  const env = options.env ?? process.env;
  const credentialSource = resolveFirebaseAdminCredentialSource(
    env,
    options.homeDir,
  );
  const publicConfigReady = hasRequiredPublicFirebaseConfig(env);
  const firebaseAdminReady =
    options.firebaseAdminInitialized === true &&
    credentialSource !== 'unavailable';

  return {
    ok: publicConfigReady && firebaseAdminReady,
    status: publicConfigReady && firebaseAdminReady ? 'healthy' : 'degraded',
    authMode: 'real',
    publicConfigReady,
    firebaseAdminReady,
    firebaseAdminCredentialSource: credentialSource,
  };
}
