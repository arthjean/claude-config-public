#!/usr/bin/env bash
# github-search.sh - unified search across the platform.
# Replaces MCP tools: search_repositories, search_code, search_issues, search_pull_requests,
#                     search_users, search_orgs.
#
# Usage:
#   ./github-search.sh repos    "<query>" [--limit 30] [--sort stars|forks|updated]
#   ./github-search.sh code     "<query>" [--limit 30]      # query examples: 'useState filename:*.tsx org:facebook'
#   ./github-search.sh issues   "<query>" [--limit 30]      # add 'is:issue' or 'is:pr' to discriminate
#   ./github-search.sh prs      "<query>" [--limit 30]
#   ./github-search.sh users    "<query>" [--limit 30]
#   ./github-search.sh orgs     "<query>" [--limit 30]
#   ./github-search.sh commits  "<query>" [--limit 30]
#   ./github-search.sh topics   "<query>" [--limit 30]
#
# Search syntax: see https://docs.github.com/en/search-github/searching-on-github

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {repos|code|issues|prs|users|orgs|commits|topics} \"<query>\" [--limit N] [--sort X]"

action="$1"; shift

[[ $# -ge 1 ]] || err "missing query"
raw_query="$1"; shift

limit=30; sort=""; extra=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) limit="$2"; shift 2 ;;
    --sort)  sort="$2"; shift 2 ;;
    *) err "unknown flag: $1" ;;
  esac
done

# Endpoint + auto-prefix per resource.
case "$action" in
  repos)   path="/search/repositories"; q="$raw_query" ;;
  code)    path="/search/code";          q="$raw_query"
           # Code search requires sort=indexed for new index; keep default.
           ;;
  issues)  path="/search/issues";        q="is:issue $raw_query" ;;
  prs)     path="/search/issues";        q="is:pr $raw_query" ;;
  users)   path="/search/users";         q="type:user $raw_query" ;;
  orgs)    path="/search/users";         q="type:org $raw_query" ;;
  commits) path="/search/commits";       q="$raw_query"
           # commit search needs special accept header.
           extra="-H Accept: application/vnd.github.cloak-preview+json" ;;
  topics)  path="/search/topics";        q="$raw_query"
           extra="-H Accept: application/vnd.github.mercy-preview+json" ;;
  *) err "unknown search type: $action" ;;
esac

qs="q=$(urlencode "$q")&per_page=${limit}"
[[ -n "$sort" ]] && qs="${qs}&sort=$(urlencode "$sort")"

# shellcheck disable=SC2086
github_api GET "${path}?${qs}" $extra | jq .
