#!/usr/bin/env bash
# github-issues.sh - full issue lifecycle.
# Replaces MCP tools: issue_read (get + comments + sub-issues + labels), issue_write (create + update),
#                     add_issue_comment, list_issues, search_issues, sub_issue_write, list_issue_types,
#                     get_label / list_label / label_write.
#
# Usage:
#   ./github-issues.sh ls       [<owner>/<repo>] [--state open|closed|all] [--label X] [--limit 30]
#   ./github-issues.sh get      [<owner>/<repo>] <number>
#   ./github-issues.sh comments [<owner>/<repo>] <number>
#   ./github-issues.sh create   [<owner>/<repo>] "<title>" "<body>" [--label X,Y] [--assignee user]
#   ./github-issues.sh update   [<owner>/<repo>] <number> <patch-json>
#   ./github-issues.sh comment  [<owner>/<repo>] <number> "<body>"
#   ./github-issues.sh close    [<owner>/<repo>] <number> [--reason completed|not_planned]
#   ./github-issues.sh reopen   [<owner>/<repo>] <number>
#   ./github-issues.sh lock     [<owner>/<repo>] <number> [--reason off-topic|too_heated|resolved|spam]
#   ./github-issues.sh unlock   [<owner>/<repo>] <number>
#   ./github-issues.sh assign   [<owner>/<repo>] <number> <user>...
#   ./github-issues.sh unassign [<owner>/<repo>] <number> <user>...
#   ./github-issues.sh label    [<owner>/<repo>] <number> add|remove|set <label>...
#   ./github-issues.sh search   "<query>" [--limit 30]
#   ./github-issues.sh sub-add    [<owner>/<repo>] <parent-number> <child-issue-id>
#   ./github-issues.sh sub-remove [<owner>/<repo>] <parent-number> <child-issue-id>
#   ./github-issues.sh sub-list   [<owner>/<repo>] <parent-number>
#   ./github-issues.sh labels-ls  [<owner>/<repo>]
#   ./github-issues.sh label-create [<owner>/<repo>] <name> [color] [description]
#   ./github-issues.sh label-rm     [<owner>/<repo>] <name>

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|comments|create|update|comment|close|reopen|lock|unlock|assign|unassign|label|search|sub-add|sub-remove|sub-list|labels-ls|label-create|label-rm} [args...]"

action="$1"; shift

