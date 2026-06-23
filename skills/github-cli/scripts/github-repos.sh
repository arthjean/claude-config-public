#!/usr/bin/env bash
# github-repos.sh - repository CRUD + topics + stars + traffic.
# Replaces MCP tools: create_repository, fork_repository, search_repositories,
#                     get_repository_tree, list_branches, create_branch,
#                     get_commit, list_commits, get_tag, list_tags,
#                     star_repository, unstar_repository, list_starred_repositories.
# Adds (MCP gaps): delete_repository, archive, transfer, topics, traffic, repo settings patch.
#
# Usage:
#   ./github-repos.sh ls       [--owner <org>] [--limit 30]
#   ./github-repos.sh get      [<owner>/<repo>]
#   ./github-repos.sh create   <name> [--private] [--description "…"] [--org <org>] [--gitignore Node] [--license MIT]
#   ./github-repos.sh fork     <owner>/<repo> [--org <target-org>]
#   ./github-repos.sh edit     [<owner>/<repo>] <patch-json>
#   ./github-repos.sh archive  [<owner>/<repo>]
#   ./github-repos.sh unarchive [<owner>/<repo>]
#   ./github-repos.sh rm       [<owner>/<repo>]                          # destructive
#   ./github-repos.sh transfer [<owner>/<repo>] <new_owner>
#   ./github-repos.sh search   "<query>" [--limit 30]
#   ./github-repos.sh tree     [<owner>/<repo>] [<ref>] [--recursive]
#   ./github-repos.sh branches [<owner>/<repo>]
#   ./github-repos.sh branch-create [<owner>/<repo>] <new-branch> [<from-ref>]
#   ./github-repos.sh commits  [<owner>/<repo>] [<ref>] [--limit 30]
#   ./github-repos.sh commit   [<owner>/<repo>] <sha>
#   ./github-repos.sh tags     [<owner>/<repo>]
#   ./github-repos.sh tag      [<owner>/<repo>] <tag>
#   ./github-repos.sh topics   [<owner>/<repo>] [<comma-separated-topics>]   # set if topics arg, else get
#   ./github-repos.sh star     <owner>/<repo>
#   ./github-repos.sh unstar   <owner>/<repo>
#   ./github-repos.sh starred  [--limit 100]
#   ./github-repos.sh traffic  [<owner>/<repo>]                          # views, clones, referrers, paths

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|create|fork|edit|archive|unarchive|rm|transfer|search|tree|branches|branch-create|commits|commit|tags|tag|topics|star|unstar|starred|traffic} [args...]"

action="$1"; shift

