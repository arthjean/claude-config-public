#!/usr/bin/env bash
# vercel-bypass.sh - deployment protection bypass tokens (MCP get_access_to_vercel_url + web_fetch_vercel_url).
# Pro/Enterprise plans only. Allows sharing or programmatically fetching protected deployments.
#
# Usage:
#   ./vercel-bypass.sh create <project-id-or-name> [--name "purpose"]
#   ./vercel-bypass.sh list   <project-id-or-name>
#   ./vercel-bypass.sh rm     <project-id-or-name> <token-id>
#   ./vercel-bypass.sh fetch  <protected-url>      <bypass-secret>
#
# Examples:
#   TOK=$(./vercel-bypass.sh create my-app | jq -r .secret)
#   ./vercel-bypass.sh fetch https://my-app-xyz.vercel.app/api/private "$TOK"
#   ./vercel-bypass.sh list my-app
#   ./vercel-bypass.sh rm my-app bp_xxx

source "$(dirname "$0")/_lib.sh"
require_vercel_token

[[ $# -ge 1 ]] || err "usage: $0 {create|list|rm|fetch} ..."

action="$1"
shift

case "$action" in
  create)
    [[ $# -ge 1 ]] || err "usage: $0 create <project> [--name purpose]"
    project="$1"; shift
    name="agent-bypass-$(date +%s)"
    for a in "$@"; do
      case "$a" in
        --name=*) name="${a#--name=}" ;;
        --name)   shift; name="$1" ;;
      esac
    done
    body=$(jq -nc --arg name "$name" '{name: $name}')
    path=$(with_team_query "/v1/security/protection-bypass/$project")
    vercel_api POST "$path" "$body" | jq .
    ;;

  list)
    [[ $# -ge 1 ]] || err "usage: $0 list <project>"
    project="$1"
    path=$(with_team_query "/v1/security/protection-bypass/$project")
    vercel_api GET "$path" | jq .
    ;;

  rm)
    [[ $# -ge 2 ]] || err "usage: $0 rm <project> <token-id>"
    project="$1"; token_id="$2"
    path=$(with_team_query "/v1/security/protection-bypass/$project/$token_id")
    vercel_api DELETE "$path" | jq .
    ;;

  fetch)
    [[ $# -ge 2 ]] || err "usage: $0 fetch <protected-url> <bypass-secret>"
    url="$1"; secret="$2"
    # Vercel deployment protection accepts the secret as a query param OR as the
    # x-vercel-protection-bypass header. Header is safer (not logged in URLs).
    curl -fsSL \
      -H "x-vercel-protection-bypass: $secret" \
      -H "x-vercel-set-bypass-cookie: samesitenone" \
      "$url"
    ;;

  *)
    err "unknown action: $action (expected: create | list | rm | fetch)"
    ;;
esac
