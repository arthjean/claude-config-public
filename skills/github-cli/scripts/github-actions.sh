#!/usr/bin/env bash
# github-actions.sh - Actions / Workflows control surface.
# Replaces MCP tools: actions_list, actions_get, actions_run_trigger, get_job_logs.
# Adds (MCP gaps): step-level logs, artifact download, runner inventory, cache usage.
#
# Usage:
#   ./github-actions.sh workflows  [<owner>/<repo>]
#   ./github-actions.sh enable     [<owner>/<repo>] <workflow-id-or-filename>
#   ./github-actions.sh disable    [<owner>/<repo>] <workflow-id-or-filename>
#   ./github-actions.sh dispatch   [<owner>/<repo>] <workflow-id-or-filename> <ref> [inputs-json]
#   ./github-actions.sh runs       [<owner>/<repo>] [--workflow X] [--status queued|in_progress|completed] [--limit 30]
#   ./github-actions.sh run        [<owner>/<repo>] <run-id>
#   ./github-actions.sh jobs       [<owner>/<repo>] <run-id>
#   ./github-actions.sh logs       [<owner>/<repo>] <run-id>          # zip of all logs (raw bytes to stdout)
#   ./github-actions.sh job-logs   [<owner>/<repo>] <job-id>          # plain-text job log
#   ./github-actions.sh rerun      [<owner>/<repo>] <run-id> [--failed]
#   ./github-actions.sh cancel     [<owner>/<repo>] <run-id>
#   ./github-actions.sh artifacts  [<owner>/<repo>] <run-id>
#   ./github-actions.sh artifact-download [<owner>/<repo>] <artifact-id> <output.zip>
#   ./github-actions.sh runners    [<owner>/<repo>]
#   ./github-actions.sh cache-usage [<owner>/<repo>]

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {workflows|enable|disable|dispatch|runs|run|jobs|logs|job-logs|rerun|cancel|artifacts|artifact-download|runners|cache-usage} [args...]"

action="$1"; shift

case "$action" in
  workflows)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/actions/workflows" | jq .
    ;;

  enable)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 enable [<owner>/<repo>] <workflow-id-or-filename>"
    github_api PUT "/repos/${repo}/actions/workflows/$(urlencode "$1")/enable"
    printf '\033[32m✓\033[0m workflow %s enabled\n' "$1"
    ;;

  disable)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 disable [<owner>/<repo>] <workflow-id-or-filename>"
    github_api PUT "/repos/${repo}/actions/workflows/$(urlencode "$1")/disable"
    printf '\033[32m✓\033[0m workflow %s disabled\n' "$1"
    ;;

  dispatch)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 dispatch [<owner>/<repo>] <workflow> <ref> [inputs-json]"
    wf="$1"; ref="$2"; inputs="${3:-{\}}"
    body=$(jq -nc --arg ref "$ref" --argjson inputs "$inputs" '{ref:$ref, inputs:$inputs}')
    github_api POST "/repos/${repo}/actions/workflows/$(urlencode "$wf")/dispatches" "$body"
    printf '\033[32m✓\033[0m dispatched %s on ref %s\n' "$wf" "$ref"
    ;;

  runs)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    workflow=""; status=""; limit=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --workflow) workflow="$2"; shift 2 ;;
        --status)   status="$2"; shift 2 ;;
        --limit)    limit="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    qs="per_page=${limit}"
    [[ -n "$status" ]] && qs="${qs}&status=$(urlencode "$status")"
    if [[ -n "$workflow" ]]; then
      github_api GET "/repos/${repo}/actions/workflows/$(urlencode "$workflow")/runs?${qs}" | jq .
    else
      github_api GET "/repos/${repo}/actions/runs?${qs}" | jq .
    fi
    ;;

  run)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 run [<owner>/<repo>] <run-id>"
    github_api GET "/repos/${repo}/actions/runs/$1" | jq .
    ;;

  jobs)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 jobs [<owner>/<repo>] <run-id>"
    github_api GET "/repos/${repo}/actions/runs/$1/jobs?per_page=100" | jq .
    ;;

  logs)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 logs [<owner>/<repo>] <run-id>"
    # Logs are a redirect to a signed URL; -L follows it. Output is a zip - pipe to a file.
    curl -sSL \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
      -H "User-Agent: github-cli-skill" \
      "https://api.github.com/repos/${repo}/actions/runs/$1/logs"
    ;;

  job-logs)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 job-logs [<owner>/<repo>] <job-id>"
    curl -sSL \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
      -H "User-Agent: github-cli-skill" \
      "https://api.github.com/repos/${repo}/actions/jobs/$1/logs"
    ;;

  rerun)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 rerun [<owner>/<repo>] <run-id> [--failed]"
    rid="$1"; shift
    suffix=""
    [[ "${1:-}" == "--failed" ]] && suffix="-failed-jobs"
    github_api POST "/repos/${repo}/actions/runs/${rid}/rerun${suffix}"
    printf '\033[32m✓\033[0m run %s rerun triggered (%s)\n' "$rid" "${suffix:-all jobs}"
    ;;

  cancel)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 cancel [<owner>/<repo>] <run-id>"
    github_api POST "/repos/${repo}/actions/runs/$1/cancel"
    printf '\033[32m✓\033[0m run %s canceled\n' "$1"
    ;;

  artifacts)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 artifacts [<owner>/<repo>] <run-id>"
    github_api GET "/repos/${repo}/actions/runs/$1/artifacts" | jq .
    ;;

  artifact-download)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 2 ]] || err "usage: $0 artifact-download [<owner>/<repo>] <artifact-id> <output.zip>"
    aid="$1"; out="$2"
    curl -sSL -o "$out" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $GITHUB_API_VERSION" \
      -H "User-Agent: github-cli-skill" \
      "https://api.github.com/repos/${repo}/actions/artifacts/${aid}/zip"
    printf '\033[32m✓\033[0m artifact saved to %s\n' "$out"
    ;;

  runners)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/actions/runners" | jq .
    ;;

  cache-usage)
    repo=$(resolve_repo "${1:-}")
    github_api GET "/repos/${repo}/actions/cache/usage" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
