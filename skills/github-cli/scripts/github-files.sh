#!/usr/bin/env bash
# github-files.sh - file-level operations on a repo (read, single-file commit, multi-file commit, delete).
# Replaces MCP tools: get_file_contents, create_or_update_file, push_files, delete_file.
#
# Usage:
#   ./github-files.sh get    [<owner>/<repo>] <path>           [--ref <branch-or-sha>]
#   ./github-files.sh raw    [<owner>/<repo>] <path>           [--ref <branch-or-sha>]   # decoded content
#   ./github-files.sh put    [<owner>/<repo>] <path> <local-file> "<commit message>" [--branch main]
#   ./github-files.sh rm     [<owner>/<repo>] <path> "<commit message>" [--branch main]
#   ./github-files.sh push   [<owner>/<repo>] <branch> "<commit message>" <local-path>...   # multi-file commit via Git Data API
#
# 'put' uploads a single file (creates if missing, updates if exists - must include sha for update).
# 'push' creates a tree of multiple files in one commit (the MCP push_files equivalent).

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {get|raw|put|rm|push} [args...]"

action="$1"; shift

case "$action" in
  get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 get [<owner>/<repo>] <path> [--ref <ref>]"
    path="$1"; shift
    qs=""
    [[ "${1:-}" == "--ref" ]] && qs="?ref=$(urlencode "$2")" && shift 2
    github_api GET "/repos/${repo}/contents/${path}${qs}" | jq .
    ;;

  raw)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 raw [<owner>/<repo>] <path> [--ref <ref>]"
    path="$1"; shift
    qs=""
    [[ "${1:-}" == "--ref" ]] && qs="?ref=$(urlencode "$2")" && shift 2
    github_api GET "/repos/${repo}/contents/${path}${qs}" \
      | jq -r '.content // ""' \
      | tr -d '\n' \
      | base64 -d
    ;;

  put)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 put [<owner>/<repo>] <path> <local-file> \"<commit msg>\" [--branch main]"
    path="$1"; src="$2"; msg="$3"; shift 3
    branch=""
    [[ "${1:-}" == "--branch" ]] && { branch="$2"; shift 2; }
    [[ -f "$src" ]] || err "local file not found: $src"

    # Look up existing sha if file exists (required for update)
    existing_sha=""
    qs=""
    [[ -n "$branch" ]] && qs="?ref=$(urlencode "$branch")"
    if existing=$(github_api GET "/repos/${repo}/contents/${path}${qs}" 2>/dev/null); then
      existing_sha=$(echo "$existing" | jq -r '.sha // ""')
    fi

    content_b64=$(base64 -w0 < "$src")
    body=$(jq -nc \
      --arg msg "$msg" --arg c "$content_b64" \
      --arg branch "$branch" --arg sha "$existing_sha" \
      '{message:$msg, content:$c}
       + (if $branch != "" then {branch:$branch} else {} end)
       + (if $sha    != "" then {sha:$sha}       else {} end)')
    github_api PUT "/repos/${repo}/contents/${path}" "$body" | jq .
    ;;

  rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 rm [<owner>/<repo>] <path> \"<commit msg>\" [--branch main]"
    path="$1"; msg="$2"; shift 2
    branch=""
    [[ "${1:-}" == "--branch" ]] && { branch="$2"; shift 2; }
    qs=""
    [[ -n "$branch" ]] && qs="?ref=$(urlencode "$branch")"
    sha=$(github_api GET "/repos/${repo}/contents/${path}${qs}" | jq -r '.sha')
    [[ -z "$sha" || "$sha" == "null" ]] && err "no sha returned - file may not exist on that ref"
    body=$(jq -nc --arg msg "$msg" --arg sha "$sha" --arg branch "$branch" \
      '{message:$msg, sha:$sha} + (if $branch != "" then {branch:$branch} else {} end)')
    github_api DELETE "/repos/${repo}/contents/${path}" "$body" | jq .
    ;;

  push)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 push [<owner>/<repo>] <branch> \"<commit msg>\" <local-path>..."
    branch="$1"; msg="$2"; shift 2

    # 1. Get the latest commit on the branch.
    base_sha=$(github_api GET "/repos/${repo}/git/refs/heads/${branch}" | jq -r '.object.sha')
    base_tree=$(github_api GET "/repos/${repo}/git/commits/${base_sha}" | jq -r '.tree.sha')

    # 2. Build a list of blobs (one POST /git/blobs per file).
    tree_entries='[]'
    for f in "$@"; do
      [[ -f "$f" ]] || err "local file not found: $f"
      content_b64=$(base64 -w0 < "$f")
      blob_body=$(jq -nc --arg c "$content_b64" '{content:$c, encoding:"base64"}')
      blob_sha=$(github_api POST "/repos/${repo}/git/blobs" "$blob_body" | jq -r '.sha')
      tree_entries=$(jq -nc --argjson cur "$tree_entries" --arg path "$f" --arg sha "$blob_sha" \
        '$cur + [{path:$path, mode:"100644", type:"blob", sha:$sha}]')
    done

    # 3. POST /git/trees with base_tree to create a new tree.
    tree_body=$(jq -nc --arg base "$base_tree" --argjson entries "$tree_entries" \
      '{base_tree:$base, tree:$entries}')
    tree_sha=$(github_api POST "/repos/${repo}/git/trees" "$tree_body" | jq -r '.sha')

    # 4. POST /git/commits to create the commit object.
    commit_body=$(jq -nc --arg msg "$msg" --arg t "$tree_sha" --arg p "$base_sha" \
      '{message:$msg, tree:$t, parents:[$p]}')
    commit_sha=$(github_api POST "/repos/${repo}/git/commits" "$commit_body" | jq -r '.sha')

    # 5. PATCH the branch ref to the new commit.
    ref_body=$(jq -nc --arg s "$commit_sha" '{sha:$s}')
    github_api PATCH "/repos/${repo}/git/refs/heads/${branch}" "$ref_body" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
