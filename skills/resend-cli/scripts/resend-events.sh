#!/usr/bin/env bash
# resend-events.sh - trigger automation events + manage event schemas (MCP GAP).
# `POST /events/send` is the documented endpoint; event-schemas CRUD is in CLI 2.0.
#
# Subcommands:
#   send         Trigger an automation by emitting an event.
#                  Flags: --event <event_name> (--contact <id> OR --email <addr>)
#                         [--payload @file.json|json]
#                  Example: send --event user.created --email a@b.com --payload '{"plan":"pro"}'
#   create       Create an event schema     create --name <event> [--body @file.json]
#   ls           List event schemas
#   get          Get an event schema         get <id>
#   update       Update an event schema      update <id> <@file.json|json-body>
#   rm           Delete an event schema      rm <id>
#
# Note: event-schemas REST paths are inferred (`/event-schemas`). If a 404 returns, use
# `bunx resend-cli events <subcommand>` from the official CLI as the canonical surface.

# shellcheck disable=SC1091
source "$(dirname "$0")/_lib.sh"
require_resend_key

[[ $# -ge 1 ]] || err "usage: $0 {send|create|ls|get|update|rm} [args...]"
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
  send)
    event=""; contact=""; email=""; payload_arg=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --event)   event="$2"; shift 2 ;;
        --contact) contact="$2"; shift 2 ;;
        --email)   email="$2"; shift 2 ;;
        --payload) payload_arg="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    [[ -n "$event" ]] || err "missing --event <event_name>"
    [[ -n "$contact" || -n "$email" ]] || err "must supply --contact <id> or --email <addr>"
    body=$(jq -nc --arg e "$event" '{event: $e}')
    [[ -n "$contact" ]] && body=$(printf '%s' "$body" | jq -c --arg v "$contact" '. + {contact_id: $v}')
    [[ -n "$email" ]]   && body=$(printf '%s' "$body" | jq -c --arg v "$email" '. + {email: $v}')
    if [[ -n "$payload_arg" ]]; then
      payload=$(_load_body "$payload_arg")
      body=$(printf '%s' "$body" | jq -c --argjson v "$payload" '. + {payload: $v}')
    fi
    resend_api POST "/events/send" "$body" | pretty
    ;;

  create)
    name=""; body_arg=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name) name="$2"; shift 2 ;;
        --body) body_arg="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    if [[ -n "$body_arg" ]]; then
      body=$(_load_body "$body_arg")
    else
      [[ -n "$name" ]] || err "missing --name (or pass --body @schema.json)"
      body=$(jq -nc --arg n "$name" '{name: $n}')
    fi
    resend_api POST "/event-schemas" "$body" | pretty
    ;;

  ls|list)    resend_api GET "/event-schemas" | pretty ;;
  get)
    [[ $# -ge 1 ]] || err "usage: $0 get <event_schema_id>"
    resend_api GET "/event-schemas/$1" | pretty ;;
  update)
    [[ $# -ge 2 ]] || err "usage: $0 update <id> <@file.json|json-body>"
    sid="$1"; body=$(_load_body "$2")
    resend_api PATCH "/event-schemas/$sid" "$body" | pretty ;;
  rm|delete)
    [[ $# -ge 1 ]] || err "usage: $0 rm <event_schema_id>"
    resend_api DELETE "/event-schemas/$1" | pretty ;;

  *) err "unknown action: $action  (try: send|create|ls|get|update|rm)" ;;
esac
