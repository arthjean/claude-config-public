#!/usr/bin/env bash
# resend-ensure.sh - preflight check for the resend-cli skill.
# Verifies bun, resend-cli reachability (optional), jq, curl, RESEND_API_KEY, host,
# and a live auth call to GET /domains (cheap, always-200 for any valid key).
# Exits non-zero with a clear error per missing dependency.
set -euo pipefail

ok()   { printf '\033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }

errors=0

# shellcheck disable=SC1091
source "$(dirname "$0")/_lib.sh"

# 1. bun (required for bunx - global rule)
if command -v bun >/dev/null 2>&1; then
  ok "bun ($(bun --version))"
else
  fail "bun not found. Install: curl -fsSL https://bun.sh/install | bash"
  errors=$((errors + 1))
fi

# 2. resend-cli reachable via bunx (optional - used only for `resend webhooks listen` tunnel
#    and the React Email .tsx renderer in `resend send`)
if command -v bun >/dev/null 2>&1; then
  if version=$(timeout 30 bunx --bun resend-cli --version 2>/dev/null | tail -n1); then
    ok "resend-cli ($version) - used for 'resend webhooks listen' + React Email rendering"
  else
    warn "bunx resend-cli --version did not return. The CLI is OPTIONAL - bash helpers cover the REST API."
    warn "  If you want the official CLI: bunx resend-cli login   (or  brew install resend/cli/resend)"
  fi
fi

# 3. jq
if command -v jq >/dev/null 2>&1; then
  ok "jq ($(jq --version))"
else
  fail "jq not found. Install it with your OS package manager."
  errors=$((errors + 1))
fi

# 4. curl
if command -v curl >/dev/null 2>&1; then
  ok "curl ($(curl --version | head -n1 | awk '{print $2}'))"
else
  fail "curl not found. Install it with your OS package manager."
  errors=$((errors + 1))
fi

# 5. RESEND_API_KEY (auto-loaded from .env(.local) by _lib.sh if not exported)
src="${_RESEND_LOADED_FROM:-shell environment}"
if [[ -n "${RESEND_API_KEY:-}" ]]; then
  case "$RESEND_API_KEY" in
    re_*)
      ok "RESEND_API_KEY is set (${#RESEND_API_KEY} chars) - source: $src"
      ;;
    *)
      warn "RESEND_API_KEY is set but does not start with 're_' (got '${RESEND_API_KEY:0:6}...'). Resend keys begin with 're_'."
      ;;
  esac
else
  fail "RESEND_API_KEY not found. Three ways to provide it:"
  fail "  1. export RESEND_API_KEY=re_xxx in your shell"
  fail "  2. cd into a project with .env.local containing RESEND_API_KEY=..."
  fail "  3. Create one at Resend → Settings → API Keys → '+ Create API Key'"
  fail "     (choose full_access for management, or sending_access for send-only domain-scoped keys)"
  errors=$((errors + 1))
fi

# 6. RESEND_HOST
if [[ "$RESEND_HOST" == "https://api.resend.com" ]]; then
  ok "RESEND_HOST default ($RESEND_HOST)"
else
  ok "RESEND_HOST overridden: $RESEND_HOST"
fi

# 7. RESEND_FROM (optional convenience var, used as default sender in resend-emails.sh send)
if [[ -n "${RESEND_FROM:-}" ]]; then
  ok "RESEND_FROM is set ($RESEND_FROM)"
else
  warn "RESEND_FROM not set - resend-emails.sh send will require an explicit --from. Tip: export RESEND_FROM='Acme <hi@acme.com>'"
fi

# 8. Live auth call - confirms the key works AND prints team context via domain list
if [[ -n "${RESEND_API_KEY:-}" ]] && command -v curl >/dev/null 2>&1; then
  resp=$(curl -fsS \
      -H "Authorization: Bearer $RESEND_API_KEY" \
      -H "Accept: application/json" \
      -H "User-Agent: $RESEND_USER_AGENT" \
      "${RESEND_HOST}/domains" 2>/dev/null) || resp=""
  if [[ -n "$resp" ]]; then
    count=$(printf '%s' "$resp" | jq -r '.data | length // 0' 2>/dev/null || echo "0")
    ok "authenticated against $RESEND_HOST"
    ok "  team has $count domain(s) configured"
    if [[ "$count" -gt 0 ]]; then
      printf '%s' "$resp" | jq -r '.data[] | "    • \(.name)  [\(.status)]  id=\(.id)"' 2>/dev/null || true
    fi
    # Probe permission tier by trying a no-op key list (full_access only).
    if curl -fsS -o /dev/null \
        -H "Authorization: Bearer $RESEND_API_KEY" \
        -H "Accept: application/json" \
        -H "User-Agent: $RESEND_USER_AGENT" \
        "${RESEND_HOST}/api-keys" 2>/dev/null; then
      ok "  permission tier: full_access (can manage api-keys, domains, contacts, broadcasts...)"
    else
      warn "  permission tier: sending_access - this key can ONLY send emails."
      warn "  Management calls (api-keys, domains create/delete, contacts, broadcasts...) will return 401 restricted_api_key."
    fi
  else
    fail "RESEND_API_KEY is set but auth failed against $RESEND_HOST/domains."
    fail "  The key may be invalid, revoked, or your team has no access."
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
