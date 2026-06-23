#!/usr/bin/env bash
# github-prs.sh - pull request CRUD + reviews + merging.
# Replaces MCP tools: create_pull_request, update_pull_request, merge_pull_request,
#                     list_pull_requests, search_pull_requests, update_pull_request_branch,
#                     pull_request_read (get + diff + status + files + reviews + comments + checks),
#                     pull_request_review_write, add_comment_to_pending_review,
#                     add_reply_to_pull_request_comment, request_copilot_review.
#
# Usage:
#   ./github-prs.sh ls          [<owner>/<repo>] [--state open|closed|all] [--limit 30]
#   ./github-prs.sh get         [<owner>/<repo>] <number>
#   ./github-prs.sh diff        [<owner>/<repo>] <number>
#   ./github-prs.sh files       [<owner>/<repo>] <number>
#   ./github-prs.sh checks      [<owner>/<repo>] <number>            # combined status + check runs
#   ./github-prs.sh reviews     [<owner>/<repo>] <number>
#   ./github-prs.sh comments    [<owner>/<repo>] <number>            # review comments (line-level)
#   ./github-prs.sh issue-comments [<owner>/<repo>] <number>         # conversation comments
#   ./github-prs.sh create      [<owner>/<repo>] "<title>" <head> <base> [--body "…"] [--draft]
#   ./github-prs.sh update      [<owner>/<repo>] <number> <patch-json>
#   ./github-prs.sh ready       [<owner>/<repo>] <number>
#   ./github-prs.sh draft       [<owner>/<repo>] <number>
#   ./github-prs.sh merge       [<owner>/<repo>] <number> [--method merge|squash|rebase] [--commit-message "…"]
#   ./github-prs.sh sync-branch [<owner>/<repo>] <number>            # update PR branch from base
#   ./github-prs.sh comment     [<owner>/<repo>] <number> "<body>"   # PR conversation
#   ./github-prs.sh review      [<owner>/<repo>] <number> approve|request-changes|comment "<body>"
#   ./github-prs.sh review-line [<owner>/<repo>] <number> <commit-sha> <path> <line> "<body>"
#   ./github-prs.sh review-reply [<owner>/<repo>] <number> <comment-id> "<body>"
#   ./github-prs.sh request-review [<owner>/<repo>] <number> <user>...
#   ./github-prs.sh request-copilot [<owner>/<repo>] <number>
#   ./github-prs.sh search      "<query>" [--limit 30]

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|diff|files|checks|reviews|comments|issue-comments|create|update|ready|draft|merge|sync-branch|comment|review|review-line|review-reply|request-review|request-copilot|search} [args...]"

action="$1"; shift

