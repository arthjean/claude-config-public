#!/usr/bin/env bash
# github-projects.sh - Projects v2 (the new GraphQL-backed boards).
# Replaces MCP tools: projects_list, projects_get, projects_write.
# All operations use GraphQL since Projects v2 has no REST surface.
#
# Usage:
#   ./github-projects.sh ls         <owner>                         # list user/org projects
#   ./github-projects.sh get        <owner> <project-number>
#   ./github-projects.sh fields     <owner> <project-number>
#   ./github-projects.sh items      <owner> <project-number> [--limit 100]
#   ./github-projects.sh status-updates <owner> <project-number>
#   ./github-projects.sh add-item   <owner> <project-number> <issue-or-pr-node-id>
#   ./github-projects.sh rm-item    <project-id> <item-id>
#   ./github-projects.sh set-field-text <project-id> <item-id> <field-id> "<value>"
#   ./github-projects.sh set-field-single-select <project-id> <item-id> <field-id> <option-id>
#   ./github-projects.sh set-field-number <project-id> <item-id> <field-id> <number>
#   ./github-projects.sh set-field-date <project-id> <item-id> <field-id> <YYYY-MM-DD>
#   ./github-projects.sh status-update <project-id> <body-text> [--state ON_TRACK|AT_RISK|OFF_TRACK]
#
# Note: project-id and item-id are GraphQL node IDs (e.g., "PVT_kwDO..."), NOT the integer
# project number from the URL. The 'get' command surfaces both. 'add-item' takes an issue or
# PR's node_id (visible via `github-issues.sh get` → '.node_id').

source "$(dirname "$0")/_lib.sh"
require_github_token

