#!/usr/bin/env bash
# neon-ensure.sh - preflight check for the neon-cli skill.
# Verifies bun, neonctl reachability, psql, jq, and NEON_API_KEY.
# Exits non-zero with a clear error per missing dependency.
set -euo pipefail

ok()   { printf '\033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }

errors=0

# 1. bun (required for bunx)
if command -v bun >/dev/null 2>&1; then
  ok "bun ($(bun --version))"
else
  fail "bun not found. Install: curl -fsSL https://bun.sh/install | bash"
  errors=$((errors + 1))
fi

# 2. neonctl reachable via bunx
if command -v bun >/dev/null 2>&1; then
  if version=$(bunx neonctl@latest --version 2>/dev/null | tail -n1); then
    ok "neonctl ($version)"
  else
    fail "bunx neonctl@latest failed. Check network or run: bunx neonctl@latest --help"
    errors=$((errors + 1))
  fi
fi

# 3. psql (required for SQL execution)
if command -v psql >/dev/null 2>&1; then
  ok "psql ($(psql --version | awk '{print $3}'))"
else
  fail "psql not found. Install the PostgreSQL client with your OS package manager."
  errors=$((errors + 1))
fi

# 4. jq (required by helper scripts for JSON parsing)
if command -v jq >/dev/null 2>&1; then
  ok "jq ($(jq --version))"
else
  fail "jq not found. Install it with your OS package manager."
  errors=$((errors + 1))
fi

# 5. NEON_API_KEY
if [[ -n "${NEON_API_KEY:-}" ]]; then
  ok "NEON_API_KEY is set (${#NEON_API_KEY} chars)"
else
  fail "NEON_API_KEY is not set. Generate at https://console.neon.tech/app/settings?modal=create_api_key and:"
  fail "  export NEON_API_KEY=neon_api_xxxxxxxxxxxx"
  errors=$((errors + 1))
fi

# 6. Optional: check pinned context
if [[ -f "${NEON_CONTEXT_FILE:-$HOME/.config/neonctl/context.json}" ]]; then
  ctx_pid=$(jq -r '.projectId // empty' "${NEON_CONTEXT_FILE:-$HOME/.config/neonctl/context.json}" 2>/dev/null || true)
  if [[ -n "$ctx_pid" ]]; then
    ok "context pinned: project_id=$ctx_pid"
  fi
else
  warn "no neonctl context pinned. Pin one with:"
  warn "  bunx neonctl@latest set-context --project-id <PID>"
  warn "  (or pass --project-id on every command, or set NEON_PROJECT_ID env var)"
fi

# 7. Verify auth actually works (1 cheap API call)
if [[ -n "${NEON_API_KEY:-}" ]] && command -v bun >/dev/null 2>&1; then
  if me=$(bunx neonctl@latest me --output json 2>/dev/null); then
    login=$(echo "$me" | jq -r '.login // .email // "unknown"')
    ok "authenticated as: $login"
  else
    fail "NEON_API_KEY is set but auth failed. The key may be invalid or revoked."
    errors=$((errors + 1))
  fi
fi

echo
if [[ $errors -eq 0 ]]; then
  ok "all checks passed"
  exit 0
else
  fail "$errors check(s) failed"
  exit 1
fi
