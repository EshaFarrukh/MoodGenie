import { NextResponse } from 'next/server';
import {
  AdminSessionAccessError,
  requireAdminActionSession,
} from '@/lib/auth';
import { createSupportCase } from '@/lib/dal';

const VALID_PRIORITIES = ['low', 'normal', 'high', 'urgent'];

export async function POST(request: Request) {
  try {
    const admin = await requireAdminActionSession([
      'super_admin',
      'support_ops',
      'clinical_ops',
    ]);
    const body = (await request.json()) as {
      title?: string;
      summary?: string;
      priority?: 'low' | 'normal' | 'high' | 'urgent';
      category?: string;
      requesterId?: string;
    };

    if (!body.title || !body.category) {
      return NextResponse.json(
        { error: 'Title and category are required.' },
        { status: 400 },
      );
    }

    await createSupportCase({
      title: body.title,
      summary: body.summary,
      priority:
        body.priority && VALID_PRIORITIES.includes(body.priority)
          ? body.priority
          : 'normal',
      category: body.category,
      requesterId: body.requesterId,
      actor: admin,
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to create support case.',
      },
      {
        status:
          error instanceof AdminSessionAccessError ? error.status : 500,
      },
    );
  }
}
