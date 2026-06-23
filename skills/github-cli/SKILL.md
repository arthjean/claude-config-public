---
model: opus
name: github-cli
description: "Manage every GitHub resource - repositories, files, issues, pull requests, reviews, Actions/workflows, releases, gists, secrets, variables, organizations, teams, Projects v2, notifications, security alerts (Dependabot/code scanning/secret scanning), webhooks, deploy keys, branch rulesets, traffic stats - from bash via the official `gh` CLI plus direct REST and GraphQL calls against api.github.com, replacing the GitHub MCP server. Covers all ~84 tools the official github-mcp-server exposes (post-October 2025 consolidation) plus broader REST surface the MCP doesn't expose: delete_repository, release create/update/upload/download, secrets/variables CRUD, org member admin, webhooks, branch protection rulesets, deploy keys, traffic. Authenticates with a single GITHUB_TOKEN (or GH_TOKEN alias, or falls back to 'gh auth token' from the keyring) - no OAuth dance, no separate MCP process. Use when the user asks to list/create/edit/delete repos, branches, issues, PRs, releases, gists, workflows, secrets, organizations, teams, projects, or webhooks; query Dependabot/code-scanning/secret-scanning alerts; trigger or rerun GitHub Actions; download workflow logs or artifacts; manage notifications; or says 'github-cli', 'gh CLI', 'manage my GitHub repos', 'list my pull requests', 'GitHub REST API', 'GitHub GraphQL'. Do NOT use when the user wants to write application code that integrates with the GitHub API at runtime (use Octokit / @octokit/rest / @octokit/graphql in code instead) or to manage the GitHub MCP server itself."
argument-hint: "[command or natural-language request]"
---

# github-cli - GitHub via bash, no MCP

Replace the official `github/github-mcp-server` (and the Anthropic remote MCP at `api.githubcopilot.com/mcp/`) with the official `gh` CLI plus a few `curl`-backed bash helpers for the REST/GraphQL gaps. Everything runs in your shell with a single `GITHUB_TOKEN`.

## Why this exists

The official **`github/github-mcp-server`** (Go, ~84 tools post-October 2025 consolidation) is solid for the read-heavy default toolsets but has known gaps:

- No `delete_repository` (intentional safety guard, but blocking for cleanup workflows)
- No release write operations - `get_latest_release` / `list_releases` exist, but `create_release`, `update_release`, `upload_asset` do not
- No secrets or variables management (Actions, Codespaces, Dependabot)
- Discussions are read-only - no `create_discussion`, no `add_discussion_comment`
- No org member admin - `search_orgs` exists but `list_org_members`, `add/remove_member`, `set_role` don't
- No webhook management, branch protection rulesets, deploy keys, or traffic stats
- Step-level workflow logs only (job-level via `get_job_logs`); artifact metadata only (no zip download)
- Pagination cap of 100 results; no `--paginate` equivalent
- Remote MCP requires OAuth; local MCP requires a separate Go process to spawn and supervise

The **`gh` CLI** ships first-class commands for ~80% of common workflows and a `gh api` escape hatch that hits any REST or GraphQL endpoint with the active credential. This skill wraps both into bash helpers that are git-greppable, low-latency (no JSON-RPC roundtrip), and fully covered by a single PAT.

## Hard prerequisites

Before any command in this skill works, verify:

1. **`bunx`** - comes with bun. The user's global rule mandates bun, never npm/npx. The skill itself doesn't require bun (it shells out to `gh` and `curl`), but the broader workflow does.
2. **`gh`** - official GitHub CLI. Install it with your OS package manager. Used directly for some commands (`gh secret set` because libsodium encryption is a pain in pure bash) and indirectly as a token source via `gh auth token`.
3. **`curl`** - install it with your OS package manager if it is not already available. Used for direct REST/GraphQL calls.
4. **`jq`** - for JSON parsing. `sudo dnf install jq` if missing.
5. **`git`** - used by `resolve_repo()` to detect the active `<owner>/<repo>` from the current directory's `origin` remote.
6. **`GITHUB_TOKEN`** - auto-loaded from the project's `.env.local` (then `.env`) walking up from cwd to the git repo root, or pulled from the shell environment if exported, or borrowed from the `gh` keyring as a last resort. Generate at https://github.com/settings/tokens (classic) or .../tokens?type=beta (fine-grained). Recommended scopes for full coverage:
   - **classic**: `repo, workflow, admin:org, gist, project, user, notifications, delete_repo, admin:public_key`
   - **fine-grained**: per-repo permissions for Contents, Issues, Pull requests, Actions, Workflows, Secrets, Environments, Pages, Webhooks, Administration, plus org-level for Members and Projects (note: Projects v2 has incomplete fine-grained coverage - use classic for org Projects)
