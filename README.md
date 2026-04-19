# MoodGenie

MoodGenie is a production-oriented wellness platform with three operating surfaces in one repo:

- a Flutter mobile app for mood tracking, AI emotional-support chat, therapist discovery, booking, and therapist communication
- a privileged Node backend for secure mutations, AI gateway behavior, data-rights operations, and release-health telemetry
- a Next.js admin dashboard for therapist approvals, support operations, privacy jobs, AI incident handling, feature governance, and launch readiness

## Repository surfaces

### Mobile app
- Flutter + Dart
- Firebase Auth, Firestore, Storage
- Provider-based app state with release telemetry, localization scaffolding, and Firebase security rules in repo

### Admin dashboard
- `apps/admin`
- Next.js App Router + TypeScript
- RBAC, audit-aware admin shell, therapist review, privacy jobs, AI ops, appointments, system health, and release-readiness tooling

### Backend
- `backend`
- Express + Firebase Admin SDK
- Authenticated AI proxying, secure appointment/chat/call mutations, mobile telemetry ingestion, and privacy workflow orchestration

## Core flows

- User sign up / sign in
- Mood logging, history, analytics, and profile progress
- AI support chat with visible degraded/fallback states
- Therapist onboarding, approval, discovery, booking, therapist chat, and calling
- Admin review for therapist trust, privacy jobs, AI incidents, and operational readiness

## Quick start

### Mobile
```bash
flutter pub get
flutter run
```

### Admin
```bash
cd apps/admin
npm install
npm run dev
```

The admin dashboard runs locally at `http://127.0.0.1:3001`.

### Backend
```bash
cd backend
npm install
npm start
```

Copy `backend/.env.example` to `backend/.env` before first setup if you are
bringing up a fresh local backend.

## One-command local stack

```bash
./scripts/local_stack.sh start
```

This boots Ollama, the local backend, the admin dashboard on `http://127.0.0.1:3001`,
the iOS Simulator, and the Flutter app with an explicit local `BACKEND_URL`.

Useful commands:

```bash
./scripts/local_stack.sh status
./scripts/local_stack.sh stop
```

If you want shell-level commands from any directory on your Mac, install the
global wrappers once and then use:

```bash
run moodgenie
status moodgenie
stop moodgenie
gcloud --version
```

On first run, the launcher will create `apps/admin/.env.local` from
`apps/admin/.env.example` if it does not exist yet and backfill the committed
public Firebase web config automatically.

The launcher now always uses real Firebase auth. For real local auth to work
end to end, you still need one Firebase Admin credential source:

- `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` in `apps/admin/.env.local`
- `GOOGLE_APPLICATION_CREDENTIALS`
- or `gcloud auth application-default login`

## Notification system setup

The repo now includes:

- push + in-app notification infrastructure in the Flutter app
- backend-managed notification preferences, inbox docs, delivery logs, retry queues, and scheduled jobs
- appointment lifecycle notifications for both users and therapists
- deterministic mood forecasting with guarded AI wellness copy
- admin notification-health visibility under `Notification Ops`

To finish live delivery outside the repo, configure:

- Firebase Cloud Messaging / APNs for real device push delivery
- Postmark via `POSTMARK_SERVER_TOKEN` and `POSTMARK_FROM_EMAIL`
- `INTERNAL_JOB_SECRET` for internal scheduled job execution
- Google Cloud Scheduler hitting:
  - `/internal/jobs/generate-mood-forecasts`
  - `/internal/jobs/send-daily-mood-reminders`
  - `/internal/jobs/send-appointment-reminders`
  - `/internal/jobs/process-notification-retries`

For local manual job testing:

```bash
INTERNAL_JOB_SECRET=your-secret ./scripts/notification_jobs_local.sh all
```

## Quality gates

### Core validation
```bash
flutter test
flutter analyze --no-fatal-infos
cd firebase_tests && npm test
cd apps/admin && npm run build
cd backend && npm run check
```

### Release smoke
```bash
./scripts/release_smoke.sh
```

## Release operations docs

- `docs/release/release_candidate_checklist.md`
- `docs/release/uat_matrix.md`
- `docs/release/incident_playbooks.md`
- `docs/release/launch_cutover_plan.md`
- `docs/release/production_identity_and_signing.md`

## Project structure

```text
apps/admin/        Next.js control plane
backend/           privileged API and operational service layer
firebase_tests/    Firebase rules test suite
lib/               Flutter mobile application
docs/release/      launch, UAT, incident, and cutover runbooks
scripts/           repeatable release smoke scripts
```

## Current operational expectations

- Firebase rules and indexes are source-controlled in this repo.
- Privileged therapist approval and privacy workflows are expected to run through admin surfaces, not direct console edits.
- AI incidents, privacy jobs, and launch posture should be monitored from the admin dashboard before public release.
