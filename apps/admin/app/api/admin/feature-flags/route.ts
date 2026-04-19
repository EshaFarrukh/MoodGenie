import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { upsertFeatureFlag } from '@/lib/dal';

export async function POST(request: Request) {
  try {
    const admin = await requireAdminActionSession([
      'super_admin',
      'trust_safety',
    ]);
    const body = (await request.json()) as {
      id?: string;
      description?: string;
      enabled?: boolean;
      rollout?: number;
      audience?: string;
      changeReason?: string;
    };

    if (!body.id) {
      return NextResponse.json(
        { error: 'Flag id is required.' },
        { status: 400 },
      );
    }

    await upsertFeatureFlag({
      id: body.id,
      description: body.description || '',
      enabled: body.enabled === true,
      rollout:
        typeof body.rollout === 'number'
          ? Math.max(0, Math.min(100, body.rollout))
          : 100,
      audience: body.audience || 'all',
      changeReason: body.changeReason,
      actor: admin,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to save feature flag.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
