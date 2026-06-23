# GitHub MCP → github-cli parity table

This skill provides bash equivalents for every tool the official `github/github-mcp-server` exposes (post-October 2025 consolidation: ~84 tool names across 19 toolsets, ~111 sub-operations), **plus** broader REST surface the MCP doesn't expose.

Source for the MCP tool list: https://github.com/github/github-mcp-server (README, main branch).

## How the consolidated MCP tools map

After the October 2025 consolidation, several MCP tools accept a `method` parameter that picks a sub-operation. Below, each row shows the MCP tool, the `method` (if any), and the equivalent `gh` command or script call.

## Default-on toolsets

### `context` + `users`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `get_me` | - | `gh api user` · `scripts/github-api.sh GET /user` |
| `get_teams` | - | `scripts/github-orgs.sh teams <org>` · `gh api orgs/{org}/teams` |
| `get_team_members` | - | `scripts/github-orgs.sh team-members <org> <team-slug>` |
| `search_users` | - | `scripts/github-search.sh users "<query>"` · `gh search users "<q>"` |
| `search_orgs` | - | `scripts/github-orgs.sh search "<query>"` · `gh search users "<q> type:org"` |

### `repos`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `create_repository` | - | `scripts/github-repos.sh create <name> [--private] [--org X]` · `gh repo create` |
| `fork_repository` | - | `scripts/github-repos.sh fork <owner>/<repo> [--org X]` · `gh repo fork` |
| `search_repositories` | - | `scripts/github-search.sh repos "<query>"` · `gh search repos` |
| `get_file_contents` | - | `scripts/github-files.sh get [...] <path>` · `scripts/github-files.sh raw [...] <path>` (decoded) |
| `create_or_update_file` | - | `scripts/github-files.sh put [...] <path> <local-file> "<msg>"` |
| `push_files` | - | `scripts/github-files.sh push [...] <branch> "<msg>" file1 file2 …` (atomic via Git Data API) |
| `delete_file` | - | `scripts/github-files.sh rm [...] <path> "<msg>"` |
| `get_repository_tree` (toolset `git`) | - | `scripts/github-repos.sh tree [...] [<ref>] [--recursive]` |
| `create_branch` | - | `scripts/github-repos.sh branch-create [...] <new> [<from-ref>]` · `gh api repos/.../git/refs --method POST` |
| `list_branches` | - | `scripts/github-repos.sh branches` · `gh api repos/.../branches --paginate` |
| `get_commit` | - | `scripts/github-repos.sh commit [...] <sha>` |
| `list_commits` | - | `scripts/github-repos.sh commits [...] [<ref>] [--limit 30]` |
| `get_tag` | - | `scripts/github-repos.sh tag [...] <tag>` |
| `list_tags` | - | `scripts/github-repos.sh tags` |
| `get_latest_release` | - | `scripts/github-releases.sh latest` |
| `get_release_by_tag` | - | `scripts/github-releases.sh get [...] <tag>` |
| `list_releases` | - | `scripts/github-releases.sh ls [--limit 30]` |
| `search_code` | - | `scripts/github-search.sh code "<query>"` |
| `star_repository` (toolset `stargazers`) | - | `scripts/github-repos.sh star <owner>/<repo>` |
| `unstar_repository` | - | `scripts/github-repos.sh unstar <owner>/<repo>` |
| `list_starred_repositories` | - | `scripts/github-repos.sh starred [--limit 100]` |

### `issues`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `issue_read` | `get` | `scripts/github-issues.sh get [...] <num>` |
| `issue_read` | `get_comments` | `scripts/github-issues.sh comments [...] <num>` |
| `issue_read` | `get_sub_issues` | `scripts/github-issues.sh sub-list [...] <num>` |
| `issue_read` | `get_labels` | `gh api repos/.../issues/{n}/labels` |
| `issue_write` | `create` | `scripts/github-issues.sh create [...] "<title>" "<body>"` |
| `issue_write` | `update` | `scripts/github-issues.sh update [...] <num> <patch-json>` |
| `add_issue_comment` | - | `scripts/github-issues.sh comment [...] <num> "<body>"` |
| `list_issues` | - | `scripts/github-issues.sh ls [...] [--state X] [--label Y]` |
| `search_issues` | - | `scripts/github-issues.sh search "<query>"` |
| `sub_issue_write` | `add` / `remove` / `reprioritize` | `scripts/github-issues.sh sub-add` / `sub-remove` (reprioritize: REST `PATCH /sub_issue` with `position` - use `gh api`) |
| `list_issue_types` | - | `gh api orgs/{org}/issue-types` |
| `assign_copilot_to_issue` (toolset `copilot`) | - | Not exposed; assign via `scripts/github-issues.sh assign [...] <num> copilot-swe-agent` if the bot account is enabled on the repo |