case "$action" in
  ls)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    state="open"; label=""; limit=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --state) state="$2"; shift 2 ;;
        --label) label="$2"; shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    qs="per_page=${limit}&state=${state}"
    [[ -n "$label" ]] && qs="${qs}&labels=$(urlencode "$label")"
    github_api GET "/repos/${repo}/issues?${qs}" | jq '[.[] | select(.pull_request == null)]'
    ;;

  get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 get [<owner>/<repo>] <number>"
    github_api GET "/repos/${repo}/issues/$1" | jq .
    ;;

  comments)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 comments [<owner>/<repo>] <number>"
    github_paginate "/repos/${repo}/issues/$1/comments?per_page=100" | jq .
    ;;

  create)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 create [<owner>/<repo>] \"<title>\" \"<body>\" [--label X,Y] [--assignee user]"
    title="$1"; body_text="$2"; shift 2
    labels=""; assignee=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --label)    labels="$2"; shift 2 ;;
        --assignee) assignee="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc --arg t "$title" --arg b "$body_text" --arg l "$labels" --arg a "$assignee" \
      '{title:$t, body:$b}
       + (if $l != "" then {labels: ($l | split(","))} else {} end)
       + (if $a != "" then {assignees: [$a]}           else {} end)')
    github_api POST "/repos/${repo}/issues" "$body" | jq .
    ;;

  update)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 update [<owner>/<repo>] <number> <patch-json>"
    github_api PATCH "/repos/${repo}/issues/$1" "$2" | jq .
    ;;

  comment)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 comment [<owner>/<repo>] <number> \"<body>\""
    body=$(jq -nc --arg b "$2" '{body:$b}')
    github_api POST "/repos/${repo}/issues/$1/comments" "$body" | jq .
    ;;

  close)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 close [<owner>/<repo>] <number> [--reason completed|not_planned]"
    num="$1"; shift
    reason="completed"
    [[ "${1:-}" == "--reason" ]] && { reason="$2"; shift 2; }
    body=$(jq -nc --arg r "$reason" '{state:"closed", state_reason:$r}')
    github_api PATCH "/repos/${repo}/issues/${num}" "$body" | jq .
    ;;

  reopen)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 reopen [<owner>/<repo>] <number>"
    github_api PATCH "/repos/${repo}/issues/$1" '{"state":"open"}' | jq .
    ;;

  lock)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 lock [<owner>/<repo>] <number> [--reason off-topic|too_heated|resolved|spam]"
    num="$1"; shift
    reason=""
    [[ "${1:-}" == "--reason" ]] && { reason="$2"; shift 2; }
    body='{}'
    [[ -n "$reason" ]] && body=$(jq -nc --arg r "$reason" '{lock_reason:$r}')
    github_api PUT "/repos/${repo}/issues/${num}/lock" "$body"
    printf '\033[32m✓\033[0m issue #%s locked\n' "$num"
    ;;

  unlock)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 unlock [<owner>/<repo>] <number>"
    github_api DELETE "/repos/${repo}/issues/$1/lock"
    printf '\033[32m✓\033[0m issue #%s unlocked\n' "$1"
    ;;

  assign|unassign)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 $action [<owner>/<repo>] <number> <user>..."
    num="$1"; shift
    users_json=$(printf '%s\n' "$@" | jq -R . | jq -sc '{assignees: .}')
    if [[ "$action" == "assign" ]]; then
      github_api POST "/repos/${repo}/issues/${num}/assignees" "$users_json" | jq .
    else
      github_api DELETE "/repos/${repo}/issues/${num}/assignees" "$users_json" | jq .
    fi
    ;;

  label)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 label [<owner>/<repo>] <number> add|remove|set <label>..."
    num="$1"; op="$2"; shift 2
    case "$op" in
      add)
        labels_json=$(printf '%s\n' "$@" | jq -R . | jq -sc '{labels: .}')
        github_api POST "/repos/${repo}/issues/${num}/labels" "$labels_json" | jq .
        ;;
      set)
        labels_json=$(printf '%s\n' "$@" | jq -R . | jq -sc '{labels: .}')
        github_api PUT "/repos/${repo}/issues/${num}/labels" "$labels_json" | jq .
        ;;
      remove)
        for l in "$@"; do
          github_api DELETE "/repos/${repo}/issues/${num}/labels/$(urlencode "$l")" >/dev/null
          printf '\033[32m✓\033[0m removed label %s\n' "$l"
        done
        ;;
      *) err "label op must be add | remove | set" ;;
    esac
    ;;

  search)
    [[ $# -ge 1 ]] || err "usage: $0 search \"<query>\" [--limit 30]"
    q=$(urlencode "is:issue $1"); shift
    limit=30
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/search/issues?q=${q}&per_page=${limit}" | jq .
    ;;

  sub-add)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 sub-add [<owner>/<repo>] <parent-number> <child-issue-id>"
    body=$(jq -nc --argjson cid "$2" '{sub_issue_id:$cid}')
    github_api POST "/repos/${repo}/issues/$1/sub_issues" "$body" | jq .
    ;;

  sub-remove)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 sub-remove [<owner>/<repo>] <parent-number> <child-issue-id>"
    body=$(jq -nc --argjson cid "$2" '{sub_issue_id:$cid}')
    github_api DELETE "/repos/${repo}/issues/$1/sub_issue" "$body" | jq .
    ;;

  sub-list)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 sub-list [<owner>/<repo>] <parent-number>"
    github_api GET "/repos/${repo}/issues/$1/sub_issues" | jq .
    ;;

  labels-ls)
    repo=$(resolve_repo "${1:-}")
    github_paginate "/repos/${repo}/labels?per_page=100" | jq .
    ;;

  label-create)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 label-create [<owner>/<repo>] <name> [color-hex] [description]"
    name="$1"; color="${2:-cccccc}"; desc="${3:-}"
    body=$(jq -nc --arg n "$name" --arg c "$color" --arg d "$desc" \
      '{name:$n, color:$c} + (if $d != "" then {description:$d} else {} end)')
    github_api POST "/repos/${repo}/labels" "$body" | jq .
    ;;

  label-rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 label-rm [<owner>/<repo>] <name>"
    github_api DELETE "/repos/${repo}/labels/$(urlencode "$1")"
    printf '\033[32m✓\033[0m label %s deleted\n' "$1"
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
