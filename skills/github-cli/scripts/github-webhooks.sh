#!/usr/bin/env bash
# github-webhooks.sh - repo & org webhooks + branch protection (rulesets) + deploy keys.
# MCP gap-filler: the official MCP exposes none of these. All operations use REST.
#
# Usage:
#   ./github-webhooks.sh ls          [<owner>/<repo>]
#   ./github-webhooks.sh get         [<owner>/<repo>] <hook-id>
#   ./github-webhooks.sh create      [<owner>/<repo>] <url> [--secret X] [--events push,pull_request,...] [--insecure-ssl]
#   ./github-webhooks.sh update      [<owner>/<repo>] <hook-id> <patch-json>
#   ./github-webhooks.sh rm          [<owner>/<repo>] <hook-id>
#   ./github-webhooks.sh test        [<owner>/<repo>] <hook-id>
#   ./github-webhooks.sh deliveries  [<owner>/<repo>] <hook-id> [--limit 30]
#   ./github-webhooks.sh redeliver   [<owner>/<repo>] <hook-id> <delivery-id>
#
#   ./github-webhooks.sh org-ls      <org>
#   ./github-webhooks.sh org-create  <org> <url> [--secret X] [--events push,...] [--insecure-ssl]
#   ./github-webhooks.sh org-rm      <org> <hook-id>
#
#   ./github-webhooks.sh rulesets    [<owner>/<repo>]                # branch protection rulesets
#   ./github-webhooks.sh ruleset-get [<owner>/<repo>] <ruleset-id>
#   ./github-webhooks.sh ruleset-rm  [<owner>/<repo>] <ruleset-id>
#
#   ./github-webhooks.sh deploy-keys [<owner>/<repo>]
#   ./github-webhooks.sh deploy-key-add [<owner>/<repo>] "<title>" <pubkey-file> [--read-only]
#   ./github-webhooks.sh deploy-key-rm  [<owner>/<repo>] <key-id>

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|create|update|rm|test|deliveries|redeliver|org-ls|org-create|org-rm|rulesets|ruleset-get|ruleset-rm|deploy-keys|deploy-key-add|deploy-key-rm} [args...]"

action="$1"; shift

# Build a webhook config object: url + secret + content_type + insecure_ssl.
_hook_body() {
  local url="$1" secret="$2" events_csv="$3" insecure="$4"
  local events_json='["push"]'
  [[ -n "$events_csv" ]] && events_json=$(jq -nc --arg s "$events_csv" '$s | split(",")')
  jq -nc \
    --arg url "$url" --arg secret "$secret" --arg ins "$insecure" \
    --argjson events "$events_json" \
    '{name:"web", active:true, events:$events,
      config: {url:$url, content_type:"json"}
              + (if $secret != "" then {secret:$secret}      else {} end)
              + (if $ins    == "true" then {insecure_ssl:"1"} else {insecure_ssl:"0"} end)}'
}

case "$action" in
  ls)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/hooks?per_page=100" | jq .
    ;;

  get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 get [<owner>/<repo>] <hook-id>"
    github_api GET "/repos/${repo}/hooks/$1" | jq .
    ;;

  create)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 create [<owner>/<repo>] <url> [--secret X] [--events ...] [--insecure-ssl]"
    url="$1"; shift
    secret=""; events=""; insecure="false"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --secret) secret="$2"; shift 2 ;;
        --events) events="$2"; shift 2 ;;
        --insecure-ssl) insecure="true"; shift ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(_hook_body "$url" "$secret" "$events" "$insecure")
    github_api POST "/repos/${repo}/hooks" "$body" | jq .
    ;;

  update)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 update [<owner>/<repo>] <hook-id> <patch-json>"
    github_api PATCH "/repos/${repo}/hooks/$1" "$2" | jq .
    ;;

  rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 rm [<owner>/<repo>] <hook-id>"
    github_api DELETE "/repos/${repo}/hooks/$1"
    printf '\033[32m✓\033[0m webhook %s deleted\n' "$1"
    ;;

  test)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 test [<owner>/<repo>] <hook-id>"
    github_api POST "/repos/${repo}/hooks/$1/tests"
    printf '\033[32m✓\033[0m test event sent to webhook %s\n' "$1"
    ;;

  deliveries)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 deliveries [<owner>/<repo>] <hook-id> [--limit 30]"
    hid="$1"; shift
    limit=30
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/repos/${repo}/hooks/${hid}/deliveries?per_page=${limit}" | jq .
    ;;

  redeliver)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 redeliver [<owner>/<repo>] <hook-id> <delivery-id>"
    github_api POST "/repos/${repo}/hooks/$1/deliveries/$2/attempts"
    printf '\033[32m✓\033[0m redelivery queued\n'
    ;;

  org-ls)
    [[ $# -ge 1 ]] || err "usage: $0 org-ls <org>"
    github_api GET "/orgs/$1/hooks?per_page=100" | jq .
    ;;

  org-create)
    [[ $# -ge 2 ]] || err "usage: $0 org-create <org> <url> [--secret X] [--events ...] [--insecure-ssl]"
    org="$1"; url="$2"; shift 2
    secret=""; events=""; insecure="false"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --secret) secret="$2"; shift 2 ;;
        --events) events="$2"; shift 2 ;;
        --insecure-ssl) insecure="true"; shift ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(_hook_body "$url" "$secret" "$events" "$insecure")
    github_api POST "/orgs/${org}/hooks" "$body" | jq .
    ;;

  org-rm)
    [[ $# -ge 2 ]] || err "usage: $0 org-rm <org> <hook-id>"
    github_api DELETE "/orgs/$1/hooks/$2"
    printf '\033[32m✓\033[0m org webhook %s deleted\n' "$2"
    ;;

  rulesets)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/rulesets?per_page=100" | jq .
    ;;

  ruleset-get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 ruleset-get [<owner>/<repo>] <ruleset-id>"
    github_api GET "/repos/${repo}/rulesets/$1" | jq .
    ;;

  ruleset-rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 ruleset-rm [<owner>/<repo>] <ruleset-id>"
    github_api DELETE "/repos/${repo}/rulesets/$1"
    printf '\033[32m✓\033[0m ruleset %s deleted\n' "$1"
    ;;

  deploy-keys)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/keys?per_page=100" | jq .
    ;;

  deploy-key-add)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 deploy-key-add [<owner>/<repo>] \"<title>\" <pubkey-file> [--read-only]"
    title="$1"; src="$2"; shift 2
    [[ -f "$src" ]] || err "pubkey file not found: $src"
    read_only=false
    [[ "${1:-}" == "--read-only" ]] && read_only=true
    key_content=$(cat "$src")
    body=$(jq -nc --arg t "$title" --arg k "$key_content" --argjson r "$read_only" \
      '{title:$t, key:$k, read_only:$r}')
    github_api POST "/repos/${repo}/keys" "$body" | jq .
    ;;

  deploy-key-rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 deploy-key-rm [<owner>/<repo>] <key-id>"
    github_api DELETE "/repos/${repo}/keys/$1"
    printf '\033[32m✓\033[0m deploy key %s deleted\n' "$1"
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
