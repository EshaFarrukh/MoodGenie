import { redirect } from 'next/navigation';
import {
  Activity,
  Bot,
  HeartPulse,
  ShieldCheck,
  Stethoscope,
} from 'lucide-react';
import { AdminLoginForm } from '@/components/auth/admin-login-form';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { getCurrentAdminSession } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export default async function LoginPage() {
  const session = await getCurrentAdminSession();
  if (session) {
    redirect('/');
  }

  const heroCapabilities = [
    {
      icon: Stethoscope,
      title: 'Therapist approvals',
      description: 'Credential review and workforce readiness.',
    },
    {
      icon: HeartPulse,
      title: 'Privacy workflows',
      description: 'Consent, support, and request handling.',
    },
    {
      icon: Bot,
      title: 'AI safety review',
      description: 'Incidents, quality checks, and release confidence.',
    },
  ];

  return (
    <main className="min-h-screen bg-[radial-gradient(circle_at_top_left,rgba(42,123,229,0.18),transparent_24%),radial-gradient(circle_at_bottom_right,rgba(43,185,238,0.16),transparent_22%),linear-gradient(180deg,#f7fbff_0%,#eff5fd_52%,#edf4fc_100%)] px-5 py-5 sm:px-8 lg:px-10 xl:px-12">
      <section className="mx-auto flex min-h-[calc(100vh-2.5rem)] max-w-[1480px] items-center">
        <div className="grid w-full items-stretch gap-6 xl:grid-cols-2">
          <Card className="relative h-full overflow-hidden border-[rgba(85,147,241,0.18)] bg-[linear-gradient(145deg,#0f4fa5_0%,#1463c8_44%,#1f86db_100%)] text-white shadow-[0_30px_90px_rgba(20,77,152,0.24)] xl:min-h-[640px]">
            <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(255,255,255,0.2),transparent_28%),radial-gradient(circle_at_bottom_right,rgba(146,220,255,0.24),transparent_24%),linear-gradient(180deg,rgba(255,255,255,0.05),rgba(255,255,255,0))]" />
            <CardContent className="relative flex h-full flex-col justify-between gap-8 p-7 sm:p-8 xl:p-9">
              <div className="space-y-7">
                <div className="inline-flex w-fit items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white/84 backdrop-blur-sm">
                  <ShieldCheck className="h-4 w-4" />
                  MoodGenie Admin Console
                </div>

                <div className="max-w-xl space-y-4">
                  <div className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.16em] text-white/72">
                    <HeartPulse className="h-3.5 w-3.5" />
                    Blue wellness operations
                  </div>
                  <h1 className="max-w-[11ch] text-[clamp(2.35rem,3.6vw,3.7rem)] font-semibold leading-[0.97] tracking-[-0.055em] text-white">
                    Control care operations with clarity.
                  </h1>
                  <p className="max-w-md text-[0.98rem] leading-6 text-[rgba(234,244,255,0.82)] sm:text-base">
                    Review approvals, privacy workflows, and platform safety from one
                    trusted workspace.
                  </p>
                </div>

                <div className="grid auto-rows-fr gap-3 sm:grid-cols-3">
                  {heroCapabilities.map((item) => {
                    const Icon = item.icon;
                    return (
                      <div
                        key={item.title}
                        className="flex h-full flex-col rounded-[22px] border border-white/14 bg-[linear-gradient(180deg,rgba(255,255,255,0.13),rgba(255,255,255,0.08))] p-4 backdrop-blur-[3px]"
                      >
                        <div className="mb-3 inline-flex w-fit rounded-2xl bg-white/12 p-2.5 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.1)]">
                          <Icon className="h-4.5 w-4.5" />
                        </div>
                        <h2 className="text-[1rem] font-semibold tracking-[-0.03em] text-white">
                          {item.title}
                        </h2>
                        <p className="mt-1.5 flex-1 text-sm leading-5 text-[rgba(235,244,255,0.74)]">
                          {item.description}
                        </p>
                      </div>
                    );
                  })}
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-3 rounded-[24px] border border-white/12 bg-white/10 px-4 py-3.5 text-sm text-[rgba(235,244,255,0.82)]">
                <span className="rounded-full bg-white/12 px-3 py-1.5 font-medium text-white">
                  Audited sessions
                </span>
                <span className="rounded-full bg-white/12 px-3 py-1.5 font-medium text-white">
                  Role-based access
                </span>
                <span className="rounded-full bg-white/12 px-3 py-1.5 font-medium text-white">
                  Live operational visibility
                </span>
              </div>
            </CardContent>
          </Card>

          <div className="flex h-full items-stretch">
            <Card className="flex h-full w-full flex-col border-[rgba(0,102,204,0.14)] bg-[linear-gradient(180deg,rgba(255,255,255,0.96),rgba(246,251,255,0.98))] shadow-[0_28px_80px_rgba(0,59,115,0.12)] xl:min-h-[640px]">
              <CardHeader className="flex-col items-start gap-3 border-b border-[rgba(0,102,204,0.1)] pb-4 pt-7">
                <div className="inline-flex items-center gap-2 rounded-full bg-[rgba(0,102,204,0.09)] px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.18em] text-[var(--mg-primary)]">
                  <Activity className="h-4 w-4" />
                  Internal admin access
                </div>
                <div className="space-y-2">
                  <CardTitle className="text-[1.95rem] leading-none tracking-[-0.06em] text-[var(--mg-primary-strong)]">
                    Sign in to MoodGenie Admin
                  </CardTitle>
                  <p className="max-w-xl text-[0.97rem] leading-6 text-[rgba(42,67,103,0.76)]">
                    Use your verified Firebase admin account to access the operational
                    workspace.
                  </p>
                </div>
              </CardHeader>
              <CardContent className="flex flex-1 flex-col justify-center space-y-5 pt-5">
                <div className="grid auto-rows-fr gap-3 rounded-[24px] border border-[rgba(0,102,204,0.08)] bg-[linear-gradient(180deg,rgba(220,238,255,0.64),rgba(244,250,255,0.96))] p-4 sm:grid-cols-3">
                  {[
                    {
                      title: 'Therapist approvals',
                      helper: 'Credential review and workforce readiness',
                    },
                    {
                      title: 'Privacy operations',
                      helper: 'Support, consent, and data request handling',
                    },
                    {
                      title: 'AI safety controls',
                      helper: 'Incident review and release confidence',
                    },
                  ].map((item) => (
                    <div
                      key={item.title}
                      className="flex h-full flex-col rounded-[20px] border border-[rgba(0,102,204,0.08)] bg-white/88 px-4 py-4 shadow-[0_10px_24px_rgba(0,59,115,0.05)]"
                    >
                      <div className="text-sm font-semibold tracking-[-0.02em] text-[var(--mg-primary-strong)]">
                        {item.title}
                      </div>
                      <p className="mt-2 flex-1 text-sm leading-5 text-[rgba(42,67,103,0.68)]">
                        {item.helper}
                      </p>
                    </div>
                  ))}
                </div>

                <AdminLoginForm />
              </CardContent>
            </Card>
          </div>
        </div>
      </section>
    </main>
  );
}
