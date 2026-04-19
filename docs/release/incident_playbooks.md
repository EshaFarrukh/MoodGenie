# MoodGenie Incident Playbooks

## AI outage
1. Confirm `/api/health` degraded state.
2. Verify the mobile app is showing degraded or fallback banners.
3. Open `/ai-ops/incidents` and assign an incident owner.
4. Disable risky AI features or feature flags if required.
5. Post status internally and keep audit notes on the incident.

## Privacy workflow failure
1. Identify the affected `data_rights_job`.
2. Move the job to an acknowledged/in-progress state with an assigned owner.
3. Rerun the secure backend flow instead of using Firebase console shortcuts.
4. Validate exported artifacts or deletion completion.
5. Record resolution details in the job notes and audit trail.

## Therapist trust breach
1. Suspend the therapist account through admin.
2. Review therapist review history and linked appointments.
3. Notify support/clinical operations owners.
4. Preserve notes, timestamps, and affected entities for investigation.

## Calling degradation
1. Check TURN readiness and recent call-health posture.
2. Confirm whether failures are signaling-related or network/TURN related.
3. If TURN is unavailable, de-scope therapist calling from release traffic.
4. Keep appointments operational even if calling is disabled.
