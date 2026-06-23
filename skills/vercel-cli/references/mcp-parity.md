# MCP ↔ vercel-cli Parity Map

The Vercel MCP server (`https://mcp.vercel.com`) exposes 13 tools. This table maps each one to its bash equivalent - CLI command, REST endpoint, or helper script.

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `search_documentation` | `WebFetch https://vercel.com/docs/...` | **Gap.** No REST/CLI equivalent. The MCP-only docs RAG can't be replicated server-side; use plain WebFetch. |
| `list_teams` | `bunx vercel@latest teams list --token "$VERCEL_TOKEN"` (or `scripts/vercel-api.sh GET "/v2/teams"`) | Full parity |
| `list_projects` | `bunx vercel@latest project ls --token "$VERCEL_TOKEN"` (or `scripts/vercel-api.sh GET "/v9/projects"`) | Full parity. Add `--scope <team>` for cross-team listing. |
| `get_project` | `bunx vercel@latest project inspect <name> --token "$VERCEL_TOKEN"` (or `scripts/vercel-api.sh GET "/v9/projects/<idOrName>"`) | Full parity |
| `list_deployments` | `bunx vercel@latest ls --token "$VERCEL_TOKEN"` (or `scripts/vercel-api.sh GET "/v6/deployments?projectId=..."`) | Full parity. REST has richer filters (state, target, since/until). |
| `get_deployment` | `bunx vercel@latest inspect <id-or-url> --token "$VERCEL_TOKEN"` (or `scripts/vercel-api.sh GET "/v13/deployments/<id>"`) | Full parity |
| **`get_deployment_build_logs`** | `scripts/vercel-logs.sh build <id-or-url>` | Wraps `GET /v3/deployments/<id>/events?builds=1` and reformats JSON to readable lines. CLI alternative: `vercel inspect <url> --logs`. |
| **`get_runtime_logs`** | `scripts/vercel-logs.sh runtime <id-or-url> [--follow]` | Wraps `vercel logs --follow`. REST alternative: `GET /v1/deployments/<id>/events`. |
| `check_domain_availability_and_price` | `scripts/vercel-api.sh GET "/v4/domains/status?name=example.com"` then `scripts/vercel-api.sh GET "/v4/domains/price?name=example.com"` | Two REST calls. No CLI equivalent for the price check alone. |
| `buy_domain` | `bunx vercel@latest domains buy example.com --token "$VERCEL_TOKEN"` | Full parity. Slow & async - poll `/v4/domains/<domain>` for status. |
| **`get_access_to_vercel_url`** | `scripts/vercel-bypass.sh create <project>` | Wraps `POST /v1/security/protection-bypass/<project>`. Pro/Enterprise only. |
| **`web_fetch_vercel_url`** | `scripts/vercel-bypass.sh fetch <url> <bypass-secret>` | Wraps `curl -H "x-vercel-protection-bypass: $SECRET"`. |
| `use_vercel_cli` | n/a (the MCP tool literally tells the LLM to call `vercel --help`) | This skill replaces the need entirely. |
| `deploy_to_vercel` | `scripts/vercel-deploy.sh [--prod]` | Wraps `vercel deploy --token --yes` and returns structured `{url, id, state, target}` JSON. |

**Bold rows** are the MCP tools with no thin CLI equivalent - they require the bash helpers in `scripts/`.

## Beyond MCP - REST surface this skill exposes that the MCP doesn't

The Vercel MCP intentionally exposes only 13 tools. The bash skill goes further by leveraging the full REST surface:

| Capability | bash entrypoint | REST endpoint |
|---|---|---|
| Env var CRUD (encrypted/plain/sensitive, per-target) | `scripts/vercel-env.sh` | `/v9/projects/<id>/env` |
| Edge config items (bulk upsert/delete) | `scripts/vercel-edge-config.sh` | `/v1/edge-config/<id>/items` |
| Webhook CRUD | `scripts/vercel-webhooks.sh` | `/v1/webhooks` |
| Log drain CRUD | `scripts/vercel-api.sh ... /v1/integrations/log-drains` | `/v1/integrations/log-drains` |
| Domain transfers, DNS records, certificates | `bunx vercel@latest domains/dns/certs ...` | `/v4-v6/domains`, `/v4/dns`, `/v9/certs` |
| Cache purge & tag-based invalidation | `bunx vercel@latest cache ...` | `/v1/edge-cache/...` |
| Project pause/unpause | `scripts/vercel-api.sh POST "/v1/projects/<id>/pause"` | `/v1/projects/<id>/pause` |
| Aliases (deployment ↔ custom domain) | `bunx vercel@latest alias ...` | `/v2/deployments/<id>/aliases`, `/v4/aliases` |
| Feature flags | `bunx vercel@latest flags ...` | `/v1/feature-flags/*` |
| Rolling releases | `bunx vercel@latest rolling-release ...` | `/v1/rolling-release/*` |
| Activity log / audit | `bunx vercel@latest activity ls ...` | `/v1/activity` |
| Usage / billing | `bunx vercel@latest usage ...` | `/v1/billing/*` |
| Integration marketplace | `bunx vercel@latest integration ...` | `/v1/integrations/*` |
| Generic raw call | `scripts/vercel-api.sh <METHOD> <PATH> [body]` | any of 250+ endpoints |

## Workflows that previously required MCP

### MCP recipe: "What broke in my last production deploy?"
```
list_deployments(projectId, target=production) →
get_deployment(latestId) →
get_deployment_build_logs(latestId)
```

### bash equivalent
```bash
LATEST=$(bunx vercel@latest ls --prod --token "$VERCEL_TOKEN" | head -n2 | tail -n1 | awk '{print $2}')
bunx vercel@latest inspect "$LATEST" --token "$VERCEL_TOKEN"
scripts/vercel-logs.sh build "$LATEST"
```

### MCP recipe: "Share this preview deployment with a non-team-member"
```
get_access_to_vercel_url(deploymentUrl) →   # returns bypass token
[append ?_vercel_share=<token> to URL]
```

### bash equivalent
```bash
SECRET=$(scripts/vercel-bypass.sh create my-app | jq -r '.secret')
echo "https://my-preview-xyz.vercel.app/?_vercel_share=$SECRET"
# Revoke when done:
scripts/vercel-bypass.sh rm my-app <token-id>
```

## Auth model difference

| | MCP | bash skill |
|---|---|---|
| Auth | OAuth (browser flow) | Personal access token (`VERCEL_TOKEN`) |
| Headless | No (requires interactive consent on first connect) | Yes |
| Token rotation | Auto via OAuth refresh | Manual via dashboard |
| Scope | All teams the user grants | Whatever the token was created with (account-wide or single-team) |
| Latency per call | ~200-500ms (JSON-RPC over HTTP) | ~50-150ms (direct HTTPS) |
| Process model | Separate MCP server | Same shell, no extra process |
