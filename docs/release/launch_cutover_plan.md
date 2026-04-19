# MoodGenie Launch Cutover Plan

## T-7 days
- Freeze launch scope.
- Clear therapist review backlog.
- Finalize store metadata, privacy declarations, and production config.
- Run the full UAT matrix.

## T-2 days
- Run `./scripts/release_smoke.sh`.
- Deploy latest Firebase rules and indexes to staging, then production after sign-off.
- Confirm admin roles, audit logging, and feature flags in production.
- Verify AI health, privacy jobs, and therapist approval workflow.

## Launch day
- Open admin pages:
  - `/ops/system-health`
  - `/ops/release-readiness`
  - `/ai-ops/incidents`
  - `/support/data-requests`
  - `/audit-log`
- Confirm no unowned high-severity incidents.
- Confirm export/delete and therapist approval operations owners are online.
- Publish mobile builds only after final release owner sign-off.

## Rollback triggers
- Severe AI safety incident
- Widespread login failure
- Broken export/delete workflow
- Broken booking/confirmation flow
- Call feature harming core therapist operations

## Rollback response
- Pause new rollout.
- Disable risky flags or call features first when possible.
- Revert backend deployment if required.
- Communicate status and capture an audit/event trail.
