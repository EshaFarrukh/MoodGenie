#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:3000}"
INTERNAL_JOB_SECRET="${INTERNAL_JOB_SECRET:-}"
COMMAND="${1:-all}"
LIMIT="${LIMIT:-50}"

if [[ -z "${INTERNAL_JOB_SECRET}" ]]; then
  echo "[notification-jobs] ERROR: Set INTERNAL_JOB_SECRET before running local notification jobs." >&2
  exit 1
fi

call_job() {
  local endpoint="$1"
  echo "[notification-jobs] POST ${endpoint}"
  curl --fail --silent --show-error \
    -X POST \
    -H "Content-Type: application/json" \
    -H "x-internal-job-secret: ${INTERNAL_JOB_SECRET}" \
    -d "{\"limit\": ${LIMIT}}" \
    "${BACKEND_URL}${endpoint}"
  echo
}

case "${COMMAND}" in
  forecasts)
    call_job "/internal/jobs/generate-mood-forecasts"
    ;;
  reminders)
    call_job "/internal/jobs/send-daily-mood-reminders"
    ;;
  appointment-reminders)
    call_job "/internal/jobs/send-appointment-reminders"
    ;;
  retries)
    call_job "/internal/jobs/process-notification-retries"
    ;;
  all)
    call_job "/internal/jobs/generate-mood-forecasts"
    call_job "/internal/jobs/send-daily-mood-reminders"
    call_job "/internal/jobs/send-appointment-reminders"
    call_job "/internal/jobs/process-notification-retries"
    ;;
  *)
    echo "Usage: $0 {all|forecasts|reminders|appointment-reminders|retries}" >&2
    exit 1
    ;;
esac

echo "[notification-jobs] Done."
