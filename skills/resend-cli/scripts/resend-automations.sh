#!/usr/bin/env bash
# resend-automations.sh - automation workflows (MCP GAP - not exposed by resend-mcp).
# These endpoints are documented in the CLI 2.0 surface but absent from the official MCP.
#
# Subcommands:
#   create   Create an automation
#              Flags: --name <name> --trigger <event_name> [--body @file.json|json]
#              The body is the full automation definition (steps, conditions, etc.).
#              See `resend automations create --help` from the official CLI for the schema.
#   ls       List automations
#   get      Get a single automation       get <id>
#   update   Update an automation          update <id> <@file.json|json-body>
#   stop     Stop a running automation     stop <id>
#   rm       Delete an automation          rm <id>
#
# Note: The exact REST surface for automation CRUD is undocumented in the public llms.txt as of
# May 2026. The skill maps to the documented `POST /automations` plus presumed REST conventions
# (GET/PATCH/DELETE /automations/{id}, POST /automations/{id}/stop). If a 404 surfaces, prefer
# the official `bunx resend-cli automations ...` commands until the REST endpoints are public.

# shellcheck disable=SC1091
source "$(dirname "$0")/_lib.sh"
require_resend_key

[[ $# -ge 1 ]] || err "usage: $0 {create|ls|get|update|stop|rm} [args...]"
action="$1"; shift

_load_body() {
  local arg="$1"
  if [[ "$arg" == @* ]]; then
    local f="${arg:1}"; [[ -f "$f" ]] || err "file not found: $f"
    cat "$f"
  else
    printf '%s' "$arg"
  fi
}

case "$action" in
  create)
    name=""; trigger=""; body_arg=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name)    name="$2"; shift 2 ;;
        --trigger) trigger="$2"; shift 2 ;;
        --body)    body_arg="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    if [[ -n "$body_arg" ]]; then
      body=$(_load_body "$body_arg")
    else
      [[ -n "$name" && -n "$trigger" ]] || err "missing --name and --trigger (or pass --body @def.json)"
      body=$(jq -nc --arg n "$name" --arg t "$trigger" '{name:$n, trigger:$t}')
    fi
    resend_api POST "/automations" "$body" | pretty
    ;;

  ls|list)
    resend_api GET "/automations" | pretty
    ;;

  get)
    [[ $# -ge 1 ]] || err "usage: $0 get <automation_id>"
    resend_api GET "/automations/$1" | pretty
    ;;

  update)
    [[ $# -ge 2 ]] || err "usage: $0 update <automation_id> <@file.json|json-body>"
    aid="$1"; body=$(_load_body "$2")
    resend_api PATCH "/automations/$aid" "$body" | pretty
    ;;

  stop)
    [[ $# -ge 1 ]] || err "usage: $0 stop <automation_id>"
    resend_api POST "/automations/$1/stop" | pretty
    ;;

  rm|delete)
    [[ $# -ge 1 ]] || err "usage: $0 rm <automation_id>"
    resend_api DELETE "/automations/$1" | pretty
    ;;

  *) err "unknown action: $action  (try: create|ls|get|update|stop|rm)" ;;
esac