case "$action" in
  ls)
    owner=""; limit=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --owner) owner="$2"; shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    if [[ -n "$owner" ]]; then
      github_api GET "/orgs/${owner}/repos?per_page=${limit}&sort=updated" | jq .
    else
      github_api GET "/user/repos?per_page=${limit}&sort=updated&affiliation=owner,collaborator,organization_member" | jq .
    fi
    ;;

  get)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}" | jq .
    ;;

  create)
    [[ $# -ge 1 ]] || err "usage: $0 create <name> [--private] [--description …] [--org <org>] [--gitignore X] [--license Y]"
    name="$1"; shift
    private=false; desc=""; org=""; gitignore=""; license=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --private)     private=true; shift ;;
        --description) desc="$2"; shift 2 ;;
        --org)         org="$2"; shift 2 ;;
        --gitignore)   gitignore="$2"; shift 2 ;;
        --license)     license="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc \
      --arg name "$name" --arg desc "$desc" \
      --arg gi "$gitignore" --arg lic "$license" \
      --argjson priv "$private" \
      '{name: $name, private: $priv}
       + (if $desc != "" then {description: $desc} else {} end)
       + (if $gi   != "" then {gitignore_template: $gi} else {} end)
       + (if $lic  != "" then {license_template:   $lic} else {} end)')
    if [[ -n "$org" ]]; then
      github_api POST "/orgs/${org}/repos" "$body" | jq .
    else
      github_api POST "/user/repos" "$body" | jq .
    fi
    ;;

  fork)
    [[ $# -ge 1 ]] || err "usage: $0 fork <owner>/<repo> [--org <target>]"
    src="$1"; shift
    org=""
    [[ "${1:-}" == "--org" ]] && { org="$2"; shift 2; }
    body='{}'
    [[ -n "$org" ]] && body=$(jq -nc --arg o "$org" '{organization: $o}')
    github_api POST "/repos/${src}/forks" "$body" | jq .
    ;;

  edit)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 edit [<owner>/<repo>] <patch-json>"
    github_api PATCH "/repos/${repo}" "$1" | jq .
    ;;

  archive)
    repo=$(resolve_repo "${1:-}")
    github_api PATCH "/repos/${repo}" '{"archived":true}' | jq .
    ;;

  unarchive)
    repo=$(resolve_repo "${1:-}")
    github_api PATCH "/repos/${repo}" '{"archived":false}' | jq .
    ;;

  rm)
    repo=$(resolve_repo "${1:-}")
    warn_msg="About to DELETE ${repo} - this is irreversible."
    printf '\033[31m!!\033[0m %s\n' "$warn_msg" >&2
    printf 'Type the repo name to confirm: ' >&2
    read -r confirm
    [[ "$confirm" == "${repo##*/}" ]] || err "confirmation did not match - aborted"
    github_api DELETE "/repos/${repo}"
    ok_msg="Deleted ${repo}"
    printf '\033[32m✓\033[0m %s\n' "$ok_msg"
    ;;

  transfer)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 transfer [<owner>/<repo>] <new_owner>"
    body=$(jq -nc --arg o "$1" '{new_owner: $o}')
    github_api POST "/repos/${repo}/transfer" "$body" | jq .
    ;;

  search)
    [[ $# -ge 1 ]] || err "usage: $0 search \"<query>\" [--limit 30]"
    q=$(urlencode "$1"); shift
    limit=30
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/search/repositories?q=${q}&per_page=${limit}" | jq .
    ;;

  tree)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    ref="${1:-HEAD}"; recursive=""
    [[ "${2:-}" == "--recursive" ]] && recursive="?recursive=1"
    # Resolve ref → sha first (HEAD or branch name)
    sha=$(github_api GET "/repos/${repo}/commits/${ref}" | jq -r '.commit.tree.sha')
    github_api GET "/repos/${repo}/git/trees/${sha}${recursive}" | jq .
    ;;

  branches)
    repo=$(resolve_repo "${1:-}")
    github_paginate "/repos/${repo}/branches?per_page=100" | jq .
    ;;

  branch-create)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 branch-create [<owner>/<repo>] <new-branch> [<from-ref>]"
    new="$1"; from="${2:-HEAD}"
    sha=$(github_api GET "/repos/${repo}/commits/${from}" | jq -r '.sha')
    body=$(jq -nc --arg ref "refs/heads/${new}" --arg s "$sha" '{ref:$ref, sha:$s}')
    github_api POST "/repos/${repo}/git/refs" "$body" | jq .
    ;;

  commits)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    ref="${1:-}"; limit=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --limit) limit="$2"; shift 2 ;;
        *) ref="$1"; shift ;;
      esac
    done
    qs="per_page=${limit}"
    [[ -n "$ref" ]] && qs="${qs}&sha=$(urlencode "$ref")"
    github_api GET "/repos/${repo}/commits?${qs}" | jq .
    ;;

  commit)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 commit [<owner>/<repo>] <sha>"
    github_api GET "/repos/${repo}/commits/$1" | jq .
    ;;

  tags)
    repo=$(resolve_repo "${1:-}")
    github_paginate "/repos/${repo}/tags?per_page=100" | jq .
    ;;

  tag)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 tag [<owner>/<repo>] <tag>"
    github_api GET "/repos/${repo}/git/refs/tags/$1" | jq .
    ;;

  topics)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    if [[ $# -ge 1 ]]; then
      # Set: split CSV → JSON array
      arr=$(jq -nc --arg s "$1" '{names: ($s | split(","))}')
      github_api PUT "/repos/${repo}/topics" "$arr" | jq .
    else
      github_api GET "/repos/${repo}/topics" | jq .
    fi
    ;;

  star)
    [[ $# -ge 1 ]] || err "usage: $0 star <owner>/<repo>"
    github_api PUT "/user/starred/$1" -H "Content-Length: 0"
    printf '\033[32m✓\033[0m starred %s\n' "$1"
    ;;

  unstar)
    [[ $# -ge 1 ]] || err "usage: $0 unstar <owner>/<repo>"
    github_api DELETE "/user/starred/$1"
    printf '\033[32m✓\033[0m unstarred %s\n' "$1"
    ;;

  starred)
    limit=100
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/user/starred?per_page=${limit}" | jq .
    ;;

  traffic)
    repo=$(resolve_repo "${1:-}")
    jq -n \
      --argjson views     "$(github_api GET "/repos/${repo}/traffic/views"     2>/dev/null || echo '{}')" \
      --argjson clones    "$(github_api GET "/repos/${repo}/traffic/clones"    2>/dev/null || echo '{}')" \
      --argjson referrers "$(github_api GET "/repos/${repo}/traffic/popular/referrers" 2>/dev/null || echo '[]')" \
      --argjson paths     "$(github_api GET "/repos/${repo}/traffic/popular/paths"     2>/dev/null || echo '[]')" \
      '{views:$views, clones:$clones, referrers:$referrers, paths:$paths}'
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
