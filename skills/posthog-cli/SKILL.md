---
model: opus
name: posthog-cli
description: "Manage every PostHog resource - insights, dashboards, feature flags, experiments, cohorts, persons, events, HogQL queries, error tracking, surveys, notebooks, session recordings, annotations, actions, data warehouse, CDP / Hog functions, LLM analytics (prompts, evaluations, trace reviews), organizations, projects, alerts, subscriptions, scheduled changes - from bash via the PostHog REST API at us.posthog.com / eu.posthog.com / self-hosted, replacing the PostHog MCP server. Covers all ~250 mcp__posthog__* tools the official MCP exposes plus the broader REST surface (~40 resource categories) the MCP doesn't expose. Authenticates with a single POSTHOG_PERSONAL_API_KEY (phx_*) - no OAuth, no separate process. Use when the user asks to list/query/create/update/delete any PostHog resource, run HogQL, manage feature flags or experiments, inspect persons or events, work with error tracking, surveys, recordings, or LLM analytics, switch projects/orgs, or says 'posthog-cli', 'posthog CLI', 'query my PostHog data', 'manage my PostHog flags', 'PostHog API', 'HogQL', 'replace PostHog MCP'. Do NOT use when the user wants to write application code that captures events at runtime (use posthog-js / posthog-node / posthog-python SDKs in code instead) or to manage the PostHog MCP server itself."
argument-hint: "[command or natural-language request]"
---

# posthog-cli - PostHog via bash, no MCP

Replace the `posthog/services/mcp` server with direct `curl` calls against the PostHog REST API. Everything runs in your shell with `POSTHOG_PERSONAL_API_KEY`.

## Why this exists

PostHog's official MCP exposes ~250 tools, but the management surface is far broader (HogQL, Hog functions / CDP, LLM observability, error tracking grouping rules, scheduled changes, advanced activity logs, proxy records, inbox, change requests, approval policies, SDK doctor, web analytics digest, and more). Bash + the REST API gives:

- **Lower latency** - no JSON-RPC roundtrip, no separate MCP process.
- **Greppable surface** - every endpoint is a line in a shell script in your repo.
- **Same auth as the MCP** - `POSTHOG_PERSONAL_API_KEY` (`phx_*`) is exactly what the MCP uses.
- **Wider coverage** - many endpoints are not in the MCP; this skill exposes them as first-class subcommands.

The official `@posthog/cli` is intentionally narrow (sourcemap upload + interactive HogQL + login). It does not replace the MCP. This skill does.

## Hard prerequisites

1. **`bun`** - global rule mandates bun, never npm/npx. Used for the optional `@posthog/cli`.
2. **`curl`** - install it with your OS package manager if it is not already available. Every API call goes through curl.
3. **`jq`** - required for JSON shaping. `sudo dnf install jq` if missing.
4. **`POSTHOG_PERSONAL_API_KEY`** - auto-loaded from the project's `.env.local` (then `.env`) walking up to the git repo root, or pulled from the shell environment if exported. Format `phx_...`. Two ways to provide it:
   ```bash
   # A) From a project - the same .env.local your app uses for posthog-js/posthog-node
   cd ~/code/myapp                         # .env.local has POSTHOG_PERSONAL_API_KEY=phx_...
   scripts/posthog-flags.sh ls             # auto-loaded, no export needed

   # B) Headless / CI / global use - export in the shell
   export POSTHOG_PERSONAL_API_KEY=phx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
5. **(Optional) `POSTHOG_HOST`** - defaults to `https://us.posthog.com`. Set to `https://eu.posthog.com` for EU Cloud or your self-hosted URL. Auto-loaded from `.env(.local)` too.
6. **(Optional) `POSTHOG_PROJECT_ID`** - integer project ID. If not set, every project-scoped script needs it as an explicit positional arg. Discover with `scripts/posthog-projects.sh ls`.

Generate a personal API key at **PostHog UI → Settings → Personal API Keys → "+ Create personal API key"**. Max 10 keys per user. Copy immediately - never shown again. Grant the scopes you need (read/write per resource: `insight:read`, `feature_flag:write`, `query:read`, `cohort:read`, etc.). For full management access, grant all read+write scopes.

Run `scripts/posthog-ensure.sh` to verify prerequisites, including a live call to `GET /api/users/@me/` that prints your default org + project so you know which context the key resolves to.

## Invocation patterns (always use one of these)

