import { NextResponse } from 'next/server';
import { getFirebaseAdminApp } from '@/lib/firebase-admin';
import { buildAdminHealthSnapshot } from '@/lib/local-health';

export async function GET() {
  let firebaseAdminInitialized = false;

  try {
    getFirebaseAdminApp();
    firebaseAdminInitialized = true;
  } catch {
    firebaseAdminInitialized = false;
  }

  const payload = buildAdminHealthSnapshot({ firebaseAdminInitialized });
  return NextResponse.json(payload, {
    status: payload.ok ? 200 : 503,
  });
}
