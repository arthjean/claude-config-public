# Shared bash helpers for clerk-cli scripts.
# Source from each script: source "$(dirname "$0")/_lib.sh"

set -euo pipefail

err() { printf '\033[31mERROR\033[0m: %s\n' "$1" >&2; exit 1; }

CLERK_API_BASE="${CLERK_API_BASE:-https://api.clerk.com/v1}"

# Auto-load CLERK_SECRET_KEY (and CLERK_API_VERSION) from a project .env file if not
# already set in the shell. Walks up from $PWD looking for .env.local then .env, stopping
# at the first git repo root or $HOME. Only Clerk-prefixed keys are extracted - the rest
# of the file is ignored (no shell evaluation, no var leakage).
#
# Precedence: shell env > .env.local > .env > error.
_clerk_load_env() {
  [[ -n "${CLERK_SECRET_KEY:-}" ]] && return 0

  local dir="${PWD}" parent
  while :; do
    for f in .env.local .env; do
      if [[ -f "$dir/$f" ]]; then
        local line key val
        while IFS= read -r line || [[ -n "$line" ]]; do
          [[ "$line" =~ ^[[:space:]]*# ]] && continue
          [[ "$line" =~ ^[[:space:]]*$ ]] && continue
          line="${line#export }"; line="${line# }"
          [[ "$line" != CLERK_SECRET_KEY=* && "$line" != CLERK_API_VERSION=* ]] && continue
          key="${line%%=*}"; val="${line#*=}"
          # Strip surrounding single or double quotes.
          [[ "$val" == \"*\" ]] && val="${val#\"}" && val="${val%\"}"
          [[ "$val" == \'*\' ]] && val="${val#\'}" && val="${val%\'}"
          case "$key" in
            CLERK_SECRET_KEY)
              [[ -z "${CLERK_SECRET_KEY:-}" ]] && export CLERK_SECRET_KEY="$val" \
                && export _CLERK_LOADED_FROM="$dir/$f"
              ;;
            CLERK_API_VERSION)
              [[ -z "${CLERK_API_VERSION:-}" ]] && export CLERK_API_VERSION="$val"
              ;;
          esac
        done < "$dir/$f"
        [[ -n "${CLERK_SECRET_KEY:-}" ]] && return 0
      fi
    done
    # Stop at repo root or once we'd traverse past $HOME / fs root.
    [[ -d "$dir/.git" ]] && return 0
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" || "$dir" == "$HOME" ]] && return 0
    dir="$parent"
  done
}

# Try to load from .env first; this is a no-op if CLERK_SECRET_KEY is already exported.
_clerk_load_env

# Default API version. Without an explicit header, the API silently resolves to legacy 2021-02-05.
CLERK_API_VERSION="${CLERK_API_VERSION:-2025-11-10}"

# Require CLERK_SECRET_KEY in the environment (or loadable from a project .env file).
require_clerk_secret_key() {
  [[ -n "${CLERK_SECRET_KEY:-}" ]] || err \
"CLERK_SECRET_KEY is not set and no .env(.local) was found in the current directory or its parents.
Three ways to provide it (highest precedence first):
  1. export CLERK_SECRET_KEY=sk_live_xxx
  2. cd into a project with .env.local containing CLERK_SECRET_KEY=...
  3. run 'bunx clerk env pull' inside a Clerk-linked project to write .env.local"
  case "$CLERK_SECRET_KEY" in
    sk_test_*|sk_live_*) ;;
    *) err "CLERK_SECRET_KEY format looks wrong (expected 'sk_test_...' or 'sk_live_...', got first 8 chars: '${CLERK_SECRET_KEY:0:8}...')." ;;
  esac
}

# URL-encode a single value for query strings.
# Usage: urlencode "user@example.com"
urlencode() {
  local s="${1:-}" out=""
  local i ch
  for ((i = 0; i < ${#s}; i++)); do
    ch="${s:i:1}"
    case "$ch" in
      [a-zA-Z0-9.~_-]) out+="$ch" ;;
      *) printf -v out '%s%%%02X' "$out" "'$ch" ;;
    esac
  done
  printf '%s' "$out"
}

# Authenticated curl against api.clerk.com/v1, with built-in 429 retry honoring Retry-After.
# Usage: clerk_api METHOD PATH [json_body | curl_extra_args...]
# Examples:
#   clerk_api GET    "/users?limit=20"
#   clerk_api POST   "/organizations" '{"name":"Acme","created_by":"user_xxx"}'
#   clerk_api PATCH  "/users/user_xxx" '{"public_metadata":{"plan":"pro"}}'
#   clerk_api DELETE "/sessions/sess_xxx"
clerk_api() {
  local method="${1:-GET}" path="${2:?path required}"
  shift 2

  # Path is expected to start with "/" - accept both /users and users.
  [[ "$path" == /* ]] || path="/$path"

  local args=(
    --silent --show-error
    --write-out '\n%{http_code}'
    -X "$method"
    -H "Authorization: Bearer $CLERK_SECRET_KEY"
    -H "Clerk-API-Version: $CLERK_API_VERSION"
    -H "Accept: application/json"
  )

  if [[ $# -gt 0 && "${1:0:1}" == "{" ]]; then
    args+=(-H "Content-Type: application/json" -d "$1")
    shift
  fi

  args+=("$@")

  local url="${CLERK_API_BASE}${path}"
  local attempt=1 max_attempts=2 response status body retry_after

  while [[ $attempt -le $max_attempts ]]; do
    response=$(curl "${args[@]}" -D /tmp/clerk-cli-headers.$$ "$url" 2>&1) || {
      [[ $attempt -lt $max_attempts ]] || { rm -f /tmp/clerk-cli-headers.$$; err "curl failed: $response"; }
      sleep 2; attempt=$((attempt + 1)); continue
    }
    # Last line is the status code; rest is the body.
    status="${response##*$'\n'}"
    body="${response%$'\n'*}"

    if [[ "$status" == "429" ]]; then
      retry_after=$(grep -i '^retry-after:' /tmp/clerk-cli-headers.$$ 2>/dev/null | awk '{print $2}' | tr -d '\r' | head -n1)
      retry_after="${retry_after:-5}"
      printf '\033[33m!\033[0m 429 rate limited, sleeping %ss before retry\n' "$retry_after" >&2
      sleep "$retry_after"
      attempt=$((attempt + 1))
      continue
    fi

    rm -f /tmp/clerk-cli-headers.$$
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      printf '%s' "$body"
      return 0
    fi
    # Non-2xx, non-429 - surface body and bail.
    err "API ${method} ${path} returned ${status}: $(printf '%s' "$body" | head -c 500)"
  done

  rm -f /tmp/clerk-cli-headers.$$
  err "API ${method} ${path} exhausted ${max_attempts} attempts"
}
