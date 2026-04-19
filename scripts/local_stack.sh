#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
ADMIN_DIR="$ROOT_DIR/apps/admin"
IOS_WORKSPACE="$ROOT_DIR/ios/Runner.xcworkspace"
RUNTIME_DIR="$ROOT_DIR/.local/local-stack"
PID_DIR="$RUNTIME_DIR/pids"
LOG_DIR="$RUNTIME_DIR/logs"
STATE_FILE="$RUNTIME_DIR/state.env"
BACKEND_ENV_FILE="$BACKEND_DIR/.env"
ADMIN_ENV_FILE=""

COMMAND="${1:-start}"
if [[ $# -gt 0 ]]; then
  shift
fi

TARGET="ios"
AUTH_MODE="real"
OPEN_UI="yes"
OPEN_XCODE="no"

BACKEND_PORT="3000"
BACKEND_HOST="127.0.0.1"
BACKEND_URL="http://${BACKEND_HOST}:${BACKEND_PORT}"
ADMIN_PORT="3001"
ADMIN_HOST="127.0.0.1"
ADMIN_URL="http://${ADMIN_HOST}:${ADMIN_PORT}"
OLLAMA_URL="http://127.0.0.1:11434"
OLLAMA_MODEL="moodgenie"
SIMULATOR_UDID=""

BACKEND_OWNED="no"
ADMIN_OWNED="no"
OLLAMA_OWNED="no"
FLUTTER_IOS_OWNED="no"
FLUTTER_MACOS_OWNED="no"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/local_stack.sh start [--target ios|macos|both] [--open-ui yes|no] [--open-xcode yes|no]
  ./scripts/local_stack.sh stop
  ./scripts/local_stack.sh status
EOF
}

log() {
  printf '[local-stack] %s\n' "$1"
}

warn() {
  printf '[local-stack] WARNING: %s\n' "$1" >&2
}

fail() {
  printf '[local-stack] ERROR: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command '$1' is not installed or not on PATH."
  fi
}

ensure_runtime_dirs() {
  mkdir -p "$PID_DIR" "$LOG_DIR"
}

pid_file() {
  printf '%s/%s.pid\n' "$PID_DIR" "$1"
}

log_file() {
  printf '%s/%s.log\n' "$LOG_DIR" "$1"
}

read_pid() {
  local file
  file="$(pid_file "$1")"
  if [[ -f "$file" ]]; then
    tr -d '[:space:]' <"$file"
  fi
}

is_pid_running() {
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1
}

write_pid() {
  printf '%s\n' "$2" >"$(pid_file "$1")"
}

remove_pid() {
  rm -f "$(pid_file "$1")"
}

port_pid() {
  { lsof -n -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -n 1; } || true
}

env_value_from_file() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi

  awk -F= -v search_key="$key" '$1 == search_key {print substr($0, index($0, "=") + 1)}' "$file" | tail -n 1
}

effective_env_value() {
  local key="$1"
  local env_value="${!key:-}"
  if [[ -n "${env_value// }" ]]; then
    printf '%s' "$env_value"
    return
  fi

  if [[ -n "$ADMIN_ENV_FILE" ]]; then
    env_value_from_file "$ADMIN_ENV_FILE" "$key"
  fi
}

upsert_env_value_in_file() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temp_file
  temp_file="$(mktemp)"

  awk -F= -v search_key="$key" -v new_value="$value" '
    BEGIN { updated = 0 }
    $1 == search_key {
      if (!updated) {
        print search_key "=" new_value
        updated = 1
      }
      next
    }
    { print }
    END {
      if (!updated) {
        print search_key "=" new_value
      }
    }
  ' "$file" >"$temp_file"

  mv "$temp_file" "$file"
}

resolve_admin_env_file() {
  if [[ -f "$ADMIN_DIR/.env.local" ]]; then
    ADMIN_ENV_FILE="$ADMIN_DIR/.env.local"
    return
  fi

  if [[ -f "$ADMIN_DIR/.env" ]]; then
    ADMIN_ENV_FILE="$ADMIN_DIR/.env"
    return
  fi

  if [[ -f "$ADMIN_DIR/.env.example" ]]; then
    cp "$ADMIN_DIR/.env.example" "$ADMIN_DIR/.env.local"
    ADMIN_ENV_FILE="$ADMIN_DIR/.env.local"
    warn "Created apps/admin/.env.local from .env.example. Fill in Firebase values if admin login does not work yet."
    return
  fi

  fail "Missing admin environment file and no apps/admin/.env.example was found."
}

