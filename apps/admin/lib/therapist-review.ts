function asTrimmedString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function toIso(value: unknown): string | null {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    const date = (value as { toDate(): Date }).toDate();
    return date.toISOString();
  }
  const parsed = new Date(String(value));
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
}

export function getTherapistApprovalBlockers(
  therapist: Record<string, unknown>,
  options: {
    verificationMethod?: string;
    verificationReference?: string;
    requireDecisionVerification?: boolean;
  } = {},
) {
  const missingFields: string[] = [];

  if (!asTrimmedString(therapist.licenseNumber)) {
    missingFields.push('license number');
  }
  if (!asTrimmedString(therapist.licenseIssuingAuthority)) {
    missingFields.push('licensing authority');
  }
  if (!asTrimmedString(therapist.licenseRegion)) {
    missingFields.push('license region');
  }
  if (!toIso(therapist.licenseExpiresAt)) {
    missingFields.push('license expiry');
  }
  if (!asTrimmedString(therapist.credentialEvidenceSummary)) {
    missingFields.push('credential evidence summary');
  }

  if (options.requireDecisionVerification) {
    if (!asTrimmedString(options.verificationMethod)) {
      missingFields.push('verification method');
    }
    if (!asTrimmedString(options.verificationReference)) {
      missingFields.push('verification reference');
    }
  }

  return missingFields;
}