**Generic REST wrapper** - best for ad-hoc reads + writes (returns clean JSON, retries on 429):
```bash
scripts/posthog-api.sh GET    /api/projects/
scripts/posthog-api.sh GET    "/api/projects/$PID/feature_flags/?limit=50"
scripts/posthog-api.sh POST   /api/projects/$PID/query/ '{"query":{"kind":"HogQLQuery","query":"SELECT count() FROM events"}}'
scripts/posthog-api.sh PATCH  /api/projects/$PID/feature_flags/123/ '{"active":false}'
scripts/posthog-api.sh DELETE /api/projects/$PID/cohorts/456/
```

**Resource-specific helpers** - best for repeatable workflows (subcommand pattern):
```bash
scripts/posthog-flags.sh ls
scripts/posthog-flags.sh enable my-flag-id
scripts/posthog-query.sh hogql "SELECT event, count() FROM events WHERE timestamp >= now() - INTERVAL 1 DAY GROUP BY event ORDER BY count() DESC LIMIT 20"
scripts/posthog-cohorts.sh add 42 "user_a,user_b,user_c"
scripts/posthog-experiments.sh launch 7
scripts/posthog-errors.sh resolve issue_xxx
```

**Official `@posthog/cli`** - only for sourcemaps + interactive HogQL prompt:
```bash
bunx @posthog/cli login                                           # browser-based auth into ~/.config/posthog
bunx @posthog/cli query                                           # interactive HogQL REPL
bunx @posthog/cli sourcemap inject ./dist
bunx @posthog/cli sourcemap upload --directory ./dist --release-name app --release-version 1.2.3
```

Never `npm install -g @posthog/cli` - use `bunx @posthog/cli` so it always pins to the latest published version.

## Multi-project / multi-region context

PostHog has **one personal API key per user** (account-wide), but every project-scoped endpoint needs a `project_id`. The skill resolves the active project in this order:

1. **Explicit positional arg** to a script (last positional, e.g., `scripts/posthog-flags.sh ls 12345`).
2. **`POSTHOG_PROJECT_ID`** env var (auto-loaded from `.env.local` walking up to git root, then `.env`).
3. Fail with `find IDs with: scripts/posthog-projects.sh ls`.

```bash
# Working on app A (US Cloud) - its .env.local pins POSTHOG_PROJECT_ID + POSTHOG_HOST
cd ~/code/myapp-a
scripts/posthog-flags.sh ls         # uses myapp-a's project automatically

# Working on app B (EU Cloud) - different .env.local
cd ~/code/myapp-b
scripts/posthog-flags.sh ls         # uses myapp-b's project automatically (and EU host)

# Override for a single call
POSTHOG_PROJECT_ID=99 POSTHOG_HOST=https://eu.posthog.com scripts/posthog-flags.sh ls

# Or switch the active project for the whole shell:
eval "$(scripts/posthog-projects.sh switch 12345)"
```

Helpers never persist, cache, or write the key anywhere - they read it once per invocation. `scripts/posthog-ensure.sh` reports the source of the loaded key (`shell environment` vs absolute `.env.local` path) so you can confirm which instance you're about to operate on.

## Quick map - "I want to..." → command

