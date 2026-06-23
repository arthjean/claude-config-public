# MCP ↔ posthog-cli parity map

Maps every `mcp__posthog__*` tool exposed by the PostHog MCP server to its bash equivalent in this skill. **Bold rows** are tools where the bash version exposes more functionality than the MCP. *(MCP gap)* rows mark resources only available via bash.

## Surface - `posthog/services/mcp` (replaces archived PostHog/mcp)

~250 tools across the categories below. The MCP wraps subsets of the REST API - bash hits the API directly with `posthog_api`.

### Account, orgs, projects

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `user-get` / `user-home-settings-get` / `user-home-settings-update` / `user-settings-update` | `scripts/posthog-projects.sh me` + `scripts/posthog-api.sh PATCH /api/users/@me/ '{...}'` | Direct REST for less-common patches. |
| `organizations-list` | `scripts/posthog-orgs.sh ls` | |
| `organization-get` | `scripts/posthog-orgs.sh get <id>` | |
| `org-members-list` | `scripts/posthog-orgs.sh members <id>` | |
| `roles-list` / `role-get` / `role-members-list` | `scripts/posthog-orgs.sh roles|role|role-members` | |
| `switch-organization` | `scripts/posthog-orgs.sh switch <id>` (prints export hint) | |
| `project-get` / `projects-get` | `scripts/posthog-projects.sh get` / `ls` | |
| `project-settings-update` | `scripts/posthog-projects.sh update <id> '<patch>'` | |
| `switch-project` | `scripts/posthog-projects.sh switch <id>` (prints export hint) | |

