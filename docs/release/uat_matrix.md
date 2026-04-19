# MoodGenie UAT Matrix

## User journeys
1. Sign up as a user and confirm role routing works.
2. Log a mood, reopen profile, and verify cached stats update correctly.
3. Use AI chat in healthy mode and confirm responses persist.
4. Trigger degraded/fallback AI behavior and confirm the banner is visible.
5. Export data and confirm the secure share flow returns the expected files.
6. Request account deletion and confirm the app signs out after backend completion.

## Therapist journeys
1. Sign up as a therapist and confirm the account remains pending.
2. Approve the therapist through admin.
3. Confirm the therapist becomes discoverable only after approval.
4. Book an appointment as a user and confirm the therapist receives the request.
5. Confirm the appointment as a therapist and verify user + therapist dashboards match.
6. Start therapist chat/call flows and confirm rooms are created through secure backend operations.

## Admin journeys
1. Sign in with each admin role and verify RBAC hides unauthorized modules.
2. Review a therapist, add notes, and confirm the audit log entry.
3. Open an AI incident, assign it, and confirm the status mutation is recorded.
4. Open a privacy job, move it through operations states, and verify audit coverage.
5. Inspect system health and release-readiness pages for current launch posture.

## Accessibility checks
1. Walk splash, home navigation, chat, and profile with TalkBack/VoiceOver.
2. Confirm shared bottom navigation passes tap-target guidelines.
3. Confirm critical labels and tooltips are present for shared navigation and chat options.

## Launch blockers
- Any failed export/delete workflow
- Any therapist discoverability without admin approval
- Any missing audit trail for privileged actions
- Any unowned AI incident with release-severity impact
