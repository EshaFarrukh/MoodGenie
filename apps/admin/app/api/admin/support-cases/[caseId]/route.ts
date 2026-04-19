import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { updateSupportCase } from '@/lib/dal';

const VALID_PRIORITIES = ['low', 'normal', 'high', 'urgent'];
const VALID_STATUSES = [
  'open',
  'in_progress',
  'waiting_on_user',
  'resolved',
  'closed',
];

export async function POST(
  request: Request,
  context: { params: Promise<{ caseId: string }> },
) {
  try {
    const admin = await requireAdminActionSession([
      'super_admin',
      'support_ops',
      'clinical_ops',
    ]);
    const { caseId } = await context.params;
    const body = (await request.json()) as {
      status?: 'open' | 'in_progress' | 'waiting_on_user' | 'resolved' | 'closed';
      priority?: 'low' | 'normal' | 'high' | 'urgent';
      owner?: string;
      summary?: string;
    };

    if (!body.status || !VALID_STATUSES.includes(body.status)) {
      return NextResponse.json(
        { error: 'A valid case status is required.' },
        { status: 400 },
      );
    }

    await updateSupportCase({
      caseId,
      status: body.status,
      priority:
        body.priority && VALID_PRIORITIES.includes(body.priority)
          ? body.priority
          : 'normal',
      owner: body.owner,
      summary: body.summary,
      actor: admin,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to update support case.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
