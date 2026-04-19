import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { cache } from 'react';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import type { AdminRole, AdminSession } from '@/lib/types';
import {
  hasAllowedAdminRole,
  requiresFreshAdminAuth,
  resolveBootstrapAccess,
} from '@/lib/access-policy';
import { getFirebaseAdminApp } from '@/lib/firebase-admin';

const SESSION_COOKIE_NAME = 'mg_admin_session';
const SESSION_DURATION_MS = 12 * 60 * 60 * 1000;
const RECENT_ADMIN_AUTH_WINDOW_SECONDS = Number(
  process.env.ADMIN_RECENT_AUTH_WINDOW_SECONDS || 30 * 60,
);
const VALID_ADMIN_ROLES: AdminRole[] = [
  'super_admin',
  'clinical_ops',
  'support_ops',
  'trust_safety',
  'read_only_analytics',
];

function normalizeRoles(value: unknown): AdminRole[] {
  const entries = Array.isArray(value) ? value : [value];
  return entries.filter((entry): entry is AdminRole =>
    typeof entry === 'string' &&
    VALID_ADMIN_ROLES.includes(entry as AdminRole),
  );
}

function bootstrapAdminUids() {
  return (process.env.ADMIN_BOOTSTRAP_UIDS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}

function adminBootstrapEnabled() {
  return process.env.ENABLE_ADMIN_BOOTSTRAP === 'true';
}

function adminMfaRequired() {
  return (
    process.env.ADMIN_REQUIRE_MFA === 'true' ||
    process.env.NODE_ENV === 'production'
  );
}

function toIsoFromSeconds(value: unknown): string | null {
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return null;
  }
  return new Date(seconds * 1000).toISOString();
}

function getAuthAgeSeconds(value: unknown): number | null {
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return null;
  }
  return Math.max(0, Math.floor(Date.now() / 1000) - seconds);
}

function firebaseTokenContext(token: DecodedIdToken) {
  const firebaseContext =
    token.firebase && typeof token.firebase === 'object'
      ? (token.firebase as {
          sign_in_provider?: string;
          sign_in_second_factor?: string;
        })
      : {};

  return {
    signInProvider:
      typeof firebaseContext.sign_in_provider === 'string'
        ? firebaseContext.sign_in_provider
        : null,
    mfaVerified:
      typeof firebaseContext.sign_in_second_factor === 'string' &&
      firebaseContext.sign_in_second_factor.trim().length > 0,
    authTime: toIsoFromSeconds(token.auth_time),
    authAgeSeconds: getAuthAgeSeconds(token.auth_time),
  };
}

export class AdminSessionAccessError extends Error {
  readonly status: number;

  constructor(message: string, status = 401) {
    super(message);
    this.name = 'AdminSessionAccessError';
    this.status = status;
  }
}

async function resolveAdminSessionByUid(
  uid: string,
  email: string | null,
  displayName: string | null,
  tokenRoles: AdminRole[],
  authContext: {
    authTime: string | null;
    authAgeSeconds: number | null;
    mfaVerified: boolean;
    signInProvider: string | null;
  },
): Promise<AdminSession | null> {
  const app = getFirebaseAdminApp();
  const db = getFirestore(app);

  const [adminDoc, userDoc] = await Promise.all([
    db.collection('admin_users').doc(uid).get(),
    db.collection('users').doc(uid).get(),
  ]);

  let roles = tokenRoles;
  if (adminDoc.exists) {
    roles = [...new Set([...roles, ...normalizeRoles(adminDoc.data()?.roles)])];
  }

  const bootstrapResolution = resolveBootstrapAccess({
    existingRoles: roles,
    enableBootstrap: adminBootstrapEnabled(),
    bootstrapUids: bootstrapAdminUids(),
    uid,
  });
  roles = bootstrapResolution.roles;

  if (adminDoc.exists && adminDoc.data()?.status === 'disabled') {
    return null;
  }

  if (roles.length === 0) {
    return null;
  }

  return {
    uid,
    email,
    displayName:
      adminDoc.data()?.displayName ||
      userDoc.data()?.name ||
      displayName ||
      email ||
      uid,
    roles,
    authTime: authContext.authTime,
    authAgeSeconds: authContext.authAgeSeconds,
    mfaVerified: authContext.mfaVerified,
    signInProvider: authContext.signInProvider,
    bootstrapProvisioned: bootstrapResolution.bootstrapProvisioned,
  };
}

