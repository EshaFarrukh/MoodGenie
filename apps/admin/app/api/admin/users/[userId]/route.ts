import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { deleteUserProfile } from '@/lib/dal';

export async function DELETE(
  request: Request,
  context: { params: Promise<{ userId: string }> },
) {
  try {
    const admin = await requireAdminActionSession(['super_admin']);
    const { userId } = await context.params;
    const body = (await request.json()) as { confirmation?: string };

    if (body.confirmation !== 'DELETE') {
      return NextResponse.json(
        { error: 'Type DELETE to confirm profile removal.' },
        { status: 400 },
      );
    }

    const summary = await deleteUserProfile({
      userId,
      actor: admin,
    });

    return NextResponse.json({ ok: true, summary });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : 'Unable to delete user profile.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
