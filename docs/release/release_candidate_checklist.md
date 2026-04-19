# MoodGenie Release Candidate Checklist

## Automated gates
- `flutter pub get`
- `flutter test`
- `flutter analyze --no-fatal-infos`
- `cd firebase_tests && npm test`
- `cd apps/admin && npm run build`
- `cd backend && node --check server.js`
- `flutter build apk --release`
- `flutter build ios --no-codesign`

## Manual release sign-off
- Android package identity and signing assets are final.
- iOS bundle identity, provisioning, and signing are final.
- Firebase rules and indexes are deployed to the production project.
- TURN credentials are configured if therapist calling remains enabled.
- Production app config and feature flags are reviewed by named owners.
- Privacy manifest answers, store disclosures, and in-app privacy text align.

## Product readiness checks
- Therapist approval queue is clear or within SLA.
- Open AI incidents are assigned and no high-severity issue is unowned.
- Privacy/export/delete jobs are working through the secure backend path.
- AI degraded/fallback states are explicit and understandable in-app.
- Booking lifecycle is visible and consistent across user, therapist, and admin.

## Final sign-off roles
- Engineering lead
- Clinical operations owner
- Support/privacy owner
- Trust and safety owner
- Release owner
