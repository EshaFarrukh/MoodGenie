import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import {
  createAdminSessionCookie,
  SESSION_COOKIE_NAME,
  SESSION_DURATION_MS,
} from '@/lib/auth';

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { idToken?: string };
    if (!body.idToken) {
      return NextResponse.json(
        { error: 'idToken is required.' },
        { status: 400 },
      );
    }

    const sessionCookie = await createAdminSessionCookie(body.idToken);
    const cookieStore = await cookies();
    cookieStore.set(SESSION_COOKIE_NAME, sessionCookie, {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      maxAge: SESSION_DURATION_MS / 1000,
      path: '/',
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : 'Unable to create admin session.',
      },
      { status: 401 },
    );
  }
}