[[ $# -ge 1 ]] || err "usage: $0 {ls|get|fields|items|status-updates|add-item|rm-item|set-field-text|set-field-single-select|set-field-number|set-field-date|status-update} [args...]"

action="$1"; shift

# Resolve <owner> to either user or organization for projectsV2.
_owner_projects_query() {
  local owner="$1" limit="${2:-50}"
  local q='query($login:String!,$first:Int!){
    user(login:$login){projectsV2(first:$first){nodes{id number title closed url}}}
    organization(login:$login){projectsV2(first:$first){nodes{id number title closed url}}}
  }'
  github_graphql "$q" "login=${owner}" "first=${limit}"
}

case "$action" in
  ls)
    [[ $# -ge 1 ]] || err "usage: $0 ls <owner>"
    _owner_projects_query "$1" 100 \
      | jq '{user: .data.user.projectsV2.nodes, org: .data.organization.projectsV2.nodes}'
    ;;

  get)
    [[ $# -ge 2 ]] || err "usage: $0 get <owner> <project-number>"
    q='query($login:String!,$num:Int!){
      organization(login:$login){projectV2(number:$num){id number title closed url shortDescription
        readme fields(first:50){nodes{... on ProjectV2FieldCommon{id name dataType}}}}}
      user(login:$login){projectV2(number:$num){id number title closed url shortDescription
        readme fields(first:50){nodes{... on ProjectV2FieldCommon{id name dataType}}}}}
    }'
    github_graphql "$q" "login=$1" "num=$2" | jq .
    ;;

  fields)
    [[ $# -ge 2 ]] || err "usage: $0 fields <owner> <project-number>"
    q='query($login:String!,$num:Int!){
      organization(login:$login){projectV2(number:$num){fields(first:50){nodes{
        ... on ProjectV2FieldCommon{id name dataType}
        ... on ProjectV2SingleSelectField{id name options{id name}}
      }}}}
      user(login:$login){projectV2(number:$num){fields(first:50){nodes{
        ... on ProjectV2FieldCommon{id name dataType}
        ... on ProjectV2SingleSelectField{id name options{id name}}
      }}}}
    }'
    github_graphql "$q" "login=$1" "num=$2" | jq .
    ;;

  items)
    [[ $# -ge 2 ]] || err "usage: $0 items <owner> <project-number> [--limit 100]"
    owner="$1"; num="$2"; shift 2
    limit=100
    [[ "${1:-}" == "--limit" ]] && { limit="$2"; shift 2; }
    q='query($login:String!,$num:Int!,$first:Int!){
      organization(login:$login){projectV2(number:$num){items(first:$first){nodes{
        id type content{
          ... on Issue{number title url state}
          ... on PullRequest{number title url state}
          ... on DraftIssue{title body}
        }
        fieldValues(first:20){nodes{
          ... on ProjectV2ItemFieldTextValue{text field{... on ProjectV2FieldCommon{name}}}
          ... on ProjectV2ItemFieldSingleSelectValue{name field{... on ProjectV2FieldCommon{name}}}
          ... on ProjectV2ItemFieldNumberValue{number field{... on ProjectV2FieldCommon{name}}}
          ... on ProjectV2ItemFieldDateValue{date field{... on ProjectV2FieldCommon{name}}}
        }}
      }}}}
    }'
    github_graphql "$q" "login=${owner}" "num=${num}" "first=${limit}" | jq .
    ;;

  status-updates)
    [[ $# -ge 2 ]] || err "usage: $0 status-updates <owner> <project-number>"
    q='query($login:String!,$num:Int!){
      organization(login:$login){projectV2(number:$num){statusUpdates(first:20){nodes{
        id body status startDate targetDate createdAt creator{login}
      }}}}
    }'
    github_graphql "$q" "login=$1" "num=$2" | jq .
    ;;

  add-item)
    [[ $# -ge 3 ]] || err "usage: $0 add-item <project-id> <content-node-id> (project-id is GraphQL node id PVT_...)"
    # Args: project-id (GraphQL node), content-id (issue or PR node)
    q='mutation($pid:ID!,$cid:ID!){addProjectV2ItemById(input:{projectId:$pid,contentId:$cid}){item{id}}}'
    github_graphql "$q" "pid=$1" "cid=$2" | jq .
    ;;

  rm-item)
    [[ $# -ge 2 ]] || err "usage: $0 rm-item <project-id> <item-id>"
    q='mutation($pid:ID!,$iid:ID!){deleteProjectV2Item(input:{projectId:$pid,itemId:$iid}){deletedItemId}}'
    github_graphql "$q" "pid=$1" "iid=$2" | jq .
    ;;

  set-field-text)
    [[ $# -ge 4 ]] || err "usage: $0 set-field-text <project-id> <item-id> <field-id> \"<value>\""
    q='mutation($pid:ID!,$iid:ID!,$fid:ID!,$v:String!){
      updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{text:$v}}){projectV2Item{id}}
    }'
    github_graphql "$q" "pid=$1" "iid=$2" "fid=$3" "v=$4" | jq .
    ;;

  set-field-single-select)
    [[ $# -ge 4 ]] || err "usage: $0 set-field-single-select <project-id> <item-id> <field-id> <option-id>"
    q='mutation($pid:ID!,$iid:ID!,$fid:ID!,$o:String!){
      updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{singleSelectOptionId:$o}}){projectV2Item{id}}
    }'
    github_graphql "$q" "pid=$1" "iid=$2" "fid=$3" "o=$4" | jq .
    ;;

  set-field-number)
    [[ $# -ge 4 ]] || err "usage: $0 set-field-number <project-id> <item-id> <field-id> <number>"
    q='mutation($pid:ID!,$iid:ID!,$fid:ID!,$n:Float!){
      updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{number:$n}}){projectV2Item{id}}
    }'
    # GraphQL helper passes everything as String; need raw JSON body for this case.
    body=$(jq -nc --arg q "$q" --arg pid "$1" --arg iid "$2" --arg fid "$3" --argjson n "$4" \
      '{query:$q, variables:{pid:$pid, iid:$iid, fid:$fid, n:$n}}')
    github_api POST "/graphql" "$body" | jq .
    ;;

  set-field-date)
    [[ $# -ge 4 ]] || err "usage: $0 set-field-date <project-id> <item-id> <field-id> <YYYY-MM-DD>"
    q='mutation($pid:ID!,$iid:ID!,$fid:ID!,$d:Date!){
      updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{date:$d}}){projectV2Item{id}}
    }'
    github_graphql "$q" "pid=$1" "iid=$2" "fid=$3" "d=$4" | jq .
    ;;

  status-update)
    [[ $# -ge 2 ]] || err "usage: $0 status-update <project-id> <body-text> [--state ON_TRACK|AT_RISK|OFF_TRACK]"
    pid="$1"; body_text="$2"; shift 2
    state="ON_TRACK"
    [[ "${1:-}" == "--state" ]] && { state="$2"; shift 2; }
    # The mutation field name is createProjectV2StatusUpdate.
    q='mutation($pid:ID!,$body:String!,$st:ProjectV2StatusUpdateStatus!){
      createProjectV2StatusUpdate(input:{projectId:$pid,body:$body,status:$st}){statusUpdate{id}}
    }'
    body=$(jq -nc --arg q "$q" --arg pid "$pid" --arg body "$body_text" --arg st "$state" \
      '{query:$q, variables:{pid:$pid, body:$body, st:$st}}')
    github_api POST "/graphql" "$body" | jq .
    ;;

  *)
    err "unknown action: $action"
    ;;
esac
