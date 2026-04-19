import Link from 'next/link';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { KpiCard } from '@/components/ui/kpi-card';
import { requireAdminSession } from '@/lib/auth';
import { getSystemHealthSnapshot } from '@/lib/dal';

const automatedGates = [
  'Flutter widget, auth, and accessibility smoke tests are green.',
  'Firebase rules tests pass in CI and match the deployed ruleset.',
  'Android release build and iOS no-codesign build succeed from a clean checkout.',
          'Admin production build, backend syntax checks, and release smoke scripts complete without drift.',
  'Unhandled mobile errors and AI degraded/fallback events are visible in the control plane.',
];

const manualGoLiveChecks = [
  'Production Android and iOS identities, signing assets, and store records are final.',
  'Firebase indexes and security rules are deployed to the production project.',
  'TURN credentials are configured for calling before enabling therapist call traffic.',
  'Store privacy disclosures, privacy manifest answers, and in-app policy copy are aligned.',
  'Named owners exist for therapist review, privacy jobs, AI incidents, and outage response.',
];

const uatJourneys = [
  'User sign up → log mood → export data → request delete account.',
  'Therapist sign up → admin approval → user booking → therapist confirm → session appears for both sides.',
  'AI healthy, degraded, fallback, and crisis override states are each visible and understandable in-app.',
  'Admin can approve a therapist, triage an AI incident, process a privacy job, and inspect an appointment trail.',
  'Rollback and incident drills can be run without depending on raw Firebase console edits.',
];

const incidentPlaybook = [
  'AI outage: confirm degraded health, surface fallback mode, review incident inbox, disable risky flags if needed.',
  'Therapist trust issue: suspend the therapist, preserve audit trail, review appointments, notify support owner.',
  'Privacy workflow failure: acknowledge job, assign owner, rerun through secure backend flow, document resolution.',
  'Call reliability incident: validate TURN readiness, inspect call-health diagnostics, de-scope calls if production TURN is unavailable.',
];

export default async function ReleaseReadinessPage() {
  await requireAdminSession([
    'super_admin',
    'support_ops',
    'trust_safety',
    'clinical_ops',
    'read_only_analytics',
  ]);

  const summary = await getSystemHealthSnapshot();
  const kpis = [
    {
      label: 'Open AI incidents',
      value: summary.openAiIncidents,
      helper: 'Launch should pause if safety incidents are unowned or growing.',
    },
    {
      label: 'Privacy queue',
      value: summary.privacyQueue,
      helper: 'Export and deletion requests must stay inside SLA before launch.',
    },
    {
      label: 'Therapist backlog',
      value: summary.therapistReviewBacklog,
      helper: 'Public growth should not open while the trust queue is stale.',
    },
    {
      label: 'Unhandled mobile errors',
      value: summary.recentUnhandledErrors,
      helper: 'Release candidates should keep new crash-class signals under active review.',
    },
  ];

  return (
    <div className="space-y-6">
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.label} {...kpi} />
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Automated gates</CardTitle>
              <CardDescription>
                These checks should be green before any production cutover starts.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {automatedGates.map((item) => (
              <div
                key={item}
                className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]"
              >
                {item}
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Manual go-live checks</CardTitle>
              <CardDescription>
                These items still require named human sign-off even with good CI.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {manualGoLiveChecks.map((item) => (
              <div
                key={item}
                className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]"
              >
                {item}
              </div>
            ))}
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>UAT journeys</CardTitle>
              <CardDescription>
                Product, support, and trust operations should walk these flows before launch.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {uatJourneys.map((item) => (
              <div
                key={item}
                className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]"
              >
                {item}
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Incident and rollback drills</CardTitle>
              <CardDescription>
                If the team cannot run these drills, the release is not truly ready.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {incidentPlaybook.map((item) => (
              <div
                key={item}
                className="rounded-[22px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] px-4 py-4 text-sm leading-6 text-[var(--mg-muted)]"
              >
                {item}
              </div>
            ))}
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>Critical launch commands</CardTitle>
              <CardDescription>
                Use the repeatable smoke path instead of ad hoc terminal commands.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent>
          <pre className="overflow-x-auto rounded-[24px] border border-[var(--mg-border)] bg-[#0b2442] p-5 text-xs leading-6 text-[#eef7ff]">
{`./scripts/release_smoke.sh

# high-signal manual follow-up
flutter build apk --release
flutter build ios --no-codesign
cd apps/admin && npm run build
cd firebase_tests && npm test`}
          </pre>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <div>
              <CardTitle>Operational shortcuts</CardTitle>
              <CardDescription>
                Launch owners should keep these surfaces open during release week.
              </CardDescription>
            </div>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            <Link href="/ops/system-health" className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white">
              Open system health
            </Link>
            <Link href="/ai-ops/incidents" className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white">
              Review AI incidents
            </Link>
            <Link href="/support/data-requests" className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white">
              Check privacy jobs
            </Link>
            <Link href="/therapists/review-queue" className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white">
              Clear therapist backlog
            </Link>
            <Link href="/audit-log" className="rounded-[24px] border border-[var(--mg-border)] bg-[var(--mg-surface-subtle)] p-4 text-sm font-semibold text-[var(--mg-heading)] transition hover:border-[var(--mg-border-strong)] hover:bg-white sm:col-span-2">
              Inspect audit trail
            </Link>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