### `labels`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `get_label` | - | `gh api repos/.../labels/<name>` |
| `list_label` | - | `scripts/github-issues.sh labels-ls` |
| `label_write` | `create` / `update` / `delete` | `scripts/github-issues.sh label-create` / `gh label edit` / `scripts/github-issues.sh label-rm` |

### `pull_requests`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `create_pull_request` | - | `scripts/github-prs.sh create [...] "<title>" <head> <base>` |
| `update_pull_request` | - | `scripts/github-prs.sh update [...] <num> <patch-json>` |
| `merge_pull_request` | - | `scripts/github-prs.sh merge [...] <num> --method squash` |
| `list_pull_requests` | - | `scripts/github-prs.sh ls [...] [--state open] [--limit 30]` |
| `search_pull_requests` | - | `scripts/github-prs.sh search "<query>"` · `gh search prs` |
| `update_pull_request_branch` | - | `scripts/github-prs.sh sync-branch [...] <num>` |
| `pull_request_read` | `get` | `scripts/github-prs.sh get [...] <num>` |
| `pull_request_read` | `get_diff` | `scripts/github-prs.sh diff [...] <num>` |
| `pull_request_read` | `get_status` | `scripts/github-prs.sh checks [...] <num>` |
| `pull_request_read` | `get_files` | `scripts/github-prs.sh files [...] <num>` |
| `pull_request_read` | `get_review_comments` | `scripts/github-prs.sh comments [...] <num>` |
| `pull_request_read` | `get_reviews` | `scripts/github-prs.sh reviews [...] <num>` |
| `pull_request_read` | `get_comments` | `scripts/github-prs.sh issue-comments [...] <num>` |
| `pull_request_read` | `get_check_runs` | `scripts/github-prs.sh checks` (returns combined status + check-runs) |
| `pull_request_review_write` | `create` (approve/request-changes/comment) | `scripts/github-prs.sh review [...] <num> approve\|request-changes\|comment "<body>"` |
| `pull_request_review_write` | `submit` (pending → submitted) | `gh api repos/.../pulls/{n}/reviews/{rid}/events --method POST -f event=APPROVE` |
| `pull_request_review_write` | `delete` (a pending review) | `gh api repos/.../pulls/{n}/reviews/{rid} --method DELETE` |
| `pull_request_review_write` | `resolve_thread` / `unresolve_thread` | GraphQL mutations `resolveReviewThread` / `unresolveReviewThread` - see references/rest-api.md |
| `add_comment_to_pending_review` | - | `gh api repos/.../pulls/{n}/comments --method POST` (line-level on a pending review) |
| `add_reply_to_pull_request_comment` | - | `scripts/github-prs.sh review-reply [...] <num> <comment-id> "<body>"` |
| `request_copilot_review` | - | `scripts/github-prs.sh request-copilot [...] <num>` |

### `actions`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `actions_list` | `list_workflows` | `scripts/github-actions.sh workflows` |
| `actions_list` | `list_workflow_runs` | `scripts/github-actions.sh runs [--workflow X] [--status Y]` |
| `actions_get` | `get_workflow_run` | `scripts/github-actions.sh run [...] <id>` |
| `actions_get` | `get_workflow_run_jobs` | `scripts/github-actions.sh jobs [...] <id>` |
| `actions_get` | `get_artifacts` | `scripts/github-actions.sh artifacts [...] <id>` |
| `actions_run_trigger` | `dispatch` | `scripts/github-actions.sh dispatch [...] <wf> <ref> [inputs]` |
| `actions_run_trigger` | `rerun` (all or failed) | `scripts/github-actions.sh rerun [...] <id> [--failed]` |
| `actions_run_trigger` | `cancel` | `scripts/github-actions.sh cancel [...] <id>` |
| `get_job_logs` | - | `scripts/github-actions.sh job-logs [...] <job-id>` (plain text) |

### `notifications`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `list_notifications` | - | `scripts/github-notifications.sh ls [--all] [--participating]` |
| `get_notification_details` | - | `scripts/github-notifications.sh get <thread-id>` |
| `dismiss_notification` | - | `scripts/github-notifications.sh done <thread-id>` |
| `mark_all_notifications_read` | - | `scripts/github-notifications.sh read-all [--repo X]` |
| `manage_notification_subscription` | - | `scripts/github-notifications.sh subscribe\|unsubscribe <thread-id>` |
| `manage_repository_notification_subscription` | - | `scripts/github-notifications.sh repo-watch\|repo-unwatch <owner>/<repo>` |

