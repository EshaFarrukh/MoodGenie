import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { updateDataRightsJobOps } from '@/lib/dal';

const VALID_OPS_STATUSES = ['open', 'acknowledged', 'in_progress', 'closed'];

export async function POST(
  request: Request,
  context: { params: Promise<{ jobId: string }> },
) {
  try {
    const admin = await requireAdminActionSession([
      'super_admin',
      'support_ops',
    ]);
    const { jobId } = await context.params;
    const body = (await request.json()) as {
      opsStatus?: 'open' | 'acknowledged' | 'in_progress' | 'closed';
      opsNotes?: string;
      opsOwner?: string;
    };

    if (!body.opsStatus || !VALID_OPS_STATUSES.includes(body.opsStatus)) {
      return NextResponse.json(
        { error: 'A valid privacy job operational status is required.' },
        { status: 400 },
      );
    }

    await updateDataRightsJobOps({
      jobId,
      opsStatus: body.opsStatus,
      opsNotes: body.opsNotes,
      opsOwner: body.opsOwner,
      actor: admin,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to update privacy job.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
