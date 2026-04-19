import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { applyTherapistDecision } from '@/lib/dal';

export async function POST(
  request: Request,
  context: { params: Promise<{ therapistId: string }> },
) {
  try {
    const admin = await requireAdminActionSession([
      'super_admin',
      'clinical_ops',
    ]);
    const { therapistId } = await context.params;
    const body = (await request.json()) as {
      decision?: 'approve' | 'reject' | 'suspend';
      notes?: string;
      verificationMethod?: string;
      verificationReference?: string;
    };

    if (
      !body.decision ||
      !['approve', 'reject', 'suspend'].includes(body.decision)
    ) {
      return NextResponse.json(
        { error: 'A valid decision is required.' },
        { status: 400 },
      );
    }

    await applyTherapistDecision({
      therapistId,
      decision: body.decision,
      notes: body.notes,
      verificationMethod: body.verificationMethod,
      verificationReference: body.verificationReference,
      actor: admin,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to save therapist decision.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
