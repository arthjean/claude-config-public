# Shared bash helpers for github-cli scripts.
# Source from each script: source "$(dirname "$0")/_lib.sh"

set -euo pipefail

err() { printf '\033[31mERROR\033[0m: %s\n' "$1" >&2; exit 1; }

GITHUB_API_BASE="${GITHUB_API_BASE:-https://api.github.com}"
GITHUB_API_VERSION="${GITHUB_API_VERSION:-2022-11-28}"

# Auto-load GITHUB_TOKEN (or accept GH_TOKEN as alias) from a project .env file if not
# already set in the shell. Walks up from $PWD looking for .env.local then .env, stopping
# at the first git repo root or $HOME. Only GitHub-prefixed keys are extracted - the rest
# of the file is ignored (no shell evaluation, no var leakage).
#
# Recognized keys: GITHUB_TOKEN, GH_TOKEN, GITHUB_API_VERSION.
# Precedence: shell env > .env.local > .env > error.
_github_load_env() {
  # If either is already exported, mirror it to GITHUB_TOKEN and stop.
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then return 0; fi
  if [[ -n "${GH_TOKEN:-}" ]]; then export GITHUB_TOKEN="$GH_TOKEN"; return 0; fi

  local dir="${PWD}" parent
  while :; do
    for f in .env.local .env; do
      if [[ -f "$dir/$f" ]]; then
        local line key val
        while IFS= read -r line || [[ -n "$line" ]]; do
          [[ "$line" =~ ^[[:space:]]*# ]] && continue
          [[ "$line" =~ ^[[:space:]]*$ ]] && continue
          line="${line#export }"; line="${line# }"
          case "$line" in
            GITHUB_TOKEN=*|GH_TOKEN=*|GITHUB_API_VERSION=*) ;;
            *) continue ;;
          esac
          key="${line%%=*}"; val="${line#*=}"
          [[ "$val" == \"*\" ]] && val="${val#\"}" && val="${val%\"}"
          [[ "$val" == \'*\' ]] && val="${val#\'}" && val="${val%\'}"
          case "$key" in
            GITHUB_TOKEN|GH_TOKEN)
              [[ -z "${GITHUB_TOKEN:-}" ]] && export GITHUB_TOKEN="$val" \
                && export _GITHUB_LOADED_FROM="$dir/$f"
              ;;
            GITHUB_API_VERSION)
              [[ -z "${GITHUB_API_VERSION:-}" || "${GITHUB_API_VERSION}" == "2022-11-28" ]] \
                && export GITHUB_API_VERSION="$val"
              ;;
          esac
        done < "$dir/$f"
        [[ -n "${GITHUB_TOKEN:-}" ]] && return 0
      fi
    done
    [[ -d "$dir/.git" ]] && return 0
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" || "$dir" == "$HOME" ]] && return 0
    dir="$parent"
  done
}

# Try to load from .env first; this is a no-op if GITHUB_TOKEN is already exported.
_github_load_env

# Last-resort fallback: if the user has gh CLI logged in but no env token, borrow it.
if [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  if t=$(gh auth token 2>/dev/null); then
    [[ -n "$t" ]] && export GITHUB_TOKEN="$t" && export _GITHUB_LOADED_FROM="gh auth token (keyring)"
  fi
fi

# Require GITHUB_TOKEN. Accepts classic PAT (ghp_…), fine-grained (github_pat_…), or
# any opaque string (some installation tokens / OAuth tokens have no fixed prefix).
require_github_token() {
  [[ -n "${GITHUB_TOKEN:-}" ]] || err \
"GITHUB_TOKEN is not set and no .env(.local) was found in the current directory or its parents.
Four ways to provide it (highest precedence first):
  1. export GITHUB_TOKEN=ghp_<redacted>
  2. export GH_TOKEN=ghp_…   (alias, same as above)
  3. cd into a project with .env.local containing GITHUB_TOKEN=…
  4. run 'gh auth login' once - the script will fall back to 'gh auth token'

Generate at https://github.com/settings/tokens (classic) or .../tokens?type=beta (fine-grained).
Recommended scopes for full coverage: repo, workflow, admin:org, gist, project, user, notifications, delete_repo."
}

# URL-encode a single value for query strings.
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

# Resolve the active <owner>/<repo> for commands that target the current repo.
# Order: explicit arg > GITHUB_REPOSITORY env var > git remote 'origin' > error.
# Usage: REPO=$(resolve_repo "${1:-}")  ; REPO is "owner/name".
resolve_repo() {
  local arg="${1:-}"
  if [[ -n "$arg" && "$arg" == */* ]]; then printf '%s' "$arg"; return 0; fi
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then printf '%s' "$GITHUB_REPOSITORY"; return 0; fi
  if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    local url owner_repo
    url=$(git config --get remote.origin.url 2>/dev/null || true)
    if [[ -n "$url" ]]; then
      # https://github.com/owner/repo(.git)  OR  git@github.com:owner/repo(.git)
      owner_repo=$(printf '%s' "$url" \
        | sed -E 's#^git@github\.com:##; s#^https?://[^/]+/##; s#\.git$##')
      [[ "$owner_repo" == */* ]] && printf '%s' "$owner_repo" && return 0
    fi
  fi
  err "could not resolve <owner>/<repo> - pass it as an argument, set GITHUB_REPOSITORY, or run inside a git repo with a github.com origin"
}

# Authenticated curl against api.github.com, with built-in 429 / secondary-rate-limit retry.
# Usage: github_api METHOD PATH [json_body | curl_extra_args...]
# Examples:
#   github_api GET    "/user"
#   github_api GET    "/repos/cli/cli/issues?state=open&per_page=100"
#   github_api POST   "/repos/cli/cli/issues" '{"title":"Bug","body":"…"}'
#   github_api PATCH  "/repos/cli/cli/issues/42" '{"state":"closed"}'
#   github_api DELETE "/repos/cli/cli/labels/wontfix"
github_api() {
  local method="${1:-GET}" path="${2:?path required}"
  shift 2

  [[ "$path" == /* ]] || path="/$path"
  # Allow either /repos/... or full https URL (paginate uses absolute Link headers).
  local url
  if [[ "$path" == http* ]]; then url="$path"; else url="${GITHUB_API_BASE}${path}"; fi

  local args=(
    --silent --show-error
    --write-out '\n%{http_code}'
    -X "$method"
    -H "Authorization: Bearer $GITHUB_TOKEN"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: $GITHUB_API_VERSION"
    -H "User-Agent: github-cli-skill"
  )

  if [[ $# -gt 0 && "${1:0:1}" == "{" ]]; then
    args+=(-H "Content-Type: application/json" -d "$1")
    shift
  fi
  args+=("$@")

  local attempt=1 max_attempts=3 response status body retry_after reset_in
  local hdr=/tmp/github-cli-headers.$$

  while [[ $attempt -le $max_attempts ]]; do
    response=$(curl "${args[@]}" -D "$hdr" "$url" 2>&1) || {
      [[ $attempt -lt $max_attempts ]] || { rm -f "$hdr"; err "curl failed: $response"; }
      sleep 2; attempt=$((attempt + 1)); continue
    }
    status="${response##*$'\n'}"
    body="${response%$'\n'*}"

    # Primary rate limit (429) or secondary (403 + retry-after / x-ratelimit-remaining=0).
    if [[ "$status" == "429" ]] \
       || { [[ "$status" == "403" ]] && grep -qiE '^retry-after:|^x-ratelimit-remaining: 0' "$hdr" 2>/dev/null; }; then
      retry_after=$(grep -i '^retry-after:' "$hdr" 2>/dev/null | awk '{print $2}' | tr -d '\r' | head -n1)
      if [[ -z "$retry_after" ]]; then
        reset_in=$(grep -i '^x-ratelimit-reset:' "$hdr" 2>/dev/null | awk '{print $2}' | tr -d '\r' | head -n1)
        if [[ -n "$reset_in" ]]; then retry_after=$(( reset_in - $(date +%s) )); fi
      fi
      retry_after="${retry_after:-30}"
      [[ "$retry_after" -lt 1 ]] && retry_after=5
      [[ "$retry_after" -gt 120 ]] && { rm -f "$hdr"; err "rate limited; reset is in ${retry_after}s, refusing to wait that long"; }
      printf '\033[33m!\033[0m %s rate limited, sleeping %ss before retry (%d/%d)\n' \
        "$status" "$retry_after" "$attempt" "$max_attempts" >&2
      sleep "$retry_after"
      attempt=$((attempt + 1)); continue
    fi

    rm -f "$hdr"
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
      printf '%s' "$body"
      return 0
    fi
    if [[ "$status" == "404" ]]; then
      err "API ${method} ${path} → 404 Not Found ($(printf '%s' "$body" | jq -r '.message // empty' 2>/dev/null))"
    fi
    err "API ${method} ${path} returned ${status}: $(printf '%s' "$body" | head -c 600)"
  done

  rm -f "$hdr"
  err "API ${method} ${path} exhausted ${max_attempts} attempts"
}

# GraphQL helper - wraps github_api against /graphql. First arg is the query string,
# remaining args are jq-style key=value pairs converted to a 'variables' object.
# Usage: github_graphql 'query($login:String!){user(login:$login){id}}' login=octocat
github_graphql() {
  local query="${1:?graphql query required}"
  shift
  local vars='{}'
  for kv in "$@"; do
    local k="${kv%%=*}" v="${kv#*=}"
    vars=$(jq -nc --argjson cur "$vars" --arg k "$k" --arg v "$v" '$cur + {($k): $v}')
  done
  local body
  body=$(jq -nc --arg q "$query" --argjson v "$vars" '{query:$q, variables:$v}')
  github_api POST "/graphql" "$body"
}

# Auto-paginate a REST endpoint by following Link: rel="next" headers.
# Returns a single JSON array (concatenated pages). Caller passes the path; query
# params should include per_page=100. Each page must return a JSON array.
# Usage: github_paginate "/repos/cli/cli/issues?per_page=100&state=open"
github_paginate() {
  local path="${1:?path required}" url="${GITHUB_API_BASE}${1#/}"
  [[ "$path" == /* ]] && url="${GITHUB_API_BASE}${path}"
  local hdr=/tmp/github-cli-paginate.$$
  local out='[]' page next

  while [[ -n "$url" ]]; do
    page=$(curl --silent --show-error \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
      -H "User-Agent: github-cli-skill" \
      -D "$hdr" "$url") || { rm -f "$hdr"; err "paginate curl failed at $url"; }
    out=$(jq -c --argjson new "$page" '. + $new' <<<"$out")
    next=$(grep -i '^link:' "$hdr" 2>/dev/null \
      | sed -nE 's/.*<([^>]+)>; rel="next".*/\1/p' | head -n1)
    url="$next"
  done
  rm -f "$hdr"
  printf '%s' "$out"
}
