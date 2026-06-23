#!/usr/bin/env bash
# github-orgs.sh - organization management.
# MCP gap-filler: the official MCP only exposes search_orgs / get_teams / get_team_members
# - no member admin, no team CRUD. This script provides all of it.
#
# Usage:
#   ./github-orgs.sh get             <org>
#   ./github-orgs.sh ls              [--user <username>]                   # list orgs the user belongs to
#   ./github-orgs.sh members         <org> [--role admin|member] [--limit 100]
#   ./github-orgs.sh add-member      <org> <username> [--role member|admin]
#   ./github-orgs.sh rm-member       <org> <username>
#   ./github-orgs.sh check-member    <org> <username>
#   ./github-orgs.sh outside-collaborators <org>
#   ./github-orgs.sh teams           <org>
#   ./github-orgs.sh team-get        <org> <team-slug>
#   ./github-orgs.sh team-create     <org> <name> [--privacy closed|secret] [--description "…"]
#   ./github-orgs.sh team-rm         <org> <team-slug>
#   ./github-orgs.sh team-members    <org> <team-slug>
#   ./github-orgs.sh team-add        <org> <team-slug> <username> [--role member|maintainer]
#   ./github-orgs.sh team-rm-member  <org> <team-slug> <username>
#   ./github-orgs.sh team-repos      <org> <team-slug>
#   ./github-orgs.sh team-add-repo   <org> <team-slug> <owner>/<repo> [--permission pull|triage|push|maintain|admin]
#   ./github-orgs.sh search          "<query>" [--limit 30]
#   ./github-orgs.sh invitations     <org>                                 # pending invites
#   ./github-orgs.sh invite          <org> <username-or-email> [--role direct_member|admin]

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {get|ls|members|add-member|rm-member|check-member|outside-collaborators|teams|team-get|team-create|team-rm|team-members|team-add|team-rm-member|team-repos|team-add-repo|search|invitations|invite} [args...]"

action="$1"; shift

