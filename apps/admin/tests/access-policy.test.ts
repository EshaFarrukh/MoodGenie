import test from 'node:test';
import assert from 'node:assert/strict';
import {
  hasAllowedAdminRole,
  requiresFreshAdminAuth,
  resolveBootstrapAccess,
} from '../lib/access-policy.ts';

test('bootstrap access is only granted when explicitly enabled', () => {
  const disabled = resolveBootstrapAccess({
    existingRoles: [],
    enableBootstrap: false,
    bootstrapUids: ['admin-1'],
    uid: 'admin-1',
  });
  assert.deepEqual(disabled, {
    roles: [],
    bootstrapProvisioned: false,
  });

  const enabled = resolveBootstrapAccess({
    existingRoles: [],
    enableBootstrap: true,
    bootstrapUids: ['admin-1'],
    uid: 'admin-1',
  });
  assert.deepEqual(enabled, {
    roles: ['super_admin'],
    bootstrapProvisioned: true,
  });
});

test('role checks enforce least privilege', () => {
  assert.equal(
    hasAllowedAdminRole(['support_ops'], ['support_ops', 'super_admin']),
    true,
  );
  assert.equal(
    hasAllowedAdminRole(['read_only_analytics'], ['support_ops']),
    false,
  );
});

test('fresh auth helper blocks stale privileged sessions', () => {
  assert.equal(requiresFreshAdminAuth(60, 300), false);
  assert.equal(requiresFreshAdminAuth(301, 300), true);
  assert.equal(requiresFreshAdminAuth(null, 300), false);
});