| Intent | Command |
|---|---|
| Verify auth + show user/org/project | `scripts/posthog-ensure.sh` |
| List all projects I can access | `scripts/posthog-projects.sh ls` |
| Switch active project for this shell | `eval "$(scripts/posthog-projects.sh switch <id>)"` |
| Run a HogQL query (sync) | `scripts/posthog-query.sh hogql "<sql>"` |
| Run HogQL from a .sql file | `scripts/posthog-query.sh hogql-file query.sql` |
| Run HogQL async + poll | `scripts/posthog-query.sh async "<sql>"` then `scripts/posthog-query.sh status <client_query_id>` |
| Validate HogQL without running | `scripts/posthog-query.sh validate "<sql>"` |
| Get HogQL TSV output | `scripts/posthog-query.sh table "<sql>"` |
| List feature flags | `scripts/posthog-flags.sh ls` |
| Get a flag by key | `scripts/posthog-flags.sh by-key my-flag` |
| Toggle a flag on/off | `scripts/posthog-flags.sh enable <id>` / `disable <id>` |
| Set a flag rollout % | `scripts/posthog-flags.sh rollout <id> 25` |
| Copy a flag to other projects | `scripts/posthog-flags.sh copy <id> "456,789"` |
| Schedule a flag change | `scripts/posthog-flags.sh schedule <id> 2026-12-01T00:00:00Z '{"active":false}'` |
| List experiments | `scripts/posthog-experiments.sh ls` |
| Launch / pause / end an experiment | `scripts/posthog-experiments.sh launch <id>` / `pause` / `end` |
| Ship a winning variant | `scripts/posthog-experiments.sh ship <id> <variant_key>` |
| Get experiment results | `scripts/posthog-experiments.sh results <id>` |
| List cohorts | `scripts/posthog-cohorts.sh ls` |
| Create a static cohort + add users | `scripts/posthog-cohorts.sh create-static "VIPs"` then `add <id> "user_a,user_b"` |
| Find a person by email | `scripts/posthog-persons.sh by-email user@example.com` |
| Bulk-delete persons | `scripts/posthog-persons.sh bulk-rm-distinct "id1,id2,id3"` |
| List recent events of a name | `scripts/posthog-events.sh recent pageview 50` |
| List event/property definitions | `scripts/posthog-events.sh defs` / `posthog-events.sh props` |
| Distinct property values | `scripts/posthog-events.sh values "$browser"` |
| List insights / dashboards | `scripts/posthog-insights.sh ls` / `posthog-dashboards.sh ls` |
| Run an insight | `scripts/posthog-insights.sh run <id>` |
| Open insight URL | `scripts/posthog-insights.sh url <id>` |
| Pin a dashboard | `scripts/posthog-dashboards.sh pin <id>` |
| List + resolve error tracking issues | `scripts/posthog-errors.sh ls` / `resolve <issue_id>` |
| Assign an error to a user | `scripts/posthog-errors.sh assign <issue_id> <user_id>` |
| Add a release annotation | `scripts/posthog-annotations.sh release "v1.2.3 deployed" 1.2.3` |
| List + summarize a recording | `scripts/posthog-recordings.sh ls 50` / `summarize <recording_id>` |
| List + invoke a Hog function | `scripts/posthog-cdp.sh ls` / `invoke <id> '<event-json>'` |
| Manage LLM evaluations | `scripts/posthog-llm.sh evaluations ls` / `create <body>` / `run <id>` |
| Save a HogQL view | `scripts/posthog-warehouse.sh view-create '{"name":"vw_top","query":{...}}'` |
| Search docs | use the `posthog` MCP `docs-search` tool - bash skill does not duplicate this |

For full inventories, see [references/rest-api.md](references/rest-api.md), [references/mcp-parity.md](references/mcp-parity.md), [references/hogql-cookbook.md](references/hogql-cookbook.md), and [references/commands.md](references/commands.md).

## HogQL workflow

HogQL is the SQL-like query layer over events, persons, sessions, recordings, and warehouse tables.

```bash
# Sync (blocking) - best for queries that finish in seconds
scripts/posthog-query.sh hogql "SELECT event, count() FROM events WHERE timestamp >= now() - INTERVAL 7 DAY GROUP BY event ORDER BY count() DESC LIMIT 50"

# TSV output for pipes / spreadsheets
scripts/posthog-query.sh table "SELECT properties.email FROM persons WHERE properties.plan='enterprise'" > emails.tsv

# Async - for long-running queries
qid=$(scripts/posthog-query.sh async "<heavy sql>" | jq -r '.client_query_id')
while true; do
  s=$(scripts/posthog-query.sh status "$qid" | jq -r '.query_status.complete')
  [[ "$s" == "true" ]] && break
  sleep 2
done
scripts/posthog-query.sh status "$qid" | jq '.results'

# Validate before running expensive queries
scripts/posthog-query.sh validate "SELECT * FROM events"
```

Other supported `kind` values via `posthog-query.sh raw`: `EventsQuery`, `PersonsQuery`, `TrendsQuery`, `FunnelsQuery`, `RetentionQuery`, `PathsQuery`, `StickinessQuery`, `LifecycleQuery`, `DataWarehouseQuery`, `LogsQuery`, `ErrorTrackingQuery`. See [references/hogql-cookbook.md](references/hogql-cookbook.md) for canonical examples.

## Pagination workflow

PostHog uses cursor-based pagination - every list endpoint returns `{count, next, previous, results: [...]}`. The wrapper `posthog_paginate` (in `scripts/_lib.sh`) follows `.next` URLs automatically; helper scripts that return `.results[]` already use it where it matters. For ad-hoc paginated reads:

