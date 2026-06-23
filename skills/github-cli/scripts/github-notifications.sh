#!/usr/bin/env bash
# github-notifications.sh - notification inbox.
# Replaces MCP tools: list_notifications, get_notification_details, dismiss_notification,
#                     mark_all_notifications_read, manage_notification_subscription,
#                     manage_repository_notification_subscription.
#
# Usage:
#   ./github-notifications.sh ls           [--all] [--participating] [--since YYYY-MM-DD]
#   ./github-notifications.sh get          <thread-id>
#   ./github-notifications.sh read         <thread-id>             # mark single thread as read
#   ./github-notifications.sh done         <thread-id>             # mark thread as done (dismiss)
#   ./github-notifications.sh read-all     [--repo <owner>/<repo>] # mark all as read (optionally per repo)
#   ./github-notifications.sh subscribe    <thread-id> [--ignored]
#   ./github-notifications.sh unsubscribe  <thread-id>
#   ./github-notifications.sh repo-watch   <owner>/<repo> [--ignored]
#   ./github-notifications.sh repo-unwatch <owner>/<repo>

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|read|done|read-all|subscribe|unsubscribe|repo-watch|repo-unwatch} [args...]"

action="$1"; shift

case "$action" in
  ls)
    qs="per_page=50"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --all)           qs="${qs}&all=true"; shift ;;
        --participating) qs="${qs}&participating=true"; shift ;;
        --since)         qs="${qs}&since=$(urlencode "$2")T00:00:00Z"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    github_api GET "/notifications?${qs}" | jq .
    ;;

  get)
    [[ $# -ge 1 ]] || err "usage: $0 get <thread-id>"
    github_api GET "/notifications/threads/$1" | jq .
    ;;

  read)
    [[ $# -ge 1 ]] || err "usage: $0 read <thread-id>"
    github_api PATCH "/notifications/threads/$1"
    printf '\033[32m✓\033[0m thread %s marked as read\n' "$1"
    ;;

  done)
    [[ $# -ge 1 ]] || err "usage: $0 done <thread-id>"
    github_api DELETE "/notifications/threads/$1"
    printf '\033[32m✓\033[0m thread %s dismissed (done)\n' "$1"
    ;;

  read-all)
    repo=""
    [[ "${1:-}" == "--repo" ]] && { repo="$2"; shift 2; }
    last_read="$(date -u +%FT%TZ)"
    body=$(jq -nc --arg t "$last_read" '{last_read_at:$t, read:true}')
    if [[ -n "$repo" ]]; then
      github_api PUT "/repos/${repo}/notifications" "$body"
      printf '\033[32m✓\033[0m all %s notifications marked as read\n' "$repo"
    else
      github_api PUT "/notifications" "$body"
      printf '\033[32m✓\033[0m all notifications marked as read\n'
    fi
    ;;

  subscribe)
    [[ $# -ge 1 ]] || err "usage: $0 subscribe <thread-id> [--ignored]"
    tid="$1"; shift
    ignored=false
    [[ "${1:-}" == "--ignored" ]] && ignored=true
    body=$(jq -nc --argjson i "$ignored" '{subscribed:(if $i then false else true end), ignored:$i}')
    github_api PUT "/notifications/threads/${tid}/subscription" "$body" | jq .
    ;;

  unsubscribe)
    [[ $# -ge 1 ]] || err "usage: $0 unsubscribe <thread-id>"
    github_api DELETE "/notifications/threads/$1/subscription"
    printf '\033[32m✓\033[0m unsubscribed from thread %s\n' "$1"
    ;;

  repo-watch)
    [[ $# -ge 1 ]] || err "usage: $0 repo-watch <owner>/<repo> [--ignored]"
    repo="$1"; shift
    ignored=false
    [[ "${1:-}" == "--ignored" ]] && ignored=true
    body=$(jq -nc --argjson i "$ignored" '{subscribed:(if $i then false else true end), ignored:$i}')
    github_api PUT "/repos/${repo}/subscription" "$body" | jq .
    ;;

  repo-unwatch)
    [[ $# -ge 1 ]] || err "usage: $0 repo-unwatch <owner>/<repo>"
    github_api DELETE "/repos/$1/subscription"
    printf '\033[32m✓\033[0m unwatched %s\n' "$1"
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
