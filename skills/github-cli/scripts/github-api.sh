#!/usr/bin/env bash
# github-api.sh - generic authenticated REST/GraphQL caller for api.github.com.
# Auto-injects Authorization, Accept, X-GitHub-Api-Version headers. Retries on rate-limit.
#
# Usage:
#   ./github-api.sh GET    /user
#   ./github-api.sh GET    "/repos/cli/cli/issues?state=open&per_page=100"
#   ./github-api.sh GET    "/repos/cli/cli/issues" --paginate     # auto-follow Link headers
#   ./github-api.sh POST   /repos/cli/cli/issues '{"title":"Bug","body":"…"}'
#   ./github-api.sh PATCH  /repos/cli/cli/issues/42 '{"state":"closed"}'
#   ./github-api.sh DELETE /repos/cli/cli/labels/wontfix
#   ./github-api.sh graphql 'query{viewer{login}}'
#   ./github-api.sh graphql 'query($login:String!){user(login:$login){id}}' login=octocat
#
# Output: pretty-printed JSON via jq.

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 <METHOD|graphql> <PATH|QUERY> [json_body | --paginate | key=val ...]"

method="$1"; shift

if [[ "$method" == "graphql" ]]; then
  [[ $# -ge 1 ]] || err "usage: $0 graphql <query> [key=value ...]"
  query="$1"; shift
  github_graphql "$query" "$@" | jq . 2>/dev/null || github_graphql "$query" "$@"
  exit 0
fi

[[ $# -ge 1 ]] || err "usage: $0 <METHOD> <PATH> [json_body | --paginate]"
path="$1"; shift

if [[ "${1:-}" == "--paginate" ]]; then
  github_paginate "$path" | jq .
else
  github_api "$method" "$path" "$@" | jq . 2>/dev/null || github_api "$method" "$path" "$@"
fi
