#!/usr/bin/env bash
# github-ensure.sh - preflight check for the github-cli skill.
# Verifies bun, gh CLI, jq, curl, git, GITHUB_TOKEN, and a live auth call to /user.
# Exits non-zero with a clear error per missing dependency.
set -euo pipefail

ok()   { printf '\033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }

errors=0

# Source _lib.sh so the .env auto-loader (and gh fallback) runs before we check the token.
# shellcheck disable=SC1091
source "$(dirname "$0")/_lib.sh"

# 1. bun (for bunx - required by the user's global rule)
if command -v bun >/dev/null 2>&1; then
  ok "bun ($(bun --version))"
else
  warn "bun not found. The skill works without it (uses gh + curl directly), but install for consistency: curl -fsSL https://bun.sh/install | bash"
fi

# 2. gh CLI
if command -v gh >/dev/null 2>&1; then
  ok "gh ($(gh --version | head -n1 | awk '{print $3}'))"
else
  fail "gh not found. The skill leans on gh for many commands. Install it with your OS package manager."
  errors=$((errors + 1))
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

# 5. git (for resolve_repo)
if command -v git >/dev/null 2>&1; then
  ok "git ($(git --version | awk '{print $3}'))"
else
  warn "git not found - resolve_repo() can't read the origin remote. Pass owner/repo explicitly to commands."
fi

# 6. GITHUB_TOKEN (auto-loaded from .env(.local) by _lib.sh, then gh keyring as last resort)
src="${_GITHUB_LOADED_FROM:-shell environment}"
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  case "$GITHUB_TOKEN" in
    ghp_*)         kind="classic PAT" ;;
    github_pat_*)  kind="fine-grained PAT" ;;
    ghs_*)         kind="GitHub App installation token" ;;
    gho_*)         kind="OAuth user-to-server token" ;;
    ghu_*)         kind="GitHub App user-to-server token" ;;
    *)             kind="opaque token (length ${#GITHUB_TOKEN})" ;;
  esac
  ok "GITHUB_TOKEN is set ($kind) - source: $src"
else
  fail "GITHUB_TOKEN not found. Four options (highest precedence first):"
  fail "  1. export GITHUB_TOKEN=ghp_xxx in your shell"
  fail "  2. export GH_TOKEN=ghp_xxx  (alias)"
  fail "  3. cd into a project with .env.local containing GITHUB_TOKEN=…"
  fail "  4. run 'gh auth login' once - auto-loaded via 'gh auth token'"
  errors=$((errors + 1))
fi

# 7. API version
ok "X-GitHub-Api-Version: $GITHUB_API_VERSION"

# 8. Live auth - GET /user is the cheapest authenticated endpoint and prints identity.
if [[ -n "${GITHUB_TOKEN:-}" ]] && command -v curl >/dev/null 2>&1; then
  if me=$(curl -fsS \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
      -H "User-Agent: github-cli-skill" \
      https://api.github.com/user 2>/dev/null); then
    login=$(echo "$me" | jq -r '.login // "unknown"')
    name=$(echo "$me" | jq -r '.name // .login')
    plan=$(echo "$me" | jq -r '.plan.name // "n/a"')
    ok "authenticated - @${login} (${name}), plan: ${plan}"

    # Also surface scopes (only present on classic PAT / OAuth) and rate-limit budget.
    scopes=$(curl -sI \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "User-Agent: github-cli-skill" \
      https://api.github.com/user 2>/dev/null \
      | grep -i '^x-oauth-scopes:' | head -n1 | sed -E 's/^[Xx]-[Oo][Aa]uth-[Ss]copes:[[:space:]]*//; s/[[:space:]]+$//' | tr -d '\r')
    if [[ -n "$scopes" ]]; then
      ok "scopes: $scopes"
    else
      warn "no x-oauth-scopes header - token is fine-grained or installation; check at github.com/settings/tokens"
    fi

    if rl=$(curl -fsS \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "User-Agent: github-cli-skill" \
        https://api.github.com/rate_limit 2>/dev/null); then
      core=$(echo "$rl" | jq -r '.resources.core.remaining')
      core_max=$(echo "$rl" | jq -r '.resources.core.limit')
      gql=$(echo "$rl" | jq -r '.resources.graphql.remaining')
      ok "rate limit - core: ${core}/${core_max}, graphql: ${gql}/5000"
    fi
  else
    fail "GITHUB_TOKEN is set but auth failed. The token may be invalid, revoked, or missing required scopes."
    errors=$((errors + 1))
  fi
fi

# 9. gh auth status (independent of GITHUB_TOKEN env - checks keyring login)
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    line=$(gh auth status 2>&1 | grep -E 'Logged in to' | head -n1)
    host=$(printf '%s' "$line" | sed -nE 's/.*Logged in to ([^ ]+).*/\1/p')
    acct=$(printf '%s' "$line" | sed -nE 's/.*account ([^ ]+).*/\1/p')
    ok "gh auth status: logged in to ${host:-github.com} as ${acct:-unknown}"
  else
    warn "gh auth status: not logged in. The skill works without it (env token is enough), but 'gh' commands need either env or 'gh auth login'."
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
