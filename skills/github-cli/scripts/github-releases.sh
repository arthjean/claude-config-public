#!/usr/bin/env bash
# github-releases.sh - full release lifecycle (CRUD + asset upload/download).
# MCP gap-filler: the official GitHub MCP only exposes get_latest_release, get_release_by_tag,
# list_releases - no create/update/delete/upload. This script provides all of it.
#
# Usage:
#   ./github-releases.sh ls          [<owner>/<repo>] [--limit 30]
#   ./github-releases.sh latest      [<owner>/<repo>]
#   ./github-releases.sh get         [<owner>/<repo>] <release-id-or-tag>
#   ./github-releases.sh create      [<owner>/<repo>] <tag> [--name "…"] [--notes "…"] [--draft] [--prerelease] [--target main]
#   ./github-releases.sh generate-notes [<owner>/<repo>] <tag> [<previous-tag>]
#   ./github-releases.sh update      [<owner>/<repo>] <release-id> <patch-json>
#   ./github-releases.sh rm          [<owner>/<repo>] <release-id>
#   ./github-releases.sh upload      [<owner>/<repo>] <release-id> <local-file> [--name override.tar.gz] [--label "Linux x64"]
#   ./github-releases.sh download    [<owner>/<repo>] <release-id> <asset-id> <output-path>
#   ./github-releases.sh assets      [<owner>/<repo>] <release-id>

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|latest|get|create|generate-notes|update|rm|upload|download|assets} [args...]"

action="$1"; shift

case "$action" in
  ls)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    limit=30
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/repos/${repo}/releases?per_page=${limit}" | jq .
    ;;

  latest)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/releases/latest" | jq .
    ;;

  get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 get [<owner>/<repo>] <release-id-or-tag>"
    # Numeric → release id, otherwise → tag.
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      github_api GET "/repos/${repo}/releases/$1" | jq .
    else
      github_api GET "/repos/${repo}/releases/tags/$(urlencode "$1")" | jq .
    fi
    ;;

  create)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 create [<owner>/<repo>] <tag> [--name …] [--notes …] [--draft] [--prerelease] [--target main]"
    tag="$1"; shift
    name=""; notes=""; draft=false; pre=false; target=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name)       name="$2"; shift 2 ;;
        --notes)      notes="$2"; shift 2 ;;
        --draft)      draft=true; shift ;;
        --prerelease) pre=true; shift ;;
        --target)     target="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc \
      --arg tag "$tag" --arg name "$name" --arg notes "$notes" --arg target "$target" \
      --argjson draft "$draft" --argjson pre "$pre" \
      '{tag_name:$tag, draft:$draft, prerelease:$pre}
       + (if $name   != "" then {name:$name}             else {} end)
       + (if $notes  != "" then {body:$notes}            else {} end)
       + (if $target != "" then {target_commitish:$target} else {} end)')
    github_api POST "/repos/${repo}/releases" "$body" | jq .
    ;;

  generate-notes)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 generate-notes [<owner>/<repo>] <tag> [<previous-tag>]"
    tag="$1"; prev="${2:-}"
    body=$(jq -nc --arg tag "$tag" --arg prev "$prev" \
      '{tag_name:$tag} + (if $prev != "" then {previous_tag_name:$prev} else {} end)')
    github_api POST "/repos/${repo}/releases/generate-notes" "$body" | jq .
    ;;

  update)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 update [<owner>/<repo>] <release-id> <patch-json>"
    github_api PATCH "/repos/${repo}/releases/$1" "$2" | jq .
    ;;

  rm)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 rm [<owner>/<repo>] <release-id>"
    github_api DELETE "/repos/${repo}/releases/$1"
    printf '\033[32m✓\033[0m release %s deleted\n' "$1"
    ;;

  upload)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 upload [<owner>/<repo>] <release-id> <local-file> [--name X] [--label Y]"
    rid="$1"; src="$2"; shift 2
    [[ -f "$src" ]] || err "local file not found: $src"
    name="$(basename "$src")"; label=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name)  name="$2";  shift 2 ;;
        --label) label="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    # Uploads go to uploads.github.com, NOT api.github.com. Content-Type derived from file.
    ctype=$(file --mime-type -b "$src" 2>/dev/null || echo "application/octet-stream")
    qs="name=$(urlencode "$name")"
    [[ -n "$label" ]] && qs="${qs}&label=$(urlencode "$label")"
    curl -sS \
      -X POST \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
      -H "Content-Type: ${ctype}" \
      -H "User-Agent: github-cli-skill" \
      --data-binary "@$src" \
      "https://uploads.github.com/repos/${repo}/releases/${rid}/assets?${qs}" | jq .
    ;;

  download)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 3 ]] || err "usage: $0 download [<owner>/<repo>] <release-id> <asset-id> <output-path>"
    rid="$1"; aid="$2"; out="$3"
    curl -sSL -o "$out" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/octet-stream" \
      -H "User-Agent: github-cli-skill" \
      "https://api.github.com/repos/${repo}/releases/assets/${aid}"
    printf '\033[32m✓\033[0m asset saved to %s\n' "$out"
    ;;

  assets)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 assets [<owner>/<repo>] <release-id>"
    github_api GET "/repos/${repo}/releases/$1/assets?per_page=100" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
