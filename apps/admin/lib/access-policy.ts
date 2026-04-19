import type { AdminRole } from './types';

export function hasAllowedAdminRole(
  sessionRoles: AdminRole[],
  allowedRoles?: AdminRole[],
) {
  if (!allowedRoles || allowedRoles.length === 0) {
    return true;
  }

  return sessionRoles.some((role) => allowedRoles.includes(role));
}

export function resolveBootstrapAccess(params: {
  existingRoles: AdminRole[];
  enableBootstrap: boolean;
  bootstrapUids: string[];
  uid: string;
}) {
  if (params.existingRoles.length > 0) {
    return {
      roles: params.existingRoles,
      bootstrapProvisioned: false,
    };
  }

  if (params.enableBootstrap && params.bootstrapUids.includes(params.uid)) {
    return {
      roles: ['super_admin'] as AdminRole[],
      bootstrapProvisioned: true,
    };
  }

  return {
    roles: params.existingRoles,
    bootstrapProvisioned: false,
  };
}

export function requiresFreshAdminAuth(
  authAgeSeconds: number | null,
  thresholdSeconds: number,
) {
  return authAgeSeconds != null && authAgeSeconds > thresholdSeconds;
}