case "$action" in
  get)
    [[ $# -ge 1 ]] || err "usage: $0 get <org>"
    github_api GET "/orgs/$1" | jq .
    ;;

  ls)
    user=""
    [[ "${1:-}" == "--user" ]] && { user="$2"; shift 2; }
    if [[ -n "$user" ]]; then
      github_api GET "/users/${user}/orgs?per_page=100" | jq .
    else
      github_api GET "/user/orgs?per_page=100" | jq .
    fi
    ;;

  members)
    [[ $# -ge 1 ]] || err "usage: $0 members <org> [--role admin|member] [--limit 100]"
    org="$1"; shift
    role=""; limit=100
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --role)  role="$2"; shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    qs="per_page=${limit}"
    [[ -n "$role" ]] && qs="${qs}&role=$(urlencode "$role")"
    github_api GET "/orgs/${org}/members?${qs}" | jq .
    ;;

  add-member)
    [[ $# -ge 2 ]] || err "usage: $0 add-member <org> <username> [--role member|admin]"
    org="$1"; user="$2"; shift 2
    role="member"
    [[ "${1:-}" == "--role" ]] && { role="$2"; shift 2; }
    body=$(jq -nc --arg r "$role" '{role:$r}')
    github_api PUT "/orgs/${org}/memberships/${user}" "$body" | jq .
    ;;

  rm-member)
    [[ $# -ge 2 ]] || err "usage: $0 rm-member <org> <username>"
    github_api DELETE "/orgs/$1/members/$2"
    printf '\033[32m✓\033[0m removed %s from %s\n' "$2" "$1"
    ;;

  check-member)
    [[ $# -ge 2 ]] || err "usage: $0 check-member <org> <username>"
    if curl -sS -o /dev/null -w '%{http_code}' \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "User-Agent: github-cli-skill" \
        "https://api.github.com/orgs/$1/members/$2" | grep -q '^204$'; then
      printf '\033[32m✓\033[0m %s is a member of %s\n' "$2" "$1"
    else
      printf '\033[33m!\033[0m %s is NOT a member of %s\n' "$2" "$1"
    fi
    ;;

  outside-collaborators)
    [[ $# -ge 1 ]] || err "usage: $0 outside-collaborators <org>"
    github_api GET "/orgs/$1/outside_collaborators?per_page=100" | jq .
    ;;

  teams)
    [[ $# -ge 1 ]] || err "usage: $0 teams <org>"
    github_paginate "/orgs/$1/teams?per_page=100" | jq .
    ;;

  team-get)
    [[ $# -ge 2 ]] || err "usage: $0 team-get <org> <team-slug>"
    github_api GET "/orgs/$1/teams/$2" | jq .
    ;;

  team-create)
    [[ $# -ge 2 ]] || err "usage: $0 team-create <org> <name> [--privacy closed|secret] [--description …]"
    org="$1"; name="$2"; shift 2
    privacy="closed"; desc=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --privacy)     privacy="$2"; shift 2 ;;
        --description) desc="$2"; shift 2 ;;
        *) err "unknown flag: $1" ;;
      esac
    done
    body=$(jq -nc --arg n "$name" --arg p "$privacy" --arg d "$desc" \
      '{name:$n, privacy:$p} + (if $d != "" then {description:$d} else {} end)')
    github_api POST "/orgs/${org}/teams" "$body" | jq .
    ;;

  team-rm)
    [[ $# -ge 2 ]] || err "usage: $0 team-rm <org> <team-slug>"
    github_api DELETE "/orgs/$1/teams/$2"
    printf '\033[32m✓\033[0m team %s/%s deleted\n' "$1" "$2"
    ;;

  team-members)
    [[ $# -ge 2 ]] || err "usage: $0 team-members <org> <team-slug>"
    github_paginate "/orgs/$1/teams/$2/members?per_page=100" | jq .
    ;;

  team-add)
    [[ $# -ge 3 ]] || err "usage: $0 team-add <org> <team-slug> <username> [--role member|maintainer]"
    org="$1"; team="$2"; user="$3"; shift 3
    role="member"
    [[ "${1:-}" == "--role" ]] && { role="$2"; shift 2; }
    body=$(jq -nc --arg r "$role" '{role:$r}')
    github_api PUT "/orgs/${org}/teams/${team}/memberships/${user}" "$body" | jq .
    ;;

  team-rm-member)
    [[ $# -ge 3 ]] || err "usage: $0 team-rm-member <org> <team-slug> <username>"
    github_api DELETE "/orgs/$1/teams/$2/memberships/$3"
    printf '\033[32m✓\033[0m removed %s from team %s/%s\n' "$3" "$1" "$2"
    ;;

  team-repos)
    [[ $# -ge 2 ]] || err "usage: $0 team-repos <org> <team-slug>"
    github_paginate "/orgs/$1/teams/$2/repos?per_page=100" | jq .
    ;;

  team-add-repo)
    [[ $# -ge 3 ]] || err "usage: $0 team-add-repo <org> <team-slug> <owner>/<repo> [--permission pull|triage|push|maintain|admin]"
    org="$1"; team="$2"; repo="$3"; shift 3
    perm="push"
    [[ "${1:-}" == "--permission" ]] && { perm="$2"; shift 2; }
    body=$(jq -nc --arg p "$perm" '{permission:$p}')
    github_api PUT "/orgs/${org}/teams/${team}/repos/${repo}" "$body"
    printf '\033[32m✓\033[0m team %s/%s gets %s on %s\n' "$org" "$team" "$perm" "$repo"
    ;;

  search)
    [[ $# -ge 1 ]] || err "usage: $0 search \"<query>\" [--limit 30]"
    q=$(urlencode "$1 type:org"); shift
    limit=30
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    github_api GET "/search/users?q=${q}&per_page=${limit}" | jq .
    ;;

  invitations)
    [[ $# -ge 1 ]] || err "usage: $0 invitations <org>"
    github_api GET "/orgs/$1/invitations?per_page=100" | jq .
    ;;

  invite)
    [[ $# -ge 2 ]] || err "usage: $0 invite <org> <username-or-email> [--role direct_member|admin]"
    org="$1"; who="$2"; shift 2
    role="direct_member"
    [[ "${1:-}" == "--role" ]] && { role="$2"; shift 2; }
    # Detect email vs username and call the right field.
    if [[ "$who" == *@* ]]; then
      body=$(jq -nc --arg e "$who" --arg r "$role" '{email:$e, role:$r}')
    else
      uid=$(github_api GET "/users/${who}" | jq -r '.id')
      body=$(jq -nc --argjson id "$uid" --arg r "$role" '{invitee_id:$id, role:$r}')
    fi
    github_api POST "/orgs/${org}/invitations" "$body" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
