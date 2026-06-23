#!/usr/bin/env bash
# github-secrets.sh - Actions / Codespaces / Dependabot secrets and variables CRUD.
# MCP gap-filler: the official MCP exposes nothing for secrets/variables management.
# Encryption uses libsodium sealed boxes (Curve25519). We use 'gh' under the hood when available
# (it handles encryption transparently), and fall back to direct REST + Python sealed-box.
#
# Usage:
#   ./github-secrets.sh ls       [<owner>/<repo>] [--scope repo|env|org] [--env <name>]
#   ./github-secrets.sh set      [<owner>/<repo>] <NAME> <value> [--scope repo|env|org] [--env <name>] [--visibility all|private|selected]
#   ./github-secrets.sh rm       [<owner>/<repo>] <NAME> [--scope repo|env|org] [--env <name>]
#
#   ./github-secrets.sh vars-ls  [<owner>/<repo>] [--scope repo|env|org] [--env <name>]
#   ./github-secrets.sh var-set  [<owner>/<repo>] <NAME> <value> [--scope repo|env|org] [--env <name>]
#   ./github-secrets.sh var-rm   [<owner>/<repo>] <NAME> [--scope repo|env|org] [--env <name>]
#
# Notes:
#   - For 'set' we delegate to `gh secret set` so libsodium encryption is handled correctly.
#     If gh is not installed, we error out (rolling our own crypto in bash isn't sane).
#   - 'org' scope requires admin:org token scope.
#   - 'env' scope = environment-level secret on a repo (e.g., production).

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|set|rm|vars-ls|var-set|var-rm} [args...]"

action="$1"; shift

# Common flag parser
parse_scope() {
  scope="repo"; env_name=""; visibility="all"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope) scope="$2"; shift 2 ;;
      --env)   env_name="$2"; scope="env"; shift 2 ;;
      --visibility) visibility="$2"; shift 2 ;;
      --) shift; break ;;
      *) printf '%s\0' "$1"; shift ;;
    esac
  done
  printf 'SCOPE=%s\nENV=%s\nVISIBILITY=%s\n' "$scope" "$env_name" "$visibility"
}

# Compute the REST base path for a given scope.
secrets_base() {
  local repo="$1" scope="$2" env_name="$3" kind="$4"   # kind = secrets | variables
  case "$scope" in
    repo)
      printf '/repos/%s/actions/%s' "$repo" "$kind" ;;
    env)
      [[ -n "$env_name" ]] || err "--env is required for env scope"
      # Need the repo's numeric id for env routes.
      local rid
      rid=$(github_api GET "/repos/${repo}" | jq -r '.id')
      printf '/repositories/%s/environments/%s/%s' "$rid" "$env_name" "$kind" ;;
    org)
      local org="${repo%%/*}"
      printf '/orgs/%s/actions/%s' "$org" "$kind" ;;
    *) err "scope must be: repo | env | org" ;;
  esac
}

case "$action" in
  ls)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    scope="repo"; env_name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --scope) scope="$2"; shift 2 ;;
        --env)   env_name="$2"; scope="env"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    base=$(secrets_base "$repo" "$scope" "$env_name" "secrets")
    github_api GET "${base}?per_page=100" | jq .
    ;;

  set)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 set [<owner>/<repo>] <NAME> <value> [--scope repo|env|org] [--env name]"
    name="$1"; value="$2"; shift 2
    scope="repo"; env_name=""; visibility="all"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --scope) scope="$2"; shift 2 ;;
        --env)   env_name="$2"; scope="env"; shift 2 ;;
        --visibility) visibility="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    command -v gh >/dev/null 2>&1 || err "'gh' is required for 'set' (handles libsodium encryption). Install: sudo dnf install gh"
    case "$scope" in
      repo)
        printf '%s' "$value" | gh secret set "$name" --repo "$repo" --body - ;;
      env)
        [[ -n "$env_name" ]] || err "--env required"
        printf '%s' "$value" | gh secret set "$name" --repo "$repo" --env "$env_name" --body - ;;
      org)
        org="${repo%%/*}"
        printf '%s' "$value" | gh secret set "$name" --org "$org" --visibility "$visibility" --body - ;;
      *) err "scope must be: repo | env | org" ;;
    esac
    printf '\033[32m✓\033[0m secret %s set (%s scope)\n' "$name" "$scope"
    ;;

  rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 rm [<owner>/<repo>] <NAME> [--scope repo|env|org] [--env name]"
    name="$1"; shift
    scope="repo"; env_name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --scope) scope="$2"; shift 2 ;;
        --env)   env_name="$2"; scope="env"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    base=$(secrets_base "$repo" "$scope" "$env_name" "secrets")
    github_api DELETE "${base}/${name}"
    printf '\033[32m✓\033[0m secret %s deleted (%s scope)\n' "$name" "$scope"
    ;;

  vars-ls)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    scope="repo"; env_name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --scope) scope="$2"; shift 2 ;;
        --env)   env_name="$2"; scope="env"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    base=$(secrets_base "$repo" "$scope" "$env_name" "variables")
    github_api GET "${base}?per_page=100" | jq .
    ;;

  var-set)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 var-set [<owner>/<repo>] <NAME> <value>"
    name="$1"; value="$2"; shift 2
    scope="repo"; env_name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --scope) scope="$2"; shift 2 ;;
        --env)   env_name="$2"; scope="env"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    base=$(secrets_base "$repo" "$scope" "$env_name" "variables")
    body=$(jq -nc --arg n "$name" --arg v "$value" '{name:$n, value:$v}')
    # POST creates, PATCH updates - try POST first.
    if ! github_api POST "$base" "$body" 2>/dev/null | jq .; then
      github_api PATCH "${base}/${name}" "$body" | jq .
    fi
    ;;

  var-rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 var-rm [<owner>/<repo>] <NAME>"
    name="$1"; shift
    scope="repo"; env_name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --scope) scope="$2"; shift 2 ;;
        --env)   env_name="$2"; scope="env"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    base=$(secrets_base "$repo" "$scope" "$env_name" "variables")
    github_api DELETE "${base}/${name}"
    printf '\033[32m✓\033[0m variable %s deleted (%s scope)\n' "$name" "$scope"
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