7. **(Optional) `GITHUB_API_VERSION`** - default `2022-11-28`. Only override if GitHub publishes a newer stable version and you want to opt in.

Run `scripts/github-ensure.sh` to verify all of the above at once, including a live auth call to `GET /user`, your active scopes, and your current rate-limit budget.

## Invocation patterns (always use one of these)

**Official CLI** - easiest for typed read paths:
```bash
gh repo view cli/cli --json name,url,description
gh pr list --state open --json number,title,state
gh api repos/cli/cli/issues --paginate --jq '.[].title'
```

**Generic REST/GraphQL wrapper** - better for scripts (returns clean JSON, retries on rate limit):
```bash
scripts/github-api.sh GET    /user
scripts/github-api.sh GET    "/repos/cli/cli/issues?state=open&per_page=100" --paginate
scripts/github-api.sh POST   /repos/cli/cli/issues '{"title":"Bug","body":"…"}'
scripts/github-api.sh PATCH  /repos/cli/cli/issues/42 '{"state":"closed"}'
scripts/github-api.sh DELETE /repos/cli/cli/labels/wontfix
scripts/github-api.sh graphql 'query{viewer{login}}'
scripts/github-api.sh graphql 'query($login:String!){user(login:$login){id}}' login=octocat
```

**Resource-specific helpers** - best for repeatable workflows (subcommand pattern):
```bash
scripts/github-repos.sh ls --owner cli --limit 50
scripts/github-issues.sh create cli/cli "Bug" "Steps…" --label bug --assignee octocat
scripts/github-prs.sh review cli/cli 123 approve "LGTM"
scripts/github-actions.sh dispatch cli/cli ci.yml main '{"env":"prod"}'
scripts/github-releases.sh create cli/cli v1.2.3 --notes "changelog" --target main
scripts/github-secrets.sh set cli/cli MY_SECRET "value" --scope repo
```

Most resource scripts auto-resolve `<owner>/<repo>` from the current directory's git remote, so inside a repo you can omit it: `scripts/github-issues.sh ls --state open` works.

## Multi-account / multi-org context

GitHub PATs can be account-wide or per-repo (fine-grained). The skill solves multi-instance the same way `clerk-cli` does: auto-load `GITHUB_TOKEN` from the project's own `.env.local` / `.env`, so just `cd` into a project and the right token is active.

**Resolution order** (highest precedence first):

1. **`GITHUB_TOKEN` already exported** in your shell - wins, useful for CI or one-shot overrides.
2. **`GH_TOKEN` already exported** - alias, mirrored to `GITHUB_TOKEN`.
3. **`.env.local`** in cwd, walking up parents until a git repo root (`.git`) or `$HOME`.
4. **`.env`** in the same walk.
5. **`gh auth token`** - borrowed from the `gh` CLI's keyring if you ran `gh auth login` once.
6. Fail with a clear message.

Same walk applies to `GITHUB_API_VERSION`. Only the `GITHUB_TOKEN`, `GH_TOKEN`, and `GITHUB_API_VERSION` keys are extracted - the rest of the file is ignored, never sourced.

```bash
# Working on a project - its .env.local has a fine-grained PAT for that repo
cd ~/code/myapp-a
scripts/github-prs.sh ls           # uses myapp-a's token automatically

# Different account
cd ~/code/myapp-b
scripts/github-prs.sh ls           # uses myapp-b's token

# Override for a single call (e.g. talk to a third repo from any cwd)
GITHUB_TOKEN=ghp_other scripts/github-repos.sh get owner/other-repo

# Bootstrap a new project - pick whichever fits
gh auth login                                    # writes to keyring; auto-picked up
echo "GITHUB_TOKEN=ghp_xxx" >> .env.local        # per-project, never committed
scripts/github-ensure.sh                         # confirms which one was loaded
```

`scripts/github-ensure.sh` reports the source (`shell environment`, `gh auth token (keyring)`, or an absolute `.env.local` path) so you can confirm which identity you're about to operate as.

Helpers in `scripts/` never persist, cache, or write the token anywhere - they read it once per invocation.

