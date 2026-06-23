# Commands reference - `@posthog/cli` + helper scripts

## Official `@posthog/cli`

Package: [`@posthog/cli`](https://www.npmjs.com/package/@posthog/cli). Install via `bunx @posthog/cli ...` (never `npm install -g`).

The CLI is intentionally narrow - three things only:

| Subcommand | Purpose |
|---|---|
| `login` | Browser-based OAuth into `~/.config/posthog/` (writes a token) |
| `query` | Interactive HogQL REPL against the linked instance |
| `sourcemap inject` | Inject release/chunk metadata into JS bundles |
| `sourcemap upload` | Upload sourcemaps to PostHog Error Tracking |

### `login`

```bash
bunx @posthog/cli login
# Opens a browser to authenticate, writes a token to ~/.config/posthog/.
# After login, the CLI uses its own token; the bash skill ignores this file.
```

### `query`

```bash
bunx @posthog/cli query
# Starts an interactive HogQL prompt. Useful for ad-hoc exploration.
# For scripting, prefer scripts/posthog-query.sh (no TTY required).
```

### `sourcemap inject` + `upload`

```bash
# Step 1 - inject release metadata into bundles before deploy.
bunx @posthog/cli sourcemap inject --directory ./dist

# Step 2 - upload .map files to PostHog Error Tracking.
bunx @posthog/cli sourcemap upload \
  --directory ./dist \
  --release-name "frontend" \
  --release-version "1.4.2" \
  --build "$(git rev-parse --short HEAD)" \
  --delete-after \
  --host https://us.posthog.com
```

### CI environment variables

The CLI accepts these env vars in CI:

| Var | Purpose | Default |
|---|---|---|
| `POSTHOG_CLI_API_KEY` | personal API key (must have `error_tracking:write` + `organization:read` for sourcemaps) | - |
| `POSTHOG_CLI_HOST` | API host | `https://us.posthog.com` |
| `POSTHOG_CLI_PROJECT_ID` | numeric project ID | - |

These align with the bash skill's `POSTHOG_PERSONAL_API_KEY` / `POSTHOG_HOST` / `POSTHOG_PROJECT_ID` and `_lib.sh` will pick them up too if present in `.env.local`.

## Helper scripts - full subcommand surface

All helper scripts share these conventions:
- Last positional arg is always the optional `[project_id]`. If omitted, falls back to `$POSTHOG_PROJECT_ID`.
- Every command pretty-prints the JSON response via jq.
- Run any script without args to see its usage banner.

### `scripts/posthog-ensure.sh`

Preflight. No subcommands. Verifies `bun`, `@posthog/cli` reachability, `jq`, `curl`, the API key (and prefix), the host, and runs a live `GET /api/users/@me/`.

### `scripts/posthog-api.sh`

Generic REST wrapper. `posthog-api.sh <METHOD> <PATH> [json_body | curl_extra_args]`.

### `scripts/posthog-projects.sh`

`ls`, `ls-org <org_id>`, `get [project_id]`, `create <org_id> <name>`, `update <project_id> <patch-json>`, `switch <project_id>`, `me`.

### `scripts/posthog-orgs.sh`

`ls`, `get <org_id>`, `members <org_id>`, `rm-member <org_id> <member_id>`, `roles <org_id>`, `role <org_id> <role_id>`, `role-members <org_id> <role_id>`, `activity <org_id>`, `switch <org_id>`.

### `scripts/posthog-query.sh`

`hogql <sql>`, `hogql-file <path>`, `raw <body-json>`, `async <sql>`, `status <client_query_id>`, `log <client_query_id>`, `cancel <client_query_id>`, `schema`, `validate <sql>`, `table <sql>`, `logs <filter-json>`. Optional env: `POSTHOG_QUERY_NAME` to label queries.

### `scripts/posthog-events.sh`

`ls`, `recent <event_name> [limit]`, `search <query>`, `defs [search] [type]`, `def-get <id>`, `def-rename <id> <new_name>`, `def-update <id> <patch>`, `props [search] [type] [group_index]`, `prop-get <id>`, `prop-update <id> <patch>`, `values <prop_key> [event] [limit]`.

### `scripts/posthog-persons.sh`

`ls [limit]`, `get <person_id>`, `find <substring>`, `by-email <email>`, `by-distinct <distinct_id>`, `activity <person_id>`, `cohorts <person_id>`, `values <prop_key> [limit]`, `set-prop <person_id> <key> <value>`, `del-prop <person_id> <key>`, `rm <person_id>`, `bulk-rm <ids-csv>`, `bulk-rm-distinct <distinct_ids-csv>`.

### `scripts/posthog-cohorts.sh`

`ls`, `get <id>`, `create <name> <filters-json> [is_static]`, `create-static <name>`, `update <id> <patch>`, `rm <id>`, `persons <id>`, `add <id> <distinct_ids-csv>`, `remove <id> <distinct_ids-csv>`, `duplicate <id>`, `activity <id>`.

### `scripts/posthog-flags.sh`

`ls`, `get <id|key>`, `by-key <key>`, `create <key> <name> [active] [rollout%]`, `create-json <body>`, `update <id> <patch>`, `enable <id>`, `disable <id>`, `rollout <id> <percent>`, `rm <id>`, `status <id>`, `dependents <id>`, `activity <id>`, `copy <id> <target_project_ids-csv>`, `blast <id> <conditions>`, `local-eval`, `schedule <id> <iso-date> <change-json>`, `schedules <id>`, `schedule-rm <id> <change_id>`.

### `scripts/posthog-experiments.sh`

`ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>`, `launch <id>`, `pause <id>`, `resume <id>`, `end <id>`, `archive <id>`, `unarchive <id>`, `duplicate <id>`, `reset <id>`, `ship <id> <variant>`, `results <id>`, `stats <id>`, `timeseries <id>`.

### `scripts/posthog-insights.sh`

`ls`, `search <query>`, `get <id>`, `by-short <short_id>`, `create <body>`, `update <id> <patch>`, `rename <id> <name>`, `rm <id>`, `run <id> [refresh]` (refresh: `blocking|async|force`), `sharing <id>`, `activity`, `url <id>`.

### `scripts/posthog-dashboards.sh`

`ls`, `get <id>`, `create <name> [desc] [pinned]`, `create-json <body>`, `update <id> <patch>`, `rename <id> <name>`, `pin <id>`, `unpin <id>`, `rm <id>`, `refresh <id>`, `sharing <id>`, `add-tile <dashboard_id> <insight_id>`, `url <id>`.

### `scripts/posthog-errors.sh`

`ls`, `get <issue_id>`, `update <id> <patch>`, `resolve <id>`, `ignore <id>`, `assign <id> <user_id>`, `merge <primary> <ids-csv>`, `split <id> <fingerprints-csv>`, `grouping-ls`, `grouping-add <body>`, `suppress-ls`, `suppress-add <body>`, `assign-ls`, `assign-add <body>`, `query <filter-json>`.

### `scripts/posthog-surveys.sh`

`ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `launch <id>`, `stop <id>`, `archive <id>`, `rm <id>`, `stats <id>`, `global`, `activity`.

### `scripts/posthog-notebooks.sh`

`ls`, `get <short_id>`, `create <title> [content-json]`, `update <short_id> <patch>`, `rename <short_id> <new_title>`, `rm <short_id>`.

### `scripts/posthog-recordings.sh`

`ls [limit]`, `get <recording_id>`, `snapshots <id>`, `summarize <id>`, `rm <id>`, `playlists`, `playlist-get <id>`, `playlist-create <name>`, `playlist-update <id> <patch>`, `url <recording_id>`.

### `scripts/posthog-annotations.sh`

`ls`, `get <id>`, `create <content> [iso-date] [scope]` (scope: `project|dashboard_item|organization`), `update <id> <patch>`, `rm <id>`, `release <content> [version]`.

### `scripts/posthog-actions.sh`

`ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>`, `count <id>`, `people <id>`.

### `scripts/posthog-warehouse.sh`

Sources: `sources`, `source-get <id>`, `source-create <body>`, `source-update <id> <patch>`, `source-rm <id>`, `source-reload <id>`, `source-jobs <id>`, `source-schemas`.
Schemas: `schema-get <id>`, `schema-update <id> <patch>`, `schema-cancel <id>`, `schema-resync <id>`, `schema-reload <id>`.
Tables / views: `tables`, `views`, `view-get <id>`, `view-create <body>`, `view-update <id> <patch>`, `view-rm <id>`, `view-run <id>`, `view-materialize <id>`, `view-unmaterialize <id>`.
Health: `health`.

### `scripts/posthog-cdp.sh`

Hog functions: `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `enable <id>`, `disable <id>`, `rm <id>`, `logs <id>`, `metrics <id>`, `invoke <id> <event-json>`.
Templates: `templates`, `template-get <id>`.
Hog flows: `flow-logs <flow_id>`, `flow-metrics <flow_id>`.

### `scripts/posthog-llm.sh`

Two-level dispatch: `<resource> <subcommand> [args...]`.

| Resource | Subcommands |
|---|---|
| `prompts` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `duplicate <id>` |
| `evaluations` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>`, `run <id>`, `judge-models`, `test-hog <body>` |
| `eval-config` | `get`, `set-active <key>` |
| `reports` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>`, `generate <id>`, `runs <id>` |
| `sentiment` | `<body-json>` |
| `summarize` | `<body-json>` |
| `reviews` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>` |
| `queues` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>` |
| `queue-items` | `ls <queue_id>`, `add <queue_id> <body>`, `get <queue_id> <item_id>`, `update <queue_id> <item_id> <patch>`, `rm <queue_id> <item_id>` |
| `skills` | `ls`, `get <id>`, `create <body>`, `duplicate <id>` |
| `skill-files` | `ls <skill_id>`, `add <skill_id> <body>`, `get <skill_id> <file_id>`, `rename <skill_id> <file_id> <new_name>`, `rm <skill_id> <file_id>` |
| `clusters` | `ls`, `get <job_id>` |

### `scripts/posthog-misc.sh`

Two-level dispatch.

| Resource | Subcommands |
|---|---|
| `alerts` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>`, `simulate <id>` |
| `subs` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>`, `test <id>`, `deliveries [sub_id]` |
| `comments` | `ls`, `get <id>`, `count`, `thread <comment_id>` |
| `integrations` | `ls`, `get <id>`, `rm <id>`, `channels <id>` |
| `scheduled` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>` |
| `early-access` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>` |
| `activity` | `project`, `advanced [filter-json]`, `filters` |
| `change-req` | `ls`, `get <id>` |
| `approval` | `ls`, `get <id>` |
| `inbox` | `reports-ls`, `reports-get <id>`, `sources-ls`, `sources-get <id>`, `tickets-ls`, `tickets-get <id>`, `tickets-update <id> <patch>` |
| `sdk-doctor` | `get` |
| `web-digest` | `get` |
| `usage` | `ls`, `get <id>`, `create <body>`, `update <id> <patch>`, `rm <id>` |
| `proxy` | `ls`, `get <id>`, `create <body>`, `rm <id>`, `retry <id>` |
| `sql-vars` | `create <body>`, `update <id> <patch>`, `rm <id>` |
| `debug-mcp` | `ui-apps` |
| `logs` | `count <body>`, `sparkline <body>`, `attrs <body>`, `attr-values <body>`, `count-ranges <body>` |

## Common bash patterns

### Resolve current user's default project + auto-export

```bash
me=$(scripts/posthog-projects.sh me)
export POSTHOG_PROJECT_ID=$(printf '%s' "$me" | jq -r '.team.id')
echo "Active project: $(printf '%s' "$me" | jq -r '.team.name') ($POSTHOG_PROJECT_ID)"
```

### Pipe HogQL TSV into a CSV

```bash
scripts/posthog-query.sh table "
  SELECT distinct_id, properties.email, count() AS events
  FROM events
  WHERE timestamp >= now() - INTERVAL 30 DAY
  GROUP BY distinct_id, properties.email
" | tr '\t' ',' > active-users.csv
```

### Bulk-disable feature flags matching a prefix

```bash
scripts/posthog-flags.sh ls \
  | jq -r '.results[] | select(.key | startswith("legacy_")) | .id' \
  | while read fid; do
      scripts/posthog-flags.sh disable "$fid"
      sleep 0.05
    done
```

### Move all "active" error tracking issues older than 30 days into "suppressed"

```bash
scripts/posthog-errors.sh ls \
  | jq -r --arg cutoff "$(date -u -d '30 days ago' +%FT%TZ)" \
      '.results[] | select(.status=="active" and .last_seen < $cutoff) | .id' \
  | while read iid; do
      scripts/posthog-errors.sh ignore "$iid"
    done
```
