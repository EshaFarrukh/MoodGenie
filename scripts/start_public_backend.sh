#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
BACKEND_HEALTH_URL="http://127.0.0.1:3000/api/health"
TUNNEL_TARGET="http://127.0.0.1:3000"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is not installed. Install it first with:"
  echo "  brew install cloudflared"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not installed."
  exit 1
fi

if ! curl -fsS "$BACKEND_HEALTH_URL" >/dev/null; then
  echo "Backend is not reachable at $BACKEND_HEALTH_URL"
  echo "Start your Node backend and Ollama first, then rerun this script."
  exit 1
fi

log_file="$(mktemp)"
tunnel_pid=""

cleanup() {
  if [[ -n "$tunnel_pid" ]] && kill -0 "$tunnel_pid" >/dev/null 2>&1; then
    kill "$tunnel_pid" >/dev/null 2>&1 || true
    wait "$tunnel_pid" 2>/dev/null || true
  fi
  rm -f "$log_file"
}

trap cleanup EXIT INT TERM

cloudflared tunnel --url "$TUNNEL_TARGET" --no-autoupdate >"$log_file" 2>&1 &
tunnel_pid="$!"

public_url=""
for _ in {1..40}; do
  if ! kill -0 "$tunnel_pid" >/dev/null 2>&1; then
    cat "$log_file"
    echo "cloudflared exited before creating a tunnel."
    exit 1
  fi

  public_url="$(awk 'match($0, /https:\/\/[A-Za-z0-9.-]+\.trycloudflare\.com/) { print substr($0, RSTART, RLENGTH); exit }' "$log_file")"
  if [[ -n "$public_url" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$public_url" ]]; then
  cat "$log_file"
  echo "Could not find the public tunnel URL in cloudflared output."
  exit 1
fi

tmp_env="$(mktemp)"
if [[ -f "$ENV_FILE" ]]; then
  awk -v url="$public_url" '
    BEGIN { replaced = 0 }
    /^BACKEND_URL=/ {
      print "BACKEND_URL=" url
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print "BACKEND_URL=" url
      }
    }
  ' "$ENV_FILE" >"$tmp_env"
  mv "$tmp_env" "$ENV_FILE"
else
  printf 'BACKEND_URL=%s\n' "$public_url" >"$ENV_FILE"
  rm -f "$tmp_env"
fi

echo "Public backend URL: $public_url"
echo "Updated $ENV_FILE with BACKEND_URL=$public_url"
echo
echo "Keep this process running while testers use the app."
echo "Press Ctrl+C to stop the tunnel."
echo

tail -n +1 -f "$log_file"