### HogQL & queries

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `query-run` | `scripts/posthog-query.sh hogql "<sql>"` or `raw <body>` | |
| `query-validate` | `scripts/posthog-query.sh validate "<sql>"` | |
| `query-generate-hogql-from-question` | *(not implemented in bash - uses LLM tooling MCP-side)* | Use Claude to generate HogQL, then run via `hogql`. |
| `query-logs` | `scripts/posthog-misc.sh logs sparkline '<body>'` etc. | |
| **`hogql-schema`** | `scripts/posthog-query.sh schema` | Returns full `DatabaseSchemaQuery` result; richer than MCP's filtered output. |
| `query-error-tracking-issues` | `scripts/posthog-errors.sh query '<filter-json>'` | |
| `get-llm-total-costs-for-project` | HogQL recipe → see [hogql-cookbook.md](hogql-cookbook.md#llm-cost-rollup) | |

### Feature flags

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `feature-flag-get-all` | `scripts/posthog-flags.sh ls` | |
| `feature-flag-get-definition` | `scripts/posthog-flags.sh get <id>` / `by-key <key>` | |
| `create-feature-flag` | `scripts/posthog-flags.sh create <key> <name>` (simple) or `create-json '<body>'` (full) | |
| `update-feature-flag` | `scripts/posthog-flags.sh update <id> '<patch>'` / `enable` / `disable` / `rollout` | Convenience subcommands beyond MCP. |
| `delete-feature-flag` | `scripts/posthog-flags.sh rm <id>` | |
| `feature-flags-status-retrieve` | `scripts/posthog-flags.sh status <id>` | |
| `feature-flags-dependent-flags-retrieve` | `scripts/posthog-flags.sh dependents <id>` | |
| `feature-flags-evaluation-reasons-retrieve` | `scripts/posthog-api.sh GET /api/projects/$PID/feature_flags/$ID/evaluation_reasons/` | |
| `feature-flags-activity-retrieve` | `scripts/posthog-flags.sh activity <id>` | |
| `feature-flags-copy-flags-create` | `scripts/posthog-flags.sh copy <id> "<targets-csv>"` | |
| `feature-flags-user-blast-radius-create` | `scripts/posthog-flags.sh blast <id> '<conditions>'` | |

### Experiments

| MCP tool | bash equivalent |
|---|---|
| `experiment-list` / `experiment-get-all` | `scripts/posthog-experiments.sh ls` |
| `experiment-get` | `scripts/posthog-experiments.sh get <id>` |
| `experiment-create` | `scripts/posthog-experiments.sh create '<body>'` |
| `experiment-update` | `scripts/posthog-experiments.sh update <id> '<patch>'` |
| `experiment-delete` | `scripts/posthog-experiments.sh rm <id>` |
| `experiment-launch` / `pause` / `resume` / `end` | `scripts/posthog-experiments.sh launch|pause|resume|end <id>` |
| `experiment-archive` / `unarchive` | `scripts/posthog-experiments.sh archive|unarchive <id>` |
| `experiment-duplicate` / `reset` | `scripts/posthog-experiments.sh duplicate|reset <id>` |
| `experiment-ship-variant` | `scripts/posthog-experiments.sh ship <id> <variant>` |
| `experiment-results-get` | `scripts/posthog-experiments.sh results <id>` |
| `experiment-stats` | `scripts/posthog-experiments.sh stats <id>` |
| `experiment-timeseries-results` | `scripts/posthog-experiments.sh timeseries <id>` |

### Insights & dashboards

| MCP tool | bash equivalent |
|---|---|
| `insights-list` | `scripts/posthog-insights.sh ls` |
| `insight-get` | `scripts/posthog-insights.sh get <id>` |
| `insight-create` | `scripts/posthog-insights.sh create '<body>'` |
| `insight-update` | `scripts/posthog-insights.sh update <id> '<patch>'` |
| `insight-delete` | `scripts/posthog-insights.sh rm <id>` |
| `insight-query` | `scripts/posthog-insights.sh run <id>` |
| `dashboards-get-all` | `scripts/posthog-dashboards.sh ls` |
| `dashboard-get` | `scripts/posthog-dashboards.sh get <id>` |
| `dashboard-create` | `scripts/posthog-dashboards.sh create <name>` / `create-json '<body>'` |
| `dashboard-update` / `dashboard-delete` | `scripts/posthog-dashboards.sh update|rm` |
| `dashboard-reorder-tiles` | `scripts/posthog-api.sh POST /api/projects/$PID/dashboards/$DID/move_tile/ '<body>'` |
| `dashboard-insights-run` | `scripts/posthog-dashboards.sh refresh <id>` |

### Cohorts, persons, events

| MCP tool | bash equivalent |
|---|---|
| `cohorts-list` | `scripts/posthog-cohorts.sh ls` |
| `cohorts-retrieve` | `scripts/posthog-cohorts.sh get <id>` |
| `cohorts-create` | `scripts/posthog-cohorts.sh create <name> '<filters>'` / `create-static <name>` |
| `cohorts-partial-update` | `scripts/posthog-cohorts.sh update <id> '<patch>'` |
| `cohorts-add-persons-to-static-cohort-partial-update` | `scripts/posthog-cohorts.sh add <id> "csv"` |
| `cohorts-rm-person-from-static-cohort-partial-update` | `scripts/posthog-cohorts.sh remove <id> "csv"` |
| `persons-list` | `scripts/posthog-persons.sh ls` / `find` / `by-email` / `by-distinct` |
| `persons-retrieve` | `scripts/posthog-persons.sh get <id>` |
| `persons-cohorts-retrieve` | `scripts/posthog-persons.sh cohorts <id>` |
| `persons-values-retrieve` | `scripts/posthog-persons.sh values <key>` |
| `persons-property-set` | `scripts/posthog-persons.sh set-prop <id> <key> <val>` |
| `persons-property-delete` | `scripts/posthog-persons.sh del-prop <id> <key>` |
| `persons-bulk-delete` | `scripts/posthog-persons.sh bulk-rm "ids"` / `bulk-rm-distinct "csv"` |
| `event-definitions-list` | `scripts/posthog-events.sh defs` |
| `event-definition-update` | `scripts/posthog-events.sh def-update <id> '<patch>'` / `def-rename <id> <name>` |
| `properties-list` | `scripts/posthog-events.sh props` |
| `entity-search` | grep across `scripts/posthog-events.sh defs`, `props`, `posthog-actions.sh ls`, `posthog-flags.sh ls` |

### Error tracking

| MCP tool | bash equivalent |
|---|---|
| `error-tracking-issues-list` | `scripts/posthog-errors.sh ls` |
| `error-tracking-issues-retrieve` | `scripts/posthog-errors.sh get <id>` |
| `error-tracking-issues-partial-update` | `scripts/posthog-errors.sh update|resolve|ignore|assign` |
| `error-tracking-issues-merge-create` | `scripts/posthog-errors.sh merge <primary> "csv"` |
| `error-tracking-issues-split-create` | `scripts/posthog-errors.sh split <id> "fingerprints-csv"` |
| `error-tracking-grouping-rules-list` / `-create` | `scripts/posthog-errors.sh grouping-ls|grouping-add` |
| `error-tracking-suppression-rules-list` / `-create` | `scripts/posthog-errors.sh suppress-ls|suppress-add` |
| `error-tracking-assignment-rules-list` / `-create` | `scripts/posthog-errors.sh assign-ls|assign-add` |

### Surveys, notebooks, recordings, annotations, actions

| MCP tool | bash equivalent |
|---|---|
| `surveys-get-all` / `survey-get` / `-create` / `-update` / `-delete` | `scripts/posthog-surveys.sh ls|get|create|update|rm` |
| `survey-stats` / `surveys-global-stats` | `scripts/posthog-surveys.sh stats <id>` / `global` |
| `notebooks-list` / `-retrieve` / `-create` / `-partial-update` / `-destroy` | `scripts/posthog-notebooks.sh ls|get|create|update|rm` |
| `session-recording-get` / `-delete` | `scripts/posthog-recordings.sh get|rm` |
| `session-recording-summarize` | `scripts/posthog-recordings.sh summarize <id>` |
| `session-recording-playlist-*` / `session-recording-playlists-list` | `scripts/posthog-recordings.sh playlists|playlist-get|playlist-create|playlist-update` |
| `annotations-list` / `annotation-retrieve` / `-create` / `annotations-partial-update` / `annotation-delete` | `scripts/posthog-annotations.sh ls|get|create|update|rm` |
| `actions-get-all` / `action-get` / `-create` / `-update` / `-delete` | `scripts/posthog-actions.sh ls|get|create|update|rm` |

### Data warehouse

| MCP tool | bash equivalent |
|---|---|
| `external-data-sources-list` / `-retrieve` / `-create` / `-partial-update` / `-destroy` | `scripts/posthog-warehouse.sh sources|source-get|source-create|source-update|source-rm` |
| `external-data-sources-reload` / `-jobs` | `scripts/posthog-warehouse.sh source-reload|source-jobs` |
| `external-data-sources-check-cdc-prerequisites-create` / `-wizard` / `-db-schema` / `-refresh-schemas` | `scripts/posthog-api.sh POST /api/projects/$PID/external_data_sources/check_cdc_prerequisites/` etc. |
| `external-data-sources-create-webhook-create` / `-delete-webhook-create` / `-update-webhook-inputs-create` / `-webhook-info-retrieve` | `scripts/posthog-api.sh ...` (REST direct) |
| `external-data-schemas-list` / `-retrieve` / `-partial-update` | `scripts/posthog-warehouse.sh source-schemas|schema-get|schema-update` |
| `external-data-schemas-cancel` / `-resync` / `-reload` | `scripts/posthog-warehouse.sh schema-cancel|schema-resync|schema-reload` |
| `external-data-schemas-incremental-fields-create` / `-delete-data` | `scripts/posthog-api.sh POST/DELETE ...` |
| `external-data-sync-logs` | `scripts/posthog-api.sh GET /api/projects/$PID/external_data_sources/$ID/jobs/?include_logs=true` |
| `view-list` / `-get` / `-create` / `-update` / `-delete` | `scripts/posthog-warehouse.sh views|view-get|view-create|view-update|view-rm` |
| `view-run` / `view-run-history` | `scripts/posthog-warehouse.sh view-run` / `scripts/posthog-api.sh GET ../run_history/` |
| `view-materialize` / `-unmaterialize` | `scripts/posthog-warehouse.sh view-materialize|view-unmaterialize` |
| `data-warehouse-data-health-issues-retrieve` | `scripts/posthog-warehouse.sh health` |

### CDP - Hog functions & Hog flows

| MCP tool | bash equivalent |
|---|---|
| `cdp-functions-list` / `-create` / `-retrieve` / `-partial-update` / `-delete` | `scripts/posthog-cdp.sh ls|create|get|update|rm` |
| `cdp-functions-logs-retrieve` / `-metrics-retrieve` | `scripts/posthog-cdp.sh logs|metrics <id>` |
| `cdp-functions-invocations-create` | `scripts/posthog-cdp.sh invoke <id> '<event>'` |
| `cdp-functions-rearrange-partial-update` | `scripts/posthog-api.sh PATCH /api/projects/$PID/hog_functions/rearrange/ '<body>'` |
| `cdp-function-templates-list` / `-retrieve` | `scripts/posthog-cdp.sh templates|template-get` |
| `hog-flows-logs-retrieve` / `-metrics-retrieve` | `scripts/posthog-cdp.sh flow-logs|flow-metrics <id>` |

### LLM observability (`llma-*`)

| MCP tool | bash equivalent |
|---|---|
| `llma-prompt-list` / `-get` / `-create` / `-update` / `-duplicate` | `scripts/posthog-llm.sh prompts ls|get|create|update|duplicate` |
| `llma-evaluation-list` / `-create` / `-get` / `-update` / `-delete` / `-run` | `scripts/posthog-llm.sh evaluations ls|get|create|update|rm|run` |
| `llma-evaluation-judge-models` | `scripts/posthog-llm.sh evaluations judge-models` |
| `llma-evaluation-test-hog` | `scripts/posthog-llm.sh evaluations test-hog '<body>'` |
| `llma-evaluation-config-get` / `-set-active-key` | `scripts/posthog-llm.sh eval-config get|set-active <key>` |
| `llma-evaluation-report-list` / `-get` / `-create` / `-update` / `-delete` / `-generate` / `-run-list` | `scripts/posthog-llm.sh reports ls|get|create|update|rm|generate|runs` |
| `llma-evaluation-summary-create` | `scripts/posthog-llm.sh summarize '<body>'` |
| `llma-sentiment-create` | `scripts/posthog-llm.sh sentiment '<body>'` |
| `llma-summarization-create` | `scripts/posthog-llm.sh summarize '<body>'` |
| `llma-trace-review-list` / `-get` / `-create` / `-update` / `-delete` | `scripts/posthog-llm.sh reviews ls|get|create|update|rm` |
| `llma-review-queue-list` / `-get` / `-create` / `-update` / `-delete` | `scripts/posthog-llm.sh queues ls|get|create|update|rm` |
| `llma-review-queue-item-list` / `-get` / `-create` / `-update` / `-delete` | `scripts/posthog-llm.sh queue-items ls|get|add|update|rm` |
| `llma-skill-list` / `-get` / `-create` / `-update` / `-duplicate` | `scripts/posthog-llm.sh skills ls|get|create|duplicate` |
| `llma-skill-file-create` / `-get` / `-rename` / `-delete` | `scripts/posthog-llm.sh skill-files add|get|rename|rm` |
| `llma-clustering-job-list` / `-get` | `scripts/posthog-llm.sh clusters ls|get` |
| `get-llm-total-costs-for-project` | HogQL recipe - see [hogql-cookbook.md](hogql-cookbook.md#llm-cost-rollup) |

### Alerts, subscriptions, comments, integrations, scheduled changes, early access, inbox, change requests, approval policies, SDK doctor, web digest, usage metrics, proxy, SQL variables, logs, debug

| MCP tool | bash equivalent |
|---|---|
| `alerts-list` / `alert-get` / `-create` / `-update` / `-delete` / `-simulate` | `scripts/posthog-misc.sh alerts ls|get|create|update|rm|simulate` |
| `subscriptions-list` / `-retrieve` / `-create` / `-partial-update` / `subscriptions-test-delivery-create` | `scripts/posthog-misc.sh subs ls|get|create|update|rm|test` |
| `subscriptions-deliveries-list` / `-retrieve` | `scripts/posthog-misc.sh subs deliveries [sub_id]` |
| `comments-list` / `comment-get` / `-thread` / `-count` | `scripts/posthog-misc.sh comments ls|get|thread|count` |
| `integrations-list` / `integration-get` / `-delete` / `integrations-channels-retrieve` | `scripts/posthog-misc.sh integrations ls|get|rm|channels` |
| `scheduled-changes-list` / `-get` / `-create` / `-update` / `-delete` | `scripts/posthog-misc.sh scheduled ls|get|create|update|rm` |
| `early-access-feature-list` / `-retrieve` / `-create` / `-partial-update` / `-destroy` | `scripts/posthog-misc.sh early-access ls|get|create|update|rm` |
| `activity-log-list` | `scripts/posthog-misc.sh activity project` |
| `advanced-activity-logs-list` / `-filters` | `scripts/posthog-misc.sh activity advanced` / `filters` |
| `change-request-get` / `change-requests-list` | `scripts/posthog-misc.sh change-req ls|get` |
| `approval-policies-list` / `approval-policy-get` | `scripts/posthog-misc.sh approval ls|get` |
| `inbox-reports-list` / `-retrieve` / `inbox-source-configs-list` / `-retrieve` | `scripts/posthog-misc.sh inbox reports-ls|reports-get|sources-ls|sources-get` |
| `conversations-tickets-list` / `-retrieve` / `-update` | `scripts/posthog-misc.sh inbox tickets-ls|tickets-get|tickets-update` |
| `sdk-doctor-get` | `scripts/posthog-misc.sh sdk-doctor get` |
| `web-analytics-weekly-digest` | `scripts/posthog-misc.sh web-digest get` |
| `usage-metrics-list` / `-retrieve` / `-create` / `-partial-update` / `-destroy` | `scripts/posthog-misc.sh usage ls|get|create|update|rm` |
| `proxy-list` / `proxy-get` / `-create` / `-delete` / `-retry` | `scripts/posthog-misc.sh proxy ls|get|create|rm|retry` |
| `sql-variables-create` / `-update` / `-delete` | `scripts/posthog-misc.sh sql-vars create|update|rm` |
| `logs-count` / `-sparkline-query` / `-attributes-list` / `-attribute-values-list` / `-count-ranges` | `scripts/posthog-misc.sh logs count|sparkline|attrs|attr-values|count-ranges` |
| `debug-mcp-ui-apps` | `scripts/posthog-misc.sh debug-mcp ui-apps` |
| `endpoint-*` (custom HogQL endpoints) | `scripts/posthog-api.sh ... /api/projects/$PID/query_endpoints/...` (REST direct) |

### Endpoint helpers (custom HogQL endpoints / "Insight endpoints")

| MCP tool | bash equivalent |
|---|---|
| `endpoints-get-all` | `scripts/posthog-api.sh GET "/api/projects/$PID/query_endpoints/"` |
| `endpoint-get` / `endpoint-create` / `endpoint-update` / `endpoint-delete` / `endpoint-run` | `scripts/posthog-api.sh GET\|POST\|PATCH\|DELETE "/api/projects/$PID/query_endpoints/[$ID/[run/]]"` |
| `endpoint-versions` / `endpoint-materialization-status` / `endpoint-openapi-spec` | direct REST |

### MCP-only / docs / search

| MCP tool | bash equivalent |
|---|---|
| `docs-search` | *(stays in MCP)* - bash skill does not duplicate doc search; use `mcp__posthog__docs-search` when needed. |

## Beyond the MCP

These resources/operations are not exposed as MCP tools but ARE available via REST and through this skill:

| Resource | bash entrypoint | API path |
|---|---|---|
| **Logs explorer** queries (count/sparkline/attrs) | `posthog-misc.sh logs *` | `/api/projects/{id}/logs/*` |
| **Inbox tickets** patch | `posthog-misc.sh inbox tickets-update` | `/api/projects/{id}/conversations/tickets/{id}/` |
| **Project switching for the shell** | `posthog-projects.sh switch` | client-side |
| **HogQL TSV output** | `posthog-query.sh table` | client-side |
| **Annotations release helper** | `posthog-annotations.sh release` | client-side |
| **Flag rollout %** convenience | `posthog-flags.sh rollout` | derives PATCH body |
| **Flag bulk schedule** | `posthog-flags.sh schedule` | `/api/projects/{id}/scheduled_changes/` |
| **All endpoints not yet helper-wrapped** | `posthog-api.sh <METHOD> <PATH> [body]` | universal escape hatch |

## Workflow comparison

### MCP recipe: "find feature flags about checkout, disable the disabled-for-eu one"

```
mcp__posthog__feature-flag-get-all() → filter results in client → mcp__posthog__update-feature-flag(id, {active: false})
```

### bash equivalent

```bash
fid=$(scripts/posthog-flags.sh ls | jq -r '.results[] | select(.key|test("checkout"; "i")) | select(.key|contains("eu")) | .id' | head -1)
scripts/posthog-flags.sh disable "$fid"
```

### MCP recipe: "show me top errors this week and resolve the noise"

```
mcp__posthog__error-tracking-issues-list({status:"active"}) → filter → mcp__posthog__error-tracking-issues-partial-update(id, {status:"resolved"})
```

### bash equivalent

```bash
scripts/posthog-errors.sh ls | jq '.results | sort_by(.aggregations.occurrences) | reverse | .[0:5]'
scripts/posthog-errors.sh resolve <issue_id>
```

## Auth model comparison

|  | MCP | bash skill |
|---|---|---|
| Auth | `POSTHOG_PERSONAL_API_KEY` env (same key, same scopes) | `POSTHOG_PERSONAL_API_KEY` env (auto-loaded from `.env.local`) |
| Headless / CI | yes | yes |
| Multi-project context | per-tool arg or session-level switch | `cd` into project + `.env.local`, or `eval "$(scripts/posthog-projects.sh switch <id>)"` |
| Rate limits | shared org bucket | shared org bucket |
| Latency | JSON-RPC roundtrip | direct curl (lower) |
| Surface area | ~250 tools | ~250 MCP-equivalent + ~30 beyond-MCP REST endpoints |
| Greppable / version-controllable | partial | yes (helpers in `scripts/`) |