case "$action" in
  ls)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    state="open"; limit=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --state) state="$2"; shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    github_api GET "/repos/${repo}/pulls?state=${state}&per_page=${limit}" | jq .
    ;;

  get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 get [<owner>/<repo>] <number>"
    github_api GET "/repos/${repo}/pulls/$1" | jq .
    ;;

  diff)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 diff [<owner>/<repo>] <number>"
    github_api GET "/repos/${repo}/pulls/$1" -H "Accept: application/vnd.github.v3.diff"
    ;;

  files)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 files [<owner>/<repo>] <number>"
    github_paginate "/repos/${repo}/pulls/$1/files?per_page=100" | jq .
    ;;

  checks)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 checks [<owner>/<repo>] <number>"
    pr=$(github_api GET "/repos/${repo}/pulls/$1")
    sha=$(echo "$pr" | jq -r '.head.sha')
    jq -n \
      --argjson status "$(github_api GET "/repos/${repo}/commits/${sha}/status" 2>/dev/null || echo '{}')" \
      --argjson runs   "$(github_api GET "/repos/${repo}/commits/${sha}/check-runs" 2>/dev/null || echo '{}')" \
      '{status:$status, check_runs:$runs}'
    ;;

  reviews)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 reviews [<owner>/<repo>] <number>"
    github_paginate "/repos/${repo}/pulls/$1/reviews?per_page=100" | jq .
    ;;

  comments)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 comments [<owner>/<repo>] <number>"
    github_paginate "/repos/${repo}/pulls/$1/comments?per_page=100" | jq .
    ;;

  issue-comments)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 issue-comments [<owner>/<repo>] <number>"
    github_paginate "/repos/${repo}/issues/$1/comments?per_page=100" | jq .
    ;;

  create)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 create [<owner>/<repo>] \"<title>\" <head> <base> [--body \"…\"] [--draft]"
    title="$1"; head="$2"; base="$3"; shift 3
    body_text=""; draft=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --body)  body_text="$2"; shift 2 ;;
        --draft) draft=true; shift ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc \
      --arg title "$title" --arg head "$head" --arg base "$base" \
      --arg b "$body_text" --argjson d "$draft" \
      '{title:$title, head:$head, base:$base, draft:$d}
       + (if $b != "" then {body:$b} else {} end)')
    github_api POST "/repos/${repo}/pulls" "$body" | jq .
    ;;

  update)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 update [<owner>/<repo>] <number> <patch-json>"
    github_api PATCH "/repos/${repo}/pulls/$1" "$2" | jq .
    ;;

  ready)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    # Marking ready uses GraphQL mutation.
    [[ $# -ge 1 ]] || err "usage: $0 ready [<owner>/<repo>] <number>"
    pr_node_id=$(github_api GET "/repos/${repo}/pulls/$1" | jq -r '.node_id')
    q='mutation($id:ID!){markPullRequestReadyForReview(input:{pullRequestId:$id}){pullRequest{isDraft}}}'
    github_graphql "$q" "id=${pr_node_id}" | jq .
    ;;

  draft)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 draft [<owner>/<repo>] <number>"
    pr_node_id=$(github_api GET "/repos/${repo}/pulls/$1" | jq -r '.node_id')
    q='mutation($id:ID!){convertPullRequestToDraft(input:{pullRequestId:$id}){pullRequest{isDraft}}}'
    github_graphql "$q" "id=${pr_node_id}" | jq .
    ;;

  merge)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 merge [<owner>/<repo>] <number> [--method merge|squash|rebase] [--commit-message \"…\"]"
    num="$1"; shift
    method="merge"; commit_msg=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --method) method="$2"; shift 2 ;;
        --commit-message) commit_msg="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc --arg m "$method" --arg msg "$commit_msg" \
      '{merge_method:$m} + (if $msg != "" then {commit_message:$msg} else {} end)')
    github_api PUT "/repos/${repo}/pulls/${num}/merge" "$body" | jq .
    ;;

  sync-branch)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 sync-branch [<owner>/<repo>] <number>"
    github_api PUT "/repos/${repo}/pulls/$1/update-branch" '{}' | jq .
    ;;

  comment)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 comment [<owner>/<repo>] <number> \"<body>\""
    body=$(jq -nc --arg b "$2" '{body:$b}')
    github_api POST "/repos/${repo}/issues/$1/comments" "$body" | jq .
    ;;

  review)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 review [<owner>/<repo>] <number> approve|request-changes|comment \"<body>\""
    num="$1"; verdict="$2"; body_text="$3"
    case "$verdict" in
      approve)         event="APPROVE" ;;
      request-changes) event="REQUEST_CHANGES" ;;
      comment)         event="COMMENT" ;;
      *) err "verdict must be: approve | request-changes | comment" ;;
    esac
    body=$(jq -nc --arg e "$event" --arg b "$body_text" '{event:$e, body:$b}')
    github_api POST "/repos/${repo}/pulls/${num}/reviews" "$body" | jq .
    ;;

  review-line)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 5 ]] || err "usage: $0 review-line [<owner>/<repo>] <number> <commit-sha> <path> <line> \"<body>\""
    num="$1"; sha="$2"; path="$3"; line="$4"; body_text="$5"
    body=$(jq -nc --arg s "$sha" --arg p "$path" --argjson l "$line" --arg b "$body_text" \
      '{commit_id:$s, path:$p, line:$l, side:"RIGHT", body:$b}')
    github_api POST "/repos/${repo}/pulls/${num}/comments" "$body" | jq .
    ;;

  review-reply)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 review-reply [<owner>/<repo>] <number> <comment-id> \"<body>\""
    num="$1"; cid="$2"; body_text="$3"
    body=$(jq -nc --arg b "$body_text" '{body:$b}')
    github_api POST "/repos/${repo}/pulls/${num}/comments/${cid}/replies" "$body" | jq .
    ;;

  request-review)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 request-review [<owner>/<repo>] <number> <user>..."
    num="$1"; shift
    body=$(printf '%s\n' "$@" | jq -R . | jq -sc '{reviewers: .}')
    github_api POST "/repos/${repo}/pulls/${num}/requested_reviewers" "$body" | jq .
    ;;

  request-copilot)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 request-copilot [<owner>/<repo>] <number>"
    body='{"reviewers":["copilot-pull-request-reviewer[bot]"]}'
    github_api POST "/repos/${repo}/pulls/$1/requested_reviewers" "$body" | jq .
    ;;

  search)
    [[ $# -ge 1 ]] || err "usage: $0 search \"<query>\" [--limit 30]"
    q=$(urlencode "is:pr $1"); shift
    limit=30
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/search/issues?q=${q}&per_page=${limit}" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