backfill_admin_env_defaults() {
  local example_file="$ADMIN_DIR/.env.example"
  if [[ ! -f "$example_file" || ! -f "$ADMIN_ENV_FILE" ]]; then
    return
  fi

  local keys=(
    "NEXT_PUBLIC_FIREBASE_API_KEY"
    "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN"
    "NEXT_PUBLIC_FIREBASE_PROJECT_ID"
    "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET"
    "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID"
    "NEXT_PUBLIC_FIREBASE_APP_ID"
    "FIREBASE_PROJECT_ID"
  )
  local updated_keys=()

  for key in "${keys[@]}"; do
    local current_value
    current_value="$(env_value_from_file "$ADMIN_ENV_FILE" "$key")"
    if [[ -n "${current_value// }" ]]; then
      continue
    fi

    local default_value
    default_value="$(env_value_from_file "$example_file" "$key")"
    if [[ -z "${default_value// }" ]]; then
      continue
    fi

    upsert_env_value_in_file "$ADMIN_ENV_FILE" "$key" "$default_value"
    updated_keys+=("$key")
  done

  if (( ${#updated_keys[@]} > 0 )); then
    warn "Filled missing admin env defaults for: ${updated_keys[*]}."
  fi
}

validate_admin_env_file() {
  local missing_keys=()
  local required_keys=(
    "NEXT_PUBLIC_FIREBASE_API_KEY"
    "NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN"
    "NEXT_PUBLIC_FIREBASE_PROJECT_ID"
    "NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET"
    "NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID"
    "NEXT_PUBLIC_FIREBASE_APP_ID"
  )

  for key in "${required_keys[@]}"; do
    local value
    value="$(awk -F= -v search_key="$key" '$1 == search_key {print substr($0, index($0, "=") + 1)}' "$ADMIN_ENV_FILE" | tail -n 1)"
    if [[ -z "${value// }" ]]; then
      missing_keys+=("$key")
    fi
  done

  if (( ${#missing_keys[@]} > 0 )); then
    warn "Admin env file is missing Firebase web config values: ${missing_keys[*]}. The admin dashboard will start, but sign-in may not work until these are filled."
  fi
}

has_explicit_firebase_admin_credentials() {
  local project_id
  local client_email
  local private_key

  project_id="$(effective_env_value "FIREBASE_PROJECT_ID")"
  client_email="$(effective_env_value "FIREBASE_CLIENT_EMAIL")"
  private_key="$(effective_env_value "FIREBASE_PRIVATE_KEY")"

  [[ -n "${project_id// }" && -n "${client_email// }" && -n "${private_key// }" ]]
}

has_application_default_credentials() {
  local credentials_path="${GOOGLE_APPLICATION_CREDENTIALS:-}"
  if [[ -n "${credentials_path// }" ]]; then
    [[ -f "$credentials_path" ]]
    return
  fi

  [[ -f "$HOME/.config/gcloud/application_default_credentials.json" ]]
}

validate_real_auth_prerequisites() {
  if has_explicit_firebase_admin_credentials || has_application_default_credentials; then
    return
  fi

  fail "Real local auth needs Firebase Admin credentials. Add FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY to apps/admin/.env.local, or set GOOGLE_APPLICATION_CREDENTIALS, or run 'gcloud auth application-default login'."
}

load_backend_config() {
  if [[ ! -f "$BACKEND_ENV_FILE" ]]; then
    fail "Missing backend/.env. Create it before starting the local stack."
  fi

  local configured_model
  configured_model="$(awk -F= '/^OLLAMA_MODEL=/{print $2}' "$BACKEND_ENV_FILE" | tail -n 1)"
  if [[ -n "$configured_model" ]]; then
    OLLAMA_MODEL="$configured_model"
  fi

  local configured_ollama_url
  configured_ollama_url="$(awk -F= '/^OLLAMA_URL=/{print $2}' "$BACKEND_ENV_FILE" | tail -n 1)"
  if [[ -n "$configured_ollama_url" ]]; then
    OLLAMA_URL="$configured_ollama_url"
  fi
}

cleanup_stale_pid() {
  local name="$1"
  local pid
  pid="$(read_pid "$name")"
  if [[ -n "$pid" ]] && ! is_pid_running "$pid"; then
    remove_pid "$name"
  fi
}

health_json_matches() {
  local url="$1"
  local expression="$2"
  local payload
  if ! payload="$(curl -fsS "$url" 2>/dev/null)"; then
    return 1
  fi

  node -e "
    let raw = '';
    process.stdin.on('data', (chunk) => raw += chunk);
    process.stdin.on('end', () => {
      try {
        const data = JSON.parse(raw);
        process.exit(${expression} ? 0 : 1);
      } catch (error) {
        process.exit(1);
      }
    });
  " <<<"$payload"
}

is_ollama_reachable() {
  curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null 2>&1
}

is_ollama_model_ready() {
  local payload
  if ! payload="$(curl -fsS "${OLLAMA_URL}/api/tags" 2>/dev/null)"; then
    return 1
  fi

  OLLAMA_MODEL="$OLLAMA_MODEL" node -e "
    let raw = '';
    process.stdin.on('data', (chunk) => raw += chunk);
    process.stdin.on('end', () => {
      try {
        const data = JSON.parse(raw);
        const configuredModel = String(process.env.OLLAMA_MODEL || '').trim().toLowerCase();
        const variants = (value) => {
          const normalized = String(value || '').trim().toLowerCase();
          if (!normalized) return [];
          if (normalized.includes(':')) return [normalized, normalized.split(':')[0]];
          return [normalized, \`\${normalized}:latest\`];
        };
        const configured = new Set(variants(configuredModel));
        const models = Array.isArray(data.models) ? data.models : [];
        const ready = models.some((entry) => {
          const names = new Set(variants(entry && entry.name));
          return [...configured].some((variant) => names.has(variant));
        });
        process.exit(ready ? 0 : 1);
      } catch (error) {
        process.exit(1);
      }
    });
  " <<<"$payload"
}

is_backend_ready() {
  health_json_matches "${BACKEND_URL}/api/health" "data && data.ok === true && data.modelReady === true && data.backendAuthMode === 'real' && data.firebaseAdminReady === true"
}

is_admin_ready() {
  health_json_matches "${ADMIN_URL}/api/health" "data && data.ok === true && data.authMode === 'real' && data.publicConfigReady === true && data.firebaseAdminReady === true"
}

wait_for_condition() {
  local description="$1"
  local timeout_seconds="$2"
  local check_command="$3"
  local started_at
  started_at="$(date +%s)"

  while true; do
    if eval "$check_command"; then
      return 0
    fi

    local now
    now="$(date +%s)"
    if (( now - started_at >= timeout_seconds )); then
      fail "Timed out waiting for ${description}. Check logs in ${LOG_DIR}."
    fi

    sleep 2
  done
}

start_background_process() {
  local name="$1"
  local workdir="$2"
  shift 2
  local logfile
  logfile="$(log_file "$name")"
  cleanup_stale_pid "$name"
  (
    cd "$workdir"
    nohup "$@" >>"$logfile" 2>&1 &
    echo $! >"$(pid_file "$name")"
  )
}

ensure_ollama_running() {
  cleanup_stale_pid "ollama"
  if is_ollama_reachable; then
    log "Reusing existing Ollama server at ${OLLAMA_URL}."
    OLLAMA_OWNED="no"
    return
  fi

  local existing_pid
  existing_pid="$(port_pid 11434)"
  if [[ -n "$existing_pid" ]]; then
    fail "Port 11434 is already in use by PID ${existing_pid}, but Ollama is not healthy."
  fi

  log "Starting Ollama server."
  start_background_process "ollama" "$ROOT_DIR" ollama serve
  OLLAMA_OWNED="yes"
  wait_for_condition "Ollama to become reachable" 30 "is_ollama_reachable"
}

ensure_ollama_model() {
  if is_ollama_model_ready; then
    log "Ollama model '${OLLAMA_MODEL}' is ready."
    return
  fi

  log "Preparing Ollama model '${OLLAMA_MODEL}'."
  if ! ollama show phi3 >/dev/null 2>&1; then
    log "Pulling base model 'phi3'."
    ollama pull phi3 >>"$(log_file "ollama")" 2>&1
  fi

  ollama create "$OLLAMA_MODEL" -f "$BACKEND_DIR/Modelfile" >>"$(log_file "ollama")" 2>&1
  wait_for_condition "Ollama model '${OLLAMA_MODEL}'" 60 "is_ollama_model_ready"
}

ensure_backend_running() {
  cleanup_stale_pid "backend"
  if is_backend_ready; then
    log "Reusing existing backend at ${BACKEND_URL}."
    BACKEND_OWNED="no"
    return
  fi

  local existing_pid
  existing_pid="$(port_pid "$BACKEND_PORT")"
  if [[ -n "$existing_pid" ]]; then
    fail "Port ${BACKEND_PORT} is already in use by PID ${existing_pid}, but the backend is not healthy."
  fi

  log "Starting backend on ${BACKEND_URL}."
  local project_id
  local client_email
  local private_key
  project_id="$(effective_env_value "FIREBASE_PROJECT_ID")"
  client_email="$(effective_env_value "FIREBASE_CLIENT_EMAIL")"
  private_key="$(effective_env_value "FIREBASE_PRIVATE_KEY")"

  if [[ -n "${project_id// }" && -n "${client_email// }" && -n "${private_key// }" ]]; then
    start_background_process "backend" "$BACKEND_DIR" env PORT="$BACKEND_PORT" ALLOW_UNAUTHENTICATED_LOCAL=false FIREBASE_PROJECT_ID="$project_id" GOOGLE_CLOUD_PROJECT="$project_id" GCLOUD_PROJECT="$project_id" FIREBASE_CLIENT_EMAIL="$client_email" FIREBASE_PRIVATE_KEY="$private_key" npm start
  else
    if [[ -n "${project_id// }" ]]; then
      start_background_process "backend" "$BACKEND_DIR" env PORT="$BACKEND_PORT" ALLOW_UNAUTHENTICATED_LOCAL=false FIREBASE_PROJECT_ID="$project_id" GOOGLE_CLOUD_PROJECT="$project_id" GCLOUD_PROJECT="$project_id" npm start
    else
      start_background_process "backend" "$BACKEND_DIR" env PORT="$BACKEND_PORT" ALLOW_UNAUTHENTICATED_LOCAL=false npm start
    fi
  fi

  BACKEND_OWNED="yes"
  wait_for_condition "backend health on ${BACKEND_URL}" 60 "is_backend_ready"
}

ensure_admin_running() {
  cleanup_stale_pid "admin"
  if is_admin_ready; then
    log "Reusing existing admin dashboard at ${ADMIN_URL}."
    ADMIN_OWNED="no"
    return
  fi

  local existing_pid
  existing_pid="$(port_pid "$ADMIN_PORT")"
  if [[ -n "$existing_pid" ]]; then
    fail "Port ${ADMIN_PORT} is already in use by PID ${existing_pid}, but the admin dashboard is not reachable."
  fi

  log "Starting admin dashboard on ${ADMIN_URL}."
  local project_id
  project_id="$(effective_env_value "FIREBASE_PROJECT_ID")"

  if [[ -n "${project_id// }" ]]; then
    start_background_process "admin" "$ADMIN_DIR" env PORT="$ADMIN_PORT" FIREBASE_PROJECT_ID="$project_id" GOOGLE_CLOUD_PROJECT="$project_id" GCLOUD_PROJECT="$project_id" npm run dev -- --hostname "$ADMIN_HOST"
  else
    start_background_process "admin" "$ADMIN_DIR" env PORT="$ADMIN_PORT" npm run dev -- --hostname "$ADMIN_HOST"
  fi
  ADMIN_OWNED="yes"
  wait_for_condition "admin dashboard on ${ADMIN_URL}" 60 "is_admin_ready"
}

find_booted_ios_simulator_udid() {
  { xcrun simctl list devices booted 2>/dev/null | awk -F '[()]' '/iPhone/ { print $2; exit }'; } || true
}

find_available_ios_simulator_udid() {
  { xcrun simctl list devices available 2>/dev/null | awk -F '[()]' '/iPhone/ { print $2; exit }'; } || true
}

prepare_ios_simulator() {
  local booted_udid
  booted_udid="$(find_booted_ios_simulator_udid)"
  if [[ -n "$booted_udid" ]]; then
    SIMULATOR_UDID="$booted_udid"
  else
    SIMULATOR_UDID="$(find_available_ios_simulator_udid)"
  fi

  if [[ -z "$SIMULATOR_UDID" ]]; then
    fail "No available iPhone simulator was found. Install one from Xcode first."
  fi

  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null 2>&1
}

start_flutter_ios() {
  cleanup_stale_pid "flutter_ios"
  local pid
  pid="$(read_pid "flutter_ios")"
  if is_pid_running "$pid"; then
    log "Reusing existing Flutter iOS process."
    FLUTTER_IOS_OWNED="yes"
    return
  fi

  prepare_ios_simulator
  log "Starting Flutter app on iOS Simulator."
  start_background_process "flutter_ios" "$ROOT_DIR" flutter run -d "$SIMULATOR_UDID" --dart-define="BACKEND_URL=${BACKEND_URL}"
  FLUTTER_IOS_OWNED="yes"
}

start_flutter_macos() {
  cleanup_stale_pid "flutter_macos"
  local pid
  pid="$(read_pid "flutter_macos")"
  if is_pid_running "$pid"; then
    log "Reusing existing Flutter macOS process."
    FLUTTER_MACOS_OWNED="yes"
    return
  fi

  log "Starting Flutter app on macOS."
  start_background_process "flutter_macos" "$ROOT_DIR" flutter run -d macos --dart-define="BACKEND_URL=${BACKEND_URL}"
  FLUTTER_MACOS_OWNED="yes"
}

write_state() {
  cat >"$STATE_FILE" <<EOF
TARGET=${TARGET}
AUTH_MODE=${AUTH_MODE}
OPEN_UI=${OPEN_UI}
OPEN_XCODE=${OPEN_XCODE}
BACKEND_URL=${BACKEND_URL}
ADMIN_URL=${ADMIN_URL}
OLLAMA_URL=${OLLAMA_URL}
OLLAMA_MODEL=${OLLAMA_MODEL}
SIMULATOR_UDID=${SIMULATOR_UDID}
BACKEND_OWNED=${BACKEND_OWNED}
ADMIN_OWNED=${ADMIN_OWNED}
OLLAMA_OWNED=${OLLAMA_OWNED}
FLUTTER_IOS_OWNED=${FLUTTER_IOS_OWNED}
FLUTTER_MACOS_OWNED=${FLUTTER_MACOS_OWNED}
EOF
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

open_surfaces() {
  if [[ "$OPEN_UI" == "yes" ]]; then
    open "${ADMIN_URL}" >/dev/null 2>&1 || true
  fi

  if [[ "$OPEN_XCODE" == "yes" ]]; then
    open "$IOS_WORKSPACE" >/dev/null 2>&1 || true
  fi
}

terminate_owned_process() {
  local name="$1"
  local owned="$2"
  if [[ "$owned" != "yes" ]]; then
    return
  fi

  local pid
  pid="$(read_pid "$name")"
  if ! is_pid_running "$pid"; then
    remove_pid "$name"
    return
  fi

  log "Stopping ${name} (PID ${pid})."
  kill "$pid" >/dev/null 2>&1 || true

  for _ in {1..10}; do
    if ! is_pid_running "$pid"; then
      remove_pid "$name"
      return
    fi
    sleep 1
  done

  kill -9 "$pid" >/dev/null 2>&1 || true
  remove_pid "$name"
}

print_status() {
  local ollama_state="stopped"
  local model_state="not_ready"
  if is_ollama_reachable; then
    ollama_state="running"
    if is_ollama_model_ready; then
      model_state="ready"
    fi
  fi

  local backend_state="stopped"
  local backend_summary="unreachable"
  if payload="$(curl -fsS "${BACKEND_URL}/api/health" 2>/dev/null)"; then
    backend_state="running"
    backend_summary="$(node -e "
      let raw = '';
      process.stdin.on('data', (chunk) => raw += chunk);
      process.stdin.on('end', () => {
        try {
          const data = JSON.parse(raw);
          process.stdout.write(\`status=\${data.status}; modelReady=\${data.modelReady}; authMode=\${data.backendAuthMode}\`);
        } catch (error) {
          process.stdout.write('status=unknown');
        }
      });
    " <<<"$payload")"
  fi

  local admin_state="stopped"
  local admin_summary="unreachable"
  if payload="$(curl -fsS "${ADMIN_URL}/api/health" 2>/dev/null)"; then
    admin_state="running"
    admin_summary="$(node -e "
      let raw = '';
      process.stdin.on('data', (chunk) => raw += chunk);
      process.stdin.on('end', () => {
        try {
          const data = JSON.parse(raw);
          process.stdout.write(\`status=\${data.status}; publicConfigReady=\${data.publicConfigReady}; firebaseAdminReady=\${data.firebaseAdminReady}; credentialSource=\${data.firebaseAdminCredentialSource}\`);
        } catch (error) {
          process.stdout.write('status=unknown');
        }
      });
    " <<<"$payload")"
  fi

  local flutter_ios_state="stopped"
  if is_pid_running "$(read_pid "flutter_ios")"; then
    flutter_ios_state="running"
  fi

  local flutter_macos_state="stopped"
  if is_pid_running "$(read_pid "flutter_macos")"; then
    flutter_macos_state="running"
  fi

  cat <<EOF
MoodGenie local stack status
  Ollama: ${ollama_state} (${model_state}) at ${OLLAMA_URL}
  Backend: ${backend_state} (${backend_summary}) at ${BACKEND_URL}
  Admin: ${admin_state} (${admin_summary}) at ${ADMIN_URL}
  Flutter iOS: ${flutter_ios_state}
  Flutter macOS: ${flutter_macos_state}
  Mode: target=${TARGET:-unknown}, auth=${AUTH_MODE:-unknown}, open_ui=${OPEN_UI:-unknown}, open_xcode=${OPEN_XCODE:-unknown}
EOF
}

preflight() {
  ensure_runtime_dirs
  require_cmd ollama
  require_cmd node
  require_cmd npm
  require_cmd flutter
  require_cmd xcodebuild
  require_cmd xcrun
  require_cmd open
  require_cmd curl
  require_cmd lsof
  load_backend_config
  resolve_admin_env_file
  backfill_admin_env_defaults
  validate_admin_env_file
  validate_real_auth_prerequisites
}

start_stack() {
  preflight
  ensure_ollama_running
  ensure_ollama_model
  ensure_backend_running
  ensure_admin_running

  case "$TARGET" in
    ios)
      start_flutter_ios
      ;;
    macos)
      start_flutter_macos
      ;;
    both)
      start_flutter_ios
      start_flutter_macos
      ;;
    *)
      fail "Unsupported target '${TARGET}'. Use ios, macos, or both."
      ;;
  esac

  write_state
  open_surfaces
  print_status
}

stop_stack() {
  load_state
  terminate_owned_process "flutter_ios" "${FLUTTER_IOS_OWNED:-no}"
  terminate_owned_process "flutter_macos" "${FLUTTER_MACOS_OWNED:-no}"
  terminate_owned_process "admin" "${ADMIN_OWNED:-no}"
  terminate_owned_process "backend" "${BACKEND_OWNED:-no}"
  terminate_owned_process "ollama" "${OLLAMA_OWNED:-no}"
  rm -f "$STATE_FILE"
  log "Local stack stopped."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --auth)
      fail "Real Firebase auth is always enforced now. Remove --auth and try again."
      ;;
    --open-ui)
      OPEN_UI="${2:-}"
      shift 2
      ;;
    --open-xcode)
      OPEN_XCODE="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument '$1'."
      ;;
  esac
done

case "$COMMAND" in
  start)
    start_stack
    ;;
  stop)
    stop_stack
    ;;
  status)
    load_state
    load_backend_config
    print_status
    ;;
  *)
    usage
    fail "Unknown command '${COMMAND}'."
    ;;
esac
