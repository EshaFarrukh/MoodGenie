import type { FeatureFlag } from '@/lib/types';

export const DEFAULT_NOTIFICATION_FEATURE_FLAGS: FeatureFlag[] = [
  {
    id: 'predictive_mood_notifications',
    description:
      'Controls explicit mood forecast notifications for users when confidence and safety gates pass.',
    enabled: true,
    rollout: 100,
    audience: 'users',
    updatedAt: null,
  },
  {
    id: 'ai_generated_notification_copy',
    description:
      'Allows backend-owned AI wellness copy for mood reminder, quote, and forecast notifications.',
    enabled: true,
    rollout: 100,
    audience: 'users',
    updatedAt: null,
  },
  {
    id: 'appointment_emails',
    description:
      'Sends appointment lifecycle and reminder emails to users and therapists.',
    enabled: true,
    rollout: 100,
    audience: 'all',
    updatedAt: null,
  },
  {
    id: 'therapist_push_ops',
    description:
      'Enables therapist-facing push notifications for booking and appointment operations.',
    enabled: true,
    rollout: 100,
    audience: 'therapists',
    updatedAt: null,
  },
];

export function mergeFeatureFlags(
  persistedFlags: FeatureFlag[],
  defaultFlags: FeatureFlag[] = DEFAULT_NOTIFICATION_FEATURE_FLAGS,
): FeatureFlag[] {
  const merged = new Map<string, FeatureFlag>();

  for (const flag of defaultFlags) {
    merged.set(flag.id, flag);
  }

  for (const flag of persistedFlags) {
    const current = merged.get(flag.id);
    merged.set(flag.id, {
      ...current,
      ...flag,
      description:
        typeof flag.description === 'string' && flag.description.trim().length > 0
          ? flag.description
          : current?.description || '',
      audience:
        typeof flag.audience === 'string' && flag.audience.trim().length > 0
          ? flag.audience
          : current?.audience || 'all',
    });
  }

  return [...merged.values()].sort((left, right) => left.id.localeCompare(right.id));
}
