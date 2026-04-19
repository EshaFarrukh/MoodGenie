import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { updateAIIncidentOps } from '@/lib/dal';

const VALID_STATUSES = ['open', 'acknowledged', 'in_progress', 'resolved'];

export async function POST(
  request: Request,
  context: { params: Promise<{ incidentId: string }> },
) {
  try {
    const admin = await requireAdminActionSession([
      'super_admin',
      'trust_safety',
      'support_ops',
    ]);
    const { incidentId } = await context.params;
    const body = (await request.json()) as {
      status?: 'open' | 'acknowledged' | 'in_progress' | 'resolved';
      opsNotes?: string;
      assignedTo?: string;
    };

    if (!body.status || !VALID_STATUSES.includes(body.status)) {
      return NextResponse.json(
        { error: 'A valid AI incident status is required.' },
        { status: 400 },
      );
    }

    await updateAIIncidentOps({
      incidentId,
      status: body.status,
      opsNotes: body.opsNotes,
      assignedTo: body.assignedTo,
      actor: admin,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to update AI incident.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