### `projects`

| MCP tool | Sub-op | github-cli equivalent |
|---|---|---|
| `projects_list` | `list_projects` | `scripts/github-projects.sh ls <owner>` |
| `projects_list` | `list_project_fields` | `scripts/github-projects.sh fields <owner> <num>` |
| `projects_list` | `list_project_items` | `scripts/github-projects.sh items <owner> <num>` |
| `projects_list` | `list_project_status_updates` | `scripts/github-projects.sh status-updates <owner> <num>` |
| `projects_get` | `get_project` | `scripts/github-projects.sh get <owner> <num>` |
| `projects_get` | `get_project_field` | `gh api graphql -f query='query{node(id:$fieldId){...}}'` |
| `projects_get` | `get_project_item` | `gh api graphql -f query='query{node(id:$itemId){...}}'` |
| `projects_get` | `get_project_status_update` | `gh api graphql -f query='query{node(id:$updateId){...}}'` |
| `projects_write` | `add_project_item` | `scripts/github-projects.sh add-item <project-id> <content-id>` |
| `projects_write` | `update_project_item` | `scripts/github-projects.sh set-field-text\|set-field-single-select\|set-field-number\|set-field-date` |
| `projects_write` | `delete_project_item` | `scripts/github-projects.sh rm-item <project-id> <item-id>` |
| `projects_write` | `create_project_status_update` | `scripts/github-projects.sh status-update <project-id> "<body>" --state ON_TRACK` |

### `discussions` (read-only in MCP)

| MCP tool | github-cli equivalent |
|---|---|
| `list_discussions` | `gh api graphql -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){discussions(first:30){nodes{id title}}}}' -f o=… -f r=…` |
| `get_discussion` | `gh api graphql -f query='query($id:ID!){node(id:$id){... on Discussion{title body comments(first:30){nodes{body}}}}}'` |
| `get_discussion_comments` | same as above |
| `list_discussion_categories` | `gh api graphql -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){discussionCategories(first:20){nodes{id name}}}}'` |

**MCP gap → covered here**: `create_discussion`, `add_discussion_comment` are not in the MCP. Use the `createDiscussion` and `addDiscussionComment` GraphQL mutations via `gh api graphql`.

### `gists`

| MCP tool | github-cli equivalent |
|---|---|
| `create_gist` | `scripts/github-gists.sh create <file>` (single) · `create-multi "desc" f1 f2` (multi) |
| `get_gist` | `scripts/github-gists.sh get <id>` |
| `list_gists` | `scripts/github-gists.sh ls [--user X]` |
| `update_gist` | `scripts/github-gists.sh update <id> <file>` · `patch <id> <json>` |

### Security toolsets (`code_security`, `secret_protection`, `dependabot`, `security_advisories`)

| MCP tool | github-cli equivalent |
|---|---|
| `get_code_scanning_alert` | `scripts/github-security.sh code-scan-get [...] <num>` |
| `list_code_scanning_alerts` | `scripts/github-security.sh code-scan [...] [--state X] [--severity Y]` |
| `get_secret_scanning_alert` | `scripts/github-security.sh secret-scan-get [...] <num>` |
| `list_secret_scanning_alerts` | `scripts/github-security.sh secret-scan [...]` |
| `get_dependabot_alert` | `scripts/github-security.sh dependabot-get [...] <num>` |
| `list_dependabot_alerts` | `scripts/github-security.sh dependabot [...]` |
| `get_global_security_advisory` | `scripts/github-security.sh ghsa-get GHSA-…` |
| `list_global_security_advisories` | `scripts/github-security.sh ghsa-list [--ecosystem X] [--severity Y]` |
| `list_org_repository_security_advisories` | `scripts/github-security.sh org-advisories <org>` |
| `list_repository_security_advisories` | `scripts/github-security.sh advisories` |

## Remote-only MCP tools (api.githubcopilot.com/mcp/)

These are not in the local Go MCP server - they're Copilot-bound and have no `gh` equivalent:

