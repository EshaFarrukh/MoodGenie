# MoodGenie Admin Suite

This is the production admin dashboard for MoodGenie. It is intended to be the
operational control plane for therapist review, privacy workflows, AI safety,
feature flags, and audit visibility.

## Stack

- Next.js App Router
- TypeScript
- Firebase Auth (web) for admin sign-in
- Firebase Admin SDK for server-side data access and privileged actions

## Required environment variables

Copy `.env.example` to `.env.local` and provide:

- public Firebase web config for admin sign-in
- Firebase Admin credentials or Application Default Credentials for real local auth
- `ADMIN_BOOTSTRAP_UIDS` for initial super-admin bootstrap if needed

## Local development

```bash
npm install
npm run dev
```

The admin dashboard runs locally at `http://127.0.0.1:3001`.

`run moodgenie` will create `.env.local` automatically from `.env.example` if
it is missing, and it will backfill the committed public Firebase values into
any blank Firebase web config keys.

For real local auth, you still need one Firebase Admin credential source:

- `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` in `.env.local`, or
- `GOOGLE_APPLICATION_CREDENTIALS`, or
- `gcloud auth application-default login`

## Current modules

- Overview dashboard
- Therapist review queue with approval / rejection / suspension actions
- User directory
- Appointment operations
- AI incident view
- Privacy jobs view
- Support cases view
- Feature flags
- Audit log

## Production notes

- Keep all privileged data access server-side.
- Use `admin_users/{uid}` for long-term RBAC rather than relying only on bootstrap UIDs.
- Every privileged mutation should create an `admin_audit_logs` entry.
- Add CI install/build/typecheck before shipping the admin app.
