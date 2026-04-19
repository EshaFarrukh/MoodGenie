import test from 'node:test';
import assert from 'node:assert/strict';
import { getTherapistApprovalBlockers } from '../lib/therapist-review.ts';

test('approval blockers focus on credential file completeness', () => {
  const blockers = getTherapistApprovalBlockers({
    displayName: 'Sohaib Khalid',
    specialty: '',
    professionalTitle: '',
    licenseNumber: '0132453',
    licenseIssuingAuthority: 'Punjab Medical Council',
    licenseRegion: 'Punjab',
    licenseExpiresAt: new Date('2027-12-31T00:00:00.000Z'),
    credentialEvidenceSummary: 'Verified against registry and submitted ID.',
  });

  assert.deepEqual(blockers, []);
});

test('approval blockers still require core license evidence', () => {
  const blockers = getTherapistApprovalBlockers({
    licenseNumber: '',
    licenseIssuingAuthority: 'Punjab Medical Council',
    licenseRegion: 'Punjab',
    licenseExpiresAt: null,
    credentialEvidenceSummary: '',
  });

  assert.deepEqual(blockers, [
    'license number',
    'license expiry',
    'credential evidence summary',
  ]);
});

test('approval blockers include reviewer verification inputs when required', () => {
  const blockers = getTherapistApprovalBlockers(
    {
      licenseNumber: '0132453',
      licenseIssuingAuthority: 'Punjab Medical Council',
      licenseRegion: 'Punjab',
      licenseExpiresAt: new Date('2027-12-31T00:00:00.000Z'),
      credentialEvidenceSummary: 'Registry match confirmed.',
    },
    {
      requireDecisionVerification: true,
      verificationMethod: 'manual_reference_check',
      verificationReference: '',
    },
  );

  assert.deepEqual(blockers, ['verification reference']);
});
