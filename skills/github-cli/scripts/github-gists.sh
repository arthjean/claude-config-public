#!/usr/bin/env bash
# github-gists.sh - gist CRUD.
# Replaces MCP tools: create_gist, get_gist, list_gists, update_gist.
# Adds (MCP gap): delete, star/unstar, fork.
#
# Usage:
#   ./github-gists.sh ls       [--limit 30] [--user <username>]
#   ./github-gists.sh get      <gist-id>
#   ./github-gists.sh create   <local-file> [--description "…"] [--public]
#   ./github-gists.sh create-multi <description> <file1> <file2>...     # multi-file gist
#   ./github-gists.sh update   <gist-id> <local-file>            # replaces single named file
#   ./github-gists.sh patch    <gist-id> <patch-json>            # raw patch
#   ./github-gists.sh rm       <gist-id>
#   ./github-gists.sh star     <gist-id>
#   ./github-gists.sh unstar   <gist-id>
#   ./github-gists.sh fork     <gist-id>

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|create|create-multi|update|patch|rm|star|unstar|fork} [args...]"

action="$1"; shift

case "$action" in
  ls)
    limit=30; user=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --limit) limit="$2"; shift 2 ;;
        --user)  user="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    if [[ -n "$user" ]]; then
      github_api GET "/users/${user}/gists?per_page=${limit}" | jq .
    else
      github_api GET "/gists?per_page=${limit}" | jq .
    fi
    ;;

  get)
    [[ $# -ge 1 ]] || err "usage: $0 get <gist-id>"
    github_api GET "/gists/$1" | jq .
    ;;

  create)
    [[ $# -ge 1 ]] || err "usage: $0 create <local-file> [--description …] [--public]"
    src="$1"; shift
    [[ -f "$src" ]] || err "local file not found: $src"
    desc=""; public=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --description) desc="$2"; shift 2 ;;
        --public)      public=true; shift ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    fname="$(basename "$src")"
    content=$(cat "$src")
    body=$(jq -nc --arg fn "$fname" --arg c "$content" --arg d "$desc" --argjson p "$public" \
      '{description:$d, public:$p, files: { ($fn): {content:$c} }}')
    github_api POST "/gists" "$body" | jq .
    ;;

  create-multi)
    [[ $# -ge 2 ]] || err "usage: $0 create-multi <description> <file1> <file2>..."
    desc="$1"; shift
    files='{}'
    for f in "$@"; do
      [[ -f "$f" ]] || err "local file not found: $f"
      files=$(jq -nc --argjson cur "$files" --arg fn "$(basename "$f")" --arg c "$(cat "$f")" \
        '$cur + { ($fn): {content:$c} }')
    done
    body=$(jq -nc --arg d "$desc" --argjson f "$files" '{description:$d, public:false, files:$f}')
    github_api POST "/gists" "$body" | jq .
    ;;

  update)
    [[ $# -ge 2 ]] || err "usage: $0 update <gist-id> <local-file>"
    gid="$1"; src="$2"
    [[ -f "$src" ]] || err "local file not found: $src"
    fname="$(basename "$src")"
    content=$(cat "$src")
    body=$(jq -nc --arg fn "$fname" --arg c "$content" '{files: { ($fn): {content:$c} }}')
    github_api PATCH "/gists/${gid}" "$body" | jq .
    ;;

  patch)
    [[ $# -ge 2 ]] || err "usage: $0 patch <gist-id> <patch-json>"
    github_api PATCH "/gists/$1" "$2" | jq .
    ;;

  rm)
    [[ $# -ge 1 ]] || err "usage: $0 rm <gist-id>"
    github_api DELETE "/gists/$1"
    printf '\033[32m✓\033[0m gist %s deleted\n' "$1"
    ;;

  star)
    [[ $# -ge 1 ]] || err "usage: $0 star <gist-id>"
    github_api PUT "/gists/$1/star" -H "Content-Length: 0"
    printf '\033[32m✓\033[0m gist %s starred\n' "$1"
    ;;

  unstar)
    [[ $# -ge 1 ]] || err "usage: $0 unstar <gist-id>"
    github_api DELETE "/gists/$1/star"
    printf '\033[32m✓\033[0m gist %s unstarred\n' "$1"
    ;;

  fork)
    [[ $# -ge 1 ]] || err "usage: $0 fork <gist-id>"
    github_api POST "/gists/$1/forks" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
