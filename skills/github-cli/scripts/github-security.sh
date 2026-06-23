#!/usr/bin/env bash
# github-security.sh - security alerts (Dependabot, code scanning, secret scanning, advisories).
# Replaces MCP tools: get/list_code_scanning_alert, get/list_secret_scanning_alert,
#                     get/list_dependabot_alert, get/list_global_security_advisory,
#                     list_org_repository_security_advisories, list_repository_security_advisories.
#
# Usage:
#   ./github-security.sh dependabot    [<owner>/<repo>] [--state open|fixed|dismissed|auto_dismissed] [--severity critical|high|medium|low]
#   ./github-security.sh dependabot-get  [<owner>/<repo>] <alert-number>
#   ./github-security.sh code-scan     [<owner>/<repo>] [--state open|closed|dismissed|fixed] [--severity X]
#   ./github-security.sh code-scan-get [<owner>/<repo>] <alert-number>
#   ./github-security.sh secret-scan   [<owner>/<repo>] [--state open|resolved]
#   ./github-security.sh secret-scan-get [<owner>/<repo>] <alert-number>
#   ./github-security.sh advisories    [<owner>/<repo>]                         # repo-level advisories
#   ./github-security.sh org-advisories <org>                                   # all advisories for an org's repos
#   ./github-security.sh ghsa-list     [--ecosystem npm|pip|...] [--severity high] [--limit 30]
#   ./github-security.sh ghsa-get      <ghsa-id>                                 # e.g. GHSA-vqq6-5vp4-jq6r
#   ./github-security.sh dismiss-dependabot [<owner>/<repo>] <alert-number> [--reason fix_started|inaccurate|no_bandwidth|not_used|tolerable_risk] [--comment "…"]

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {dependabot|dependabot-get|code-scan|code-scan-get|secret-scan|secret-scan-get|advisories|org-advisories|ghsa-list|ghsa-get|dismiss-dependabot} [args...]"

action="$1"; shift

# Common state/severity flag parser → query string.
_alerts_qs() {
  local qs="per_page=100"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state)    qs="${qs}&state=$(urlencode "$2")"; shift 2 ;;
      --severity) qs="${qs}&severity=$(urlencode "$2")"; shift 2 ;;
      --ecosystem) qs="${qs}&ecosystem=$(urlencode "$2")"; shift 2 ;;
      --limit)    qs="${qs%per_page=100}per_page=$2"; shift 2 ;;
      *) err "unknown flag: $1" ;;
    esac
  done
  printf '%s' "$qs"
}

case "$action" in
  dependabot)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    qs=$(_alerts_qs "$@")
    github_paginate "/repos/${repo}/dependabot/alerts?${qs}" | jq .
    ;;

  dependabot-get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 dependabot-get [<owner>/<repo>] <alert-number>"
    github_api GET "/repos/${repo}/dependabot/alerts/$1" | jq .
    ;;

  code-scan)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    qs=$(_alerts_qs "$@")
    github_paginate "/repos/${repo}/code-scanning/alerts?${qs}" | jq .
    ;;

  code-scan-get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 code-scan-get [<owner>/<repo>] <alert-number>"
    github_api GET "/repos/${repo}/code-scanning/alerts/$1" | jq .
    ;;

  secret-scan)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    qs=$(_alerts_qs "$@")
    github_paginate "/repos/${repo}/secret-scanning/alerts?${qs}" | jq .
    ;;

  secret-scan-get)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 secret-scan-get [<owner>/<repo>] <alert-number>"
    github_api GET "/repos/${repo}/secret-scanning/alerts/$1" | jq .
    ;;

  advisories)
    repo=$(resolve_repo "${1:-}")
    github_paginate "/repos/${repo}/security-advisories?per_page=100" | jq .
    ;;

  org-advisories)
    [[ $# -ge 1 ]] || err "usage: $0 org-advisories <org>"
    github_paginate "/orgs/$1/security-advisories?per_page=100" | jq .
    ;;

  ghsa-list)
    qs=$(_alerts_qs "$@")
    github_paginate "/advisories?${qs}" | jq .
    ;;

  ghsa-get)
    [[ $# -ge 1 ]] || err "usage: $0 ghsa-get <ghsa-id>"
    github_api GET "/advisories/$1" | jq .
    ;;

  dismiss-dependabot)
    repo=$(resolve_repo "${1:-}")
    [[ "${1:-}" == */* ]] && shift
    [[ $# -ge 1 ]] || err "usage: $0 dismiss-dependabot [<owner>/<repo>] <alert-number> [--reason X] [--comment Y]"
    num="$1"; shift
    reason="tolerable_risk"; comment=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --reason)  reason="$2"; shift 2 ;;
        --comment) comment="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc --arg r "$reason" --arg c "$comment" \
      '{state:"dismissed", dismissed_reason:$r}
       + (if $c != "" then {dismissed_comment:$c} else {} end)')
    github_api PATCH "/repos/${repo}/dependabot/alerts/${num}" "$body" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
