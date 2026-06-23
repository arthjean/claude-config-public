# Shared bash helpers for neon-cli scripts.
# Source from each script: source "$(dirname "$0")/_lib.sh"

set -euo pipefail

err() { printf '\033[31mERROR\033[0m: %s\n' "$1" >&2; exit 1; }

# Require NEON_API_KEY in the environment.
require_neon_api_key() {
  [[ -n "${NEON_API_KEY:-}" ]] || err \
    "NEON_API_KEY is not set. Generate at https://console.neon.tech/app/settings?modal=create_api_key and: export NEON_API_KEY=neon_api_xxx"
}

# Resolve project ID from arg, NEON_PROJECT_ID, or pinned context. Echoes the ID.
resolve_project_id() {
  local override="${1:-}"
  if [[ -n "$override" ]]; then
    echo "$override"; return 0
  fi
  if [[ -n "${NEON_PROJECT_ID:-}" ]]; then
    echo "$NEON_PROJECT_ID"; return 0
  fi
  # Try pinned context
  local ctx="${NEON_CONTEXT_FILE:-$HOME/.config/neonctl/context.json}"
  if [[ -f "$ctx" ]]; then
    local pid
    pid=$(jq -r '.projectId // empty' "$ctx" 2>/dev/null || true)
    if [[ -n "$pid" ]]; then
      echo "$pid"; return 0
    fi
  fi
  err "no project ID. Pass via env (NEON_PROJECT_ID=...), pin with 'bunx neonctl@latest set-context --project-id <ID>', or pass as second arg to the script."
}

# Get a connection string for a branch. Args: branch [pooled|direct] [project_id]
neon_conn() {
  local branch="${1:?branch required}"
  local mode="${2:-direct}"
  local pid
  pid=$(resolve_project_id "${3:-}")

  local pooled_flag=()
  [[ "$mode" == "pooled" ]] && pooled_flag=(--pooled)

  bunx neonctl@latest cs "$branch" \
    --project-id "$pid" \
    --no-color \
    "${pooled_flag[@]}"
}

# Run a single SQL statement. Args: branch sql [pooled|direct] [project_id]
neon_psql_c() {
  local branch="${1:?branch required}"
  local sql="${2:?sql required}"
  local mode="${3:-pooled}"
  local pid="${4:-}"

  local conn
  conn=$(neon_conn "$branch" "$mode" "$pid")
  psql "$conn" -At -c "$sql"
}

# Run a multi-statement script (from stdin or file) in a single transaction.
# Args: branch [file] [direct|pooled] [project_id]   (omitted file = read stdin)
neon_psql_tx() {
  local branch="${1:?branch required}"
  local file="${2:-}"
  local mode="${3:-direct}"  # transactions default to direct (DDL-safe)
  local pid="${4:-}"

  local conn
  conn=$(neon_conn "$branch" "$mode" "$pid")
  if [[ -n "$file" && -f "$file" ]]; then
    psql "$conn" -v ON_ERROR_STOP=1 -1 -f "$file"
  else
    psql "$conn" -v ON_ERROR_STOP=1 -1
  fi
}
