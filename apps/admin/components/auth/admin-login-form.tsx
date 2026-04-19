'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowRight, LockKeyhole, ShieldCheck } from 'lucide-react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { Button } from '@/components/ui/button';
import { getFirebaseClientAuth } from '@/lib/firebase-client';

export function AdminLoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setError(null);

    try {
      const auth = getFirebaseClientAuth();
      const credentials = await signInWithEmailAndPassword(auth, email, password);
      const idToken = await credentials.user.getIdToken(true);

      const response = await fetch('/api/session/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken }),
      });

      const payload = (await response.json()) as { error?: string };
      if (!response.ok) {
        throw new Error(payload.error || 'Unable to start an admin session.');
      }

      router.replace('/');
      router.refresh();
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : 'Unable to sign in.',
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form className="space-y-5" onSubmit={onSubmit}>
      <div className="grid gap-5">
        <div className="space-y-2">
          <label
            htmlFor="email"
            className="text-sm font-semibold tracking-[-0.01em] text-[var(--mg-primary-strong)]"
          >
            Admin email
          </label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            autoComplete="email"
            className="w-full rounded-[22px] border border-[var(--mg-border)] bg-[linear-gradient(180deg,#fbfdff_0%,#f3f8fe_100%)] px-4 py-3.5 text-sm text-[var(--mg-text)] shadow-[inset_0_1px_0_rgba(255,255,255,0.7)] outline-none transition placeholder:text-[rgba(100,116,139,0.7)] focus:border-[var(--mg-primary)] focus:bg-white focus:shadow-[0_0_0_4px_rgba(0,102,204,0.12)]"
            placeholder="name@moodgenie.com"
            required
          />
        </div>
        <div className="space-y-2">
          <label
            htmlFor="password"
            className="text-sm font-semibold tracking-[-0.01em] text-[var(--mg-primary-strong)]"
          >
            Password
          </label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
            className="w-full rounded-[22px] border border-[var(--mg-border)] bg-[linear-gradient(180deg,#fbfdff_0%,#f3f8fe_100%)] px-4 py-3.5 text-sm text-[var(--mg-text)] shadow-[inset_0_1px_0_rgba(255,255,255,0.7)] outline-none transition placeholder:text-[rgba(100,116,139,0.7)] focus:border-[var(--mg-primary)] focus:bg-white focus:shadow-[0_0_0_4px_rgba(0,102,204,0.12)]"
            placeholder="Enter your password"
            required
          />
        </div>
      </div>
      {error ? (
        <div className="rounded-[20px] border border-[rgba(226,83,74,0.18)] bg-[rgba(226,83,74,0.08)] px-4 py-3 text-sm leading-6 text-[var(--mg-danger)]">
          {error}
        </div>
      ) : null}

      <div className="rounded-[24px] border border-[rgba(0,102,204,0.12)] bg-[linear-gradient(180deg,rgba(240,247,255,0.96),rgba(250,252,255,0.96))] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.7)]">
        <div className="flex items-start gap-3">
          <div className="rounded-2xl bg-white p-2.5 text-[var(--mg-primary)] shadow-[0_12px_24px_rgba(0,59,115,0.08)]">
            <ShieldCheck className="h-5 w-5" />
          </div>
          <div className="space-y-2">
            <p className="text-sm font-semibold tracking-[-0.01em] text-[var(--mg-primary-strong)]">
              Privileged access is audited.
            </p>
            <p className="text-sm leading-6 text-[rgba(51,65,85,0.82)]">
              Sessions are issued only after a verified Firebase admin sign-in.
              Production access should stay protected with multi-factor
              authentication and device trust.
            </p>
          </div>
        </div>
      </div>

      <Button
        type="submit"
        size="lg"
        className="h-12 w-full justify-center rounded-[22px] bg-[linear-gradient(135deg,#003b73_0%,#0066cc_56%,#00b4d8_100%)] text-white shadow-[0_18px_34px_rgba(0,59,115,0.22)] hover:brightness-[0.98]"
        disabled={isSubmitting}
      >
        <LockKeyhole className="h-4 w-4" />
        {isSubmitting ? 'Signing in…' : 'Access Admin Suite'}
        {!isSubmitting ? <ArrowRight className="h-4 w-4" /> : null}
      </Button>
    </form>
  );
}