| MCP tool | Status |
|---|---|
| `create_pull_request_with_copilot` | Copilot Coding Agent feature; not replicable from `gh`. Use the GitHub UI or call the same internal API the remote MCP wraps (undocumented). |
| `get_copilot_space` / `list_copilot_spaces` | Copilot Spaces - UI-only feature, no public API. |
| `github_support_docs_search` | Documentation Q&A. The skill provides `scripts/github-search.sh code` for code search; for docs use a generic web search (or Anthropic's docs MCP). |

## github-cli adds beyond MCP parity

These are MCP gaps that the skill fills:

| Operation | Script |
|---|---|
| `delete_repository` | `scripts/github-repos.sh rm [...]` (intentionally absent from MCP for safety) |
| `archive` / `unarchive` repo | `scripts/github-repos.sh archive` / `unarchive` |
| Repo transfer | `scripts/github-repos.sh transfer [...] <new-owner>` |
| Repo topics get/set | `scripts/github-repos.sh topics [...] [tag1,tag2,…]` |
| Repo traffic stats (views/clones/referrers/paths) | `scripts/github-repos.sh traffic [...]` |
| Multi-file atomic commit (push_files exists in MCP, this is the bash equivalent) | `scripts/github-files.sh push` |
| Issue lock/unlock | `scripts/github-issues.sh lock\|unlock` |
| Issue assignees add/remove | `scripts/github-issues.sh assign\|unassign` |
| PR ready/draft toggle (GraphQL mutations) | `scripts/github-prs.sh ready\|draft` |
| Workflow enable/disable | `scripts/github-actions.sh enable\|disable` |
| Workflow logs (zip of all jobs) | `scripts/github-actions.sh logs` |
| Artifact zip download | `scripts/github-actions.sh artifact-download` |
| Self-hosted runner inventory | `scripts/github-actions.sh runners` |
| Actions cache usage | `scripts/github-actions.sh cache-usage` |
| **Releases create / update / delete** | `scripts/github-releases.sh create\|update\|rm` |
| Release notes auto-generation | `scripts/github-releases.sh generate-notes` |
| Release asset upload / download | `scripts/github-releases.sh upload\|download` |
| **Secrets / variables CRUD (Actions, Codespaces, Dependabot)** | `scripts/github-secrets.sh ls\|set\|rm\|vars-ls\|var-set\|var-rm` |
| **Org member admin** | `scripts/github-orgs.sh add-member\|rm-member\|check-member\|invite` |
| Outside collaborators | `scripts/github-orgs.sh outside-collaborators` |
| Team CRUD + repo grants | `scripts/github-orgs.sh team-create\|team-rm\|team-add\|team-add-repo` |
| Org pending invitations | `scripts/github-orgs.sh invitations` |
| Discussion *create* / *add comment* | GraphQL `createDiscussion` / `addDiscussionComment` (see references/rest-api.md) |
| Repo / org webhook CRUD | `scripts/github-webhooks.sh ls\|create\|update\|rm\|test\|deliveries\|redeliver\|org-*` |
| Branch protection rulesets | `scripts/github-webhooks.sh rulesets\|ruleset-get\|ruleset-rm` |
| Deploy keys CRUD | `scripts/github-webhooks.sh deploy-keys\|deploy-key-add\|deploy-key-rm` |
| Gist delete / fork / star | `scripts/github-gists.sh rm\|fork\|star\|unstar` |
| Search topics & commits | `scripts/github-search.sh topics\|commits` |

## Latency comparison

|  | Local MCP (Go) | Remote MCP (OAuth) | github-cli |
|---|---|---|---|
| Cold start | ~80 ms (process spawn) | ~150 ms (HTTP + auth) | ~20 ms (`bash` startup) |
| Warm call (REST) | ~30 ms (JSON-RPC) | ~120 ms (HTTP roundtrip ×2) | ~70 ms (raw `curl`) |
| Multi-call workflow | Fastest (single process) | Slowest (per-call overhead) | Linear (one curl per call) |

For interactive use (1-3 calls), `gh` and the bash wrappers feel snappier because there's no daemon to keep alive. For batch-heavy workflows (>50 calls in a row), the local MCP wins on raw throughput - but you can mitigate that with `github_paginate` + `--paginate` to collapse N pagination calls into one.

## Auth comparison

|  | Local MCP | Remote MCP | github-cli |
|---|---|---|---|
| Auth source | `GITHUB_PERSONAL_ACCESS_TOKEN` env | OAuth (browser flow) | `GITHUB_TOKEN` env or `gh auth login` keyring |
| GHES support | Yes (`GITHUB_HOST`) | No (cloud-only by default) | Yes (point `GITHUB_API_BASE` to `https://ghes.example.com/api/v3`) |
| Multi-account | One token per process | One OAuth identity per host | `cd` into a project → auto-loads its `.env.local` |
| Scopes visibility | Hidden | Hidden | `scripts/github-ensure.sh` prints `x-oauth-scopes` |