```bash
source scripts/_lib.sh
require_posthog_key
posthog_paginate "/api/projects/$POSTHOG_PROJECT_ID/feature_flags/?limit=100" \
  | jq -s 'sort_by(.key)' > all-flags.json
```

## Rate-limit aware retry - built into `posthog_api`

PostHog rate limits (per-team, all users in one org share the bucket):

| Endpoint category | Limit |
|---|---|
| Analytics / list endpoints | 240/min, 1,200/hour |
| Standard CRUD | 480/min, 4,800/hour |
| `/query/` (HogQL) | 2,400/hour |
| `events/values` | 60/min, 300/hour |
| Public POST `/capture/` | unlimited (separate ingestion path, not in this skill) |

On HTTP 429 the API returns `Retry-After` (seconds). `_lib.sh` reads it and retries up to 3 times. For higher concurrency, batch with explicit sleep:

```bash
# Migration: tag 5,000 persons. Pace 50 req/s to stay well under 480 req/min.
for u in $(jq -r '.[].id' persons.json); do
  scripts/posthog-persons.sh set-prop "$u" migrated true
  sleep 0.02
done
```

## Guardrails (don't skip)

1. **Never embed `POSTHOG_PERSONAL_API_KEY` in a script committed to git.** Always read from env. Helpers enforce this.
2. **`scripts/posthog-persons.sh rm`** is irreversible - deletes the person, their events stay anonymized but the link is gone. Use `bulk-rm` only with a verified ID list.
3. **`scripts/posthog-projects.sh switch`** only prints an `export` line - eval it. It does NOT change PostHog server state.
4. **Flag changes propagate immediately** in production via `/decide` and `local_evaluation`. Verify with `scripts/posthog-flags.sh status <id>` before flipping critical flags.
5. **Experiment `ship`** ends the experiment and creates an exposure cohort - you cannot resume after shipping. Use `pause` / `end` if you need a soft stop.
6. **Cohort `add`/`remove` only work on STATIC cohorts.** Dynamic (filter-based) cohorts manage their membership server-side; trying to add to one fails with 400.
7. **HogQL queries against very large date ranges can hit the 2,400/hour quota fast.** Use `scripts/posthog-query.sh validate` to confirm syntax + cost estimate before running async.
8. **Project API keys (`phc_*`) cannot read management endpoints.** The skill detects this format and refuses. Always use a personal key (`phx_*`).
9. **The `/api/projects/{id}/` prefix is being deprecated** in favor of `/api/environments/{id}/` for data-scoped resources. Both currently work; this skill uses `projects/` for stability. Migrate when PostHog announces a hard deadline.
10. **Personal API key scope mismatches surface as 403, not 401.** If a script fails with `forbidden`, you likely missed a scope when creating the key - re-issue with the right scopes.

## When to reach for the references

- **[references/rest-api.md](references/rest-api.md)** - endpoint catalog by resource (path, methods, scopes, body shape), pagination, rate limits, error format. Use when you need a path the helpers don't cover.
- **[references/mcp-parity.md](references/mcp-parity.md)** - every `mcp__posthog__*` tool ↔ its bash equivalent. Use when migrating an MCP-based workflow to bash, or when the user references a specific MCP tool name.
- **[references/hogql-cookbook.md](references/hogql-cookbook.md)** - canonical HogQL patterns: top events, conversion funnels, cohort analysis, retention, LLM cost roll-ups, error tracking joins, warehouse joins.
- **[references/commands.md](references/commands.md)** - `@posthog/cli` subcommands (login, query, sourcemap inject/upload) + every helper script's full subcommand surface.

## When NOT to use this skill

- Writing application code that captures events at runtime → use `posthog-js`, `posthog-node`, `posthog-python`, etc. directly. Those use the public **project API key** (`phc_*`), not the personal key (`phx_*`) this skill uses.
- Real-time event streaming → PostHog has no real-time event firehose API. Use webhooks/destinations or query with HogQL on a polling cadence.
- Configuring billing, paying invoices, or managing seats → dashboard-only.
- Modifying instance signing keys / OIDC → dashboard-only, no API surface.
- Capturing source maps for error tracking from a bash script → use the official `bunx @posthog/cli sourcemap upload` rather than reimplementing the multipart upload here.
- Continuous polling for new events → noisy and quota-burning. Set up a webhook destination + listener instead, or batch with `>= timestamp` filters at low cadence.