## Quick map - "I want to..." → command

### Repos & files
| Intent | Command |
|---|---|
| Verify auth + show identity + scopes + rate limit | `scripts/github-ensure.sh` |
| List my repos (or org's) | `scripts/github-repos.sh ls [--owner <org>] [--limit 50]` |
| Get a single repo | `scripts/github-repos.sh get [<owner>/<repo>]` |
| Create a repo | `scripts/github-repos.sh create my-repo --private --description "…"` |
| Fork a repo | `scripts/github-repos.sh fork cli/cli` |
| Edit repo settings (raw patch) | `scripts/github-repos.sh edit owner/repo '{"description":"new","has_issues":false}'` |
| Archive / unarchive a repo | `scripts/github-repos.sh archive`/`unarchive [<owner>/<repo>]` |
| Delete a repo (irreversible - confirms) | `scripts/github-repos.sh rm [<owner>/<repo>]` |
| Transfer a repo | `scripts/github-repos.sh transfer [<owner>/<repo>] <new-owner>` |
| Search repos | `scripts/github-repos.sh search "topic:rust stars:>1000" --limit 20` |
| Browse a repo's tree | `scripts/github-repos.sh tree [<owner>/<repo>] [<ref>] [--recursive]` |
| List branches / create a branch | `scripts/github-repos.sh branches`, `branch-create [...] new-branch [from-ref]` |
| Get / list commits / get a tag | `scripts/github-repos.sh commit [...] <sha>`, `commits`, `tag`, `tags` |
| Read or set repo topics | `scripts/github-repos.sh topics [...] [tag1,tag2,tag3]` |
| Star / unstar / list starred | `scripts/github-repos.sh star`, `unstar`, `starred` |
| Repo traffic (views/clones/referrers) | `scripts/github-repos.sh traffic [<owner>/<repo>]` |
| Get a single file's contents (decoded) | `scripts/github-files.sh raw [<owner>/<repo>] <path> [--ref <branch>]` |
| Create / update a single file | `scripts/github-files.sh put [...] path/file.md ./local "msg" [--branch main]` |
| Delete a file | `scripts/github-files.sh rm [...] path/file.md "msg" [--branch main]` |
| Push multiple files in one commit | `scripts/github-files.sh push [...] <branch> "msg" file1 file2 …` |

### Issues
| Intent | Command |
|---|---|
| List issues (excludes PRs) | `scripts/github-issues.sh ls [...] [--state open\|closed\|all] [--label X]` |
| Get / create / update an issue | `scripts/github-issues.sh get`, `create "<title>" "<body>"`, `update <num> <patch-json>` |
| Comment on an issue | `scripts/github-issues.sh comment [...] <num> "<body>"` |
| Close / reopen / lock / unlock | `scripts/github-issues.sh close [--reason completed\|not_planned]`, `reopen`, `lock`, `unlock` |
| Add / remove / set labels | `scripts/github-issues.sh label [...] <num> add\|remove\|set <label>...` |
| Assign / unassign | `scripts/github-issues.sh assign [...] <num> <user>...` |
| Search issues | `scripts/github-issues.sh search "is:open label:bug repo:cli/cli"` |
| Sub-issues (parent/child) | `scripts/github-issues.sh sub-add\|sub-remove\|sub-list` |
| Repo labels CRUD | `scripts/github-issues.sh labels-ls`, `label-create`, `label-rm` |

### Pull requests
| Intent | Command |
|---|---|
| List / get / diff / files / checks | `scripts/github-prs.sh ls\|get\|diff\|files\|checks [...] <num>` |
| Create / update / merge | `scripts/github-prs.sh create [...] "<title>" <head> <base>`, `merge [...] <num> --method squash` |
| Convert draft ↔ ready | `scripts/github-prs.sh ready`, `draft` |
| Sync PR branch from base | `scripts/github-prs.sh sync-branch [...] <num>` |
| Comment / review / line-comment | `scripts/github-prs.sh comment`, `review approve\|request-changes\|comment`, `review-line` |
| Reply to a review thread | `scripts/github-prs.sh review-reply [...] <num> <comment-id> "<body>"` |
| Request review (or Copilot) | `scripts/github-prs.sh request-review [...] <num> <user>...`, `request-copilot` |
| Search PRs | `scripts/github-prs.sh search "is:open review-requested:@me"` |

### Actions / workflows
| Intent | Command |
|---|---|
| List workflows / runs | `scripts/github-actions.sh workflows`, `runs [--workflow X] [--status queued\|in_progress\|completed]` |
| Trigger a workflow | `scripts/github-actions.sh dispatch [...] <workflow> <ref> [inputs-json]` |
| Get run / jobs / logs / artifacts | `scripts/github-actions.sh run\|jobs\|logs\|artifacts [...] <run-id>` |
| Plain-text job log | `scripts/github-actions.sh job-logs [...] <job-id>` |
| Download an artifact zip | `scripts/github-actions.sh artifact-download [...] <artifact-id> out.zip` |
| Rerun (all or failed only) | `scripts/github-actions.sh rerun [...] <run-id> [--failed]` |
| Cancel a run | `scripts/github-actions.sh cancel [...] <run-id>` |
| Enable / disable a workflow | `scripts/github-actions.sh enable\|disable [...] <workflow>` |
| Self-hosted runners / cache usage | `scripts/github-actions.sh runners`, `cache-usage` |

### Releases (full CRUD - fills MCP gap)
| Intent | Command |
|---|---|
| List / latest / get | `scripts/github-releases.sh ls`, `latest`, `get [...] <id-or-tag>` |
| Create with autogen notes | `scripts/github-releases.sh create [...] v1.2.3 --notes "…" [--draft] [--prerelease]` |
| Generate release notes only | `scripts/github-releases.sh generate-notes [...] v1.2.3 [v1.2.2]` |
| Update / delete | `scripts/github-releases.sh update [...] <id> <patch-json>`, `rm [...] <id>` |
| Upload / download / list assets | `scripts/github-releases.sh upload [...] <id> dist.tar.gz`, `download`, `assets` |

### Secrets & variables (fills MCP gap)
| Intent | Command |
|---|---|
| List secrets (repo / env / org) | `scripts/github-secrets.sh ls [...] [--scope repo\|env\|org] [--env name]` |
| Set a secret (uses gh for libsodium) | `scripts/github-secrets.sh set [...] NAME value [--scope ...]` |
| Delete a secret | `scripts/github-secrets.sh rm [...] NAME [--scope ...]` |
| Same for plain variables | `scripts/github-secrets.sh vars-ls`, `var-set`, `var-rm` |

### Organizations & teams (fills MCP gap)
| Intent | Command |
|---|---|
| Get an org / list my orgs | `scripts/github-orgs.sh get <org>`, `ls [--user X]` |
| List members [filtered by role] | `scripts/github-orgs.sh members <org> [--role admin\|member]` |
| Add / remove / check member | `scripts/github-orgs.sh add-member <org> <user> [--role member\|admin]`, `rm-member`, `check-member` |
| Invite by email or username | `scripts/github-orgs.sh invite <org> <email-or-user> [--role direct_member\|admin]` |
| List / create / delete teams | `scripts/github-orgs.sh teams`, `team-create`, `team-rm` |
| Team membership / repo grants | `scripts/github-orgs.sh team-add`, `team-rm-member`, `team-add-repo` |

### Projects v2 (GraphQL)
| Intent | Command |
|---|---|
| List user/org projects | `scripts/github-projects.sh ls <owner>` |
| Get a project + its fields/items | `scripts/github-projects.sh get`, `fields`, `items <owner> <project-number>` |
| Add / remove an item | `scripts/github-projects.sh add-item <project-id> <issue-or-pr-node-id>`, `rm-item` |
| Set a field value (text/select/number/date) | `scripts/github-projects.sh set-field-text\|set-field-single-select\|set-field-number\|set-field-date` |
| Post a status update | `scripts/github-projects.sh status-update <project-id> "<body>" [--state ON_TRACK\|AT_RISK\|OFF_TRACK]` |

### Search (everything)
| Intent | Command |
|---|---|
| Repos / code / issues / PRs / users / orgs / commits / topics | `scripts/github-search.sh repos\|code\|issues\|prs\|users\|orgs\|commits\|topics "<query>" [--limit N]` |

### Security alerts
| Intent | Command |
|---|---|
| Dependabot alerts (list / get / dismiss) | `scripts/github-security.sh dependabot [...] [--state open] [--severity high]`, `dependabot-get`, `dismiss-dependabot` |
| Code scanning alerts | `scripts/github-security.sh code-scan [...] [--state open]`, `code-scan-get` |
| Secret scanning alerts | `scripts/github-security.sh secret-scan`, `secret-scan-get` |
| Repo / org security advisories | `scripts/github-security.sh advisories`, `org-advisories <org>` |
| Browse the global GHSA database | `scripts/github-security.sh ghsa-list [--ecosystem npm] [--severity high]`, `ghsa-get GHSA-…` |

### Notifications
| Intent | Command |
|---|---|
| Inbox / single thread | `scripts/github-notifications.sh ls [--all] [--participating] [--since YYYY-MM-DD]`, `get <thread-id>` |
| Mark single / all read | `scripts/github-notifications.sh read <thread-id>`, `read-all [--repo owner/repo]` |
| Dismiss thread (mark done) | `scripts/github-notifications.sh done <thread-id>` |
| Subscribe / unsubscribe | `scripts/github-notifications.sh subscribe`, `unsubscribe`, `repo-watch`, `repo-unwatch` |

### Webhooks, rulesets, deploy keys (fills MCP gap)
| Intent | Command |
|---|---|
| List / create / update / delete repo webhooks | `scripts/github-webhooks.sh ls\|get\|create\|update\|rm` |
| Test / list / redeliver hook events | `scripts/github-webhooks.sh test\|deliveries\|redeliver` |
| Org webhooks | `scripts/github-webhooks.sh org-ls\|org-create\|org-rm` |
| Branch protection rulesets | `scripts/github-webhooks.sh rulesets\|ruleset-get\|ruleset-rm` |
| Deploy keys | `scripts/github-webhooks.sh deploy-keys\|deploy-key-add\|deploy-key-rm` |

### Gists
| Intent | Command |
|---|---|
| List / get / fork | `scripts/github-gists.sh ls [--user X]`, `get`, `fork` |
| Create from a single or multiple files | `scripts/github-gists.sh create file.txt --public`, `create-multi "desc" f1 f2 …` |
| Update / patch / delete | `scripts/github-gists.sh update <id> file.txt`, `patch <id> <json>`, `rm <id>` |
| Star / unstar | `scripts/github-gists.sh star\|unstar <id>` |

For the full `gh` CLI surface, see [references/commands.md](references/commands.md).
For raw REST endpoints, see [references/rest-api.md](references/rest-api.md).
For 1:1 GitHub MCP tool mapping, see [references/mcp-parity.md](references/mcp-parity.md).

## Pagination workflow - REST uses Link headers, GraphQL uses cursors

**REST**: most list endpoints support `?per_page=100` (max). The `_lib.sh` helper `github_paginate` follows `Link: rel="next"` automatically and concatenates JSON arrays:

```bash
# Inside a script:
source "$(dirname "$0")/_lib.sh"
all_issues=$(github_paginate "/repos/cli/cli/issues?per_page=100&state=all")
echo "$all_issues" | jq 'length'

# Or via the generic api.sh:
scripts/github-api.sh GET "/repos/cli/cli/issues?per_page=100" --paginate
```

**GraphQL**: cursor-based via `pageInfo.endCursor`. Use `gh api graphql --paginate` with the `after:$endCursor` pattern, or write a loop in your script.

## Rate-limit aware retry - built into `scripts/github-api.sh`

Authenticated REST: 5,000 req/h primary + secondary rate limits on bursts. GraphQL: 5,000 points/h. Search: 30 req/min. The wrapper:

1. Detects `429` (primary) and `403 + retry-after` (secondary).
2. Reads `Retry-After` (seconds) or computes from `X-RateLimit-Reset` (epoch).
3. Retries up to 3 times with exponential backoff. Refuses to wait > 120s - surfaces an error instead.

Live budget: `scripts/github-ensure.sh` prints `core` and `graphql` remaining at the end of its checks.

For very large bulk jobs (rewriting topics on 1,000 repos, dismissing 5,000 Dependabot alerts), pace your loop:
```bash
for r in $(scripts/github-repos.sh ls --owner myorg --limit 100 | jq -r '.[].full_name'); do
  scripts/github-repos.sh topics "$r" "rust,cli"
  sleep 0.8     # ~75 req/min, well under any secondary limit
done
```

## Multi-file commit workflow - atomic via Git Data API

`scripts/github-files.sh push` mirrors the MCP `push_files` tool by composing the commit through 5 REST calls (get base ref → create blobs → create tree → create commit → update ref) - the result is one atomic commit with an arbitrary number of files, no local clone required:

```bash
# From any directory - files are uploaded as their basename:
scripts/github-files.sh push myorg/myrepo main "feat: add docs" \
  README.md docs/intro.md docs/api.md
```

For incremental edits use `put` (single file) or `rm` (delete with sha lookup) - they're one-shot REST calls.

## Guardrails (don't skip)

These prevent the most common destructive accidents:

1. **Never embed `GITHUB_TOKEN` in a script committed to git.** Always read from env. `.env.local` is gitignored by default in most templates; double-check before committing.
2. **`scripts/github-repos.sh rm` is irreversible.** It deletes the repo, all its issues, PRs, releases, deployments, and history. The script prompts for confirmation matching the repo name. There is no soft-delete and no undo. Use `archive` if you only need to freeze the repo.
3. **`scripts/github-prs.sh merge --method squash --delete-branch` deletes the source branch on remote.** If the branch is also tracked locally, prune your local copy with `git fetch -p` after.
4. **`scripts/github-secrets.sh set` overwrites silently.** Setting an existing secret name replaces the value with no version history. Audit current values via your password manager / secrets vault before rotating.
5. **`scripts/github-actions.sh dispatch` runs immediately.** Workflows triggered via `workflow_dispatch` execute on the specified ref using the workflow file from that ref. If a malicious branch contains a `workflow_dispatch` trigger, dispatching against it runs that branch's workflow with your credentials - only dispatch against trusted refs.
6. **Org membership changes are immediate and email the user.** `add-member` invites instantly; `rm-member` removes instantly. There is no "draft" or "preview" state.
7. **Token scopes are minimum, not actual permission.** A `repo`-scoped token still cannot push to a repo where the user lacks write permission. Errors come back as `403 Forbidden` even if the token's scopes look fine - check repo / org permissions, not just scopes.
8. **GraphQL points cost varies wildly.** A simple `viewer{login}` is 1 point, but a deep nested query over 100 repos can cost 100+. The `rate_limit` endpoint shows your `graphql.remaining`. Don't loop GraphQL in tight bash loops - batch with `first:100` and pagination instead.
9. **Fine-grained PATs have incomplete coverage on Projects v2 and some org-level admin.** If a `github-orgs.sh` or `github-projects.sh` call returns `404` or `403` despite you being an admin, swap to a classic PAT with `admin:org` and `project` scopes.
10. **Webhook secrets are write-once.** When you create a webhook with `--secret`, the secret is stored hashed; you cannot retrieve it later via API. Keep a copy in your password manager.

## When to reach for the references

- **[references/commands.md](references/commands.md)** - Full `gh` CLI command reference. Every top-level command (auth, repo, issue, pr, release, workflow, run, gist, secret, variable, label, project, search, codespace, ruleset, attestation, cache, api, extension) and its main subcommands with examples.
- **[references/rest-api.md](references/rest-api.md)** - Direct `curl` / `gh api` patterns against `https://api.github.com`. The `github_api()` boilerplate, REST endpoint catalog by resource (repos, files, issues, PRs, actions, secrets, orgs, security, traffic, etc.), GraphQL primer, pagination patterns, rate-limit handling.
- **[references/mcp-parity.md](references/mcp-parity.md)** - Mapping table: every `github-mcp-server` tool (post-Oct 2025 consolidation, ~84 tools, 19 toolsets) ↔ its `gh` / script equivalent + comparison vs the remote MCP at `api.githubcopilot.com/mcp/`.

## When NOT to use this skill

- Writing application code that integrates with the GitHub API at runtime → use `@octokit/rest`, `@octokit/graphql`, `octokit` (Python), or `octocrab` (Rust). This skill is for ops/admin from your shell, not for backend integration.
- Running CI inside a GitHub Action - `GITHUB_TOKEN` is auto-injected and `gh` is preinstalled on hosted runners. The bash helpers here still work but `gh` directly is leaner inside Actions.
- Authoring webhook receivers / event handlers - that's runtime code listening on a server, not bash polling. Use a webhook framework (`@octokit/webhooks`, FastAPI, Axum) and serve over HTTP.
- Hosting a GitHub App or OAuth App - App installation tokens, JWT signing with the App private key, and OAuth flows are not in scope. The skill assumes a personal token.
- Mirroring a repo to another forge (GitLab, Bitbucket) - not a GitHub-side operation. Use `git push --mirror` against the destination remote.
- Bulk operations exceeding 5,000 req/h - for org-wide migrations across many repos, run as a GitHub App with installation tokens (15,000 req/h per installation) instead.
