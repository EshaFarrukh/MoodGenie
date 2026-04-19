import {
  getApps,
  initializeApp,
  cert,
  applicationDefault,
} from 'firebase-admin/app';
import type { App, AppOptions } from 'firebase-admin/app';

let cachedApp: App | null = null;

function resolvedProjectId(env: NodeJS.ProcessEnv = process.env) {
  return (
    env.FIREBASE_PROJECT_ID ||
    env.GOOGLE_CLOUD_PROJECT ||
    env.GCLOUD_PROJECT ||
    ''
  ).trim();
}

export function buildFirebaseAdminOptions(
  env: NodeJS.ProcessEnv = process.env,
): AppOptions | undefined {
  const projectId = resolvedProjectId(env);
  const clientEmail = env.FIREBASE_CLIENT_EMAIL?.trim();
  const privateKey = env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    return {
      projectId,
      credential: cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    };
  }

  if (projectId) {
    return {
      projectId,
      credential: applicationDefault(),
    };
  }

  return undefined;
}

export function getFirebaseAdminApp(): App {
  if (cachedApp) {
    return cachedApp;
  }

  const existing = getApps()[0];
  if (existing) {
    cachedApp = existing;
    return existing;
  }

  cachedApp = initializeApp(buildFirebaseAdminOptions());
  return cachedApp;
}