const resolveAdminSessionByUidCached = cache(resolveAdminSessionByUid);

export async function createAdminSessionCookie(idToken: string) {
  const app = getFirebaseAdminApp();
  const auth = getAuth(app);
  const decodedToken = await auth.verifyIdToken(idToken, true);
  const authContext = firebaseTokenContext(decodedToken);
  const tokenRoles = normalizeRoles(
    decodedToken.adminRoles || decodedToken.adminRole,
  );
  const adminSession = await resolveAdminSessionByUidCached(
    decodedToken.uid,
    decodedToken.email || null,
    decodedToken.name || null,
    tokenRoles,
    authContext,
  );

  if (!adminSession) {
    throw new Error('Admin access is required for this dashboard.');
  }

  if (adminMfaRequired() && !adminSession.mfaVerified) {
    throw new Error(
      'A multi-factor verified admin sign-in is required for this dashboard.',
    );
  }

  return auth.createSessionCookie(idToken, { expiresIn: SESSION_DURATION_MS });
}

const getCurrentAdminSessionCached = cache(
  async (): Promise<AdminSession | null> => {
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get(SESSION_COOKIE_NAME)?.value;
  if (!sessionCookie) {
    return null;
  }

  try {
    const app = getFirebaseAdminApp();
    const auth = getAuth(app);
    const decodedCookie = await auth.verifySessionCookie(sessionCookie, true);
    const authContext = firebaseTokenContext(decodedCookie);
    const tokenRoles = normalizeRoles(
      decodedCookie.adminRoles || decodedCookie.adminRole,
    );

    return resolveAdminSessionByUidCached(
      decodedCookie.uid,
      decodedCookie.email || null,
      decodedCookie.name || null,
      tokenRoles,
      authContext,
    );
  } catch {
    return null;
  }
});

export async function getCurrentAdminSession(): Promise<AdminSession | null> {
  return getCurrentAdminSessionCached();
}

export async function requireAdminSession(
  allowedRoles?: AdminRole[],
): Promise<AdminSession> {
  const session = await getCurrentAdminSession();
  if (!session) {
    redirect('/login');
  }

  if (adminMfaRequired() && !session.mfaVerified) {
    redirect('/login');
  }

  if (
    allowedRoles &&
    allowedRoles.length > 0 &&
    !hasAllowedAdminRole(session.roles, allowedRoles)
  ) {
    redirect('/');
  }

  return session;
}

export async function requireAdminActionSession(
  allowedRoles?: AdminRole[],
): Promise<AdminSession> {
  const session = await getCurrentAdminSession();
  if (!session) {
    throw new AdminSessionAccessError(
      'Administrator access is required for this action.',
      401,
    );
  }

  if (
    allowedRoles &&
    allowedRoles.length > 0 &&
    !hasAllowedAdminRole(session.roles, allowedRoles)
  ) {
    throw new AdminSessionAccessError(
      'You do not have permission to perform this action.',
      403,
    );
  }

  if (adminMfaRequired() && !session.mfaVerified) {
    throw new AdminSessionAccessError(
      'A multi-factor verified admin sign-in is required for privileged actions.',
      401,
    );
  }

  if (requiresFreshAdminAuth(session.authAgeSeconds, RECENT_ADMIN_AUTH_WINDOW_SECONDS)) {
    throw new AdminSessionAccessError(
      'Please sign in again before performing privileged admin changes.',
      401,
    );
  }

  return session;
}

export { SESSION_COOKIE_NAME, SESSION_DURATION_MS };
