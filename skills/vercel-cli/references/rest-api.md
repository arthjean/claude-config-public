# Vercel REST API - Direct curl

For parity gaps that have no `vercel` CLI equivalent (or when you need a single endpoint without spinning up node/bun), call the API directly.

**Base URL:** `https://api.vercel.com`
**Auth:** `Authorization: Bearer $VERCEL_TOKEN` on every request
**Team scoping:** add `?teamId=<id>` (or `?slug=<team-slug>`) on every team-scoped endpoint
**OpenAPI spec (machine-readable, all endpoints):** https://openapi.vercel.sh/
**Docs:** https://vercel.com/docs/rest-api

## curl boilerplate (mirrored in scripts/_lib.sh)

```bash
vercel_api() {
  local method="${1:-GET}" path="$2"
  shift 2
  curl -fsS \
    --retry 1 --retry-delay 5 \
    -X "$method" \
    -H "Authorization: Bearer $VERCEL_TOKEN" \
    -H "Accept: application/json" \
    "https://api.vercel.com${path}" \
    "$@"
}

# Usage:
vercel_api GET    "/v2/user"
vercel_api GET    "/v9/projects?teamId=$VERCEL_TEAM_ID"
vercel_api POST   "/v1/webhooks?teamId=$VERCEL_TEAM_ID" \
                  -H "Content-Type: application/json" \
                  -d '{"url":"https://hooks.example.com","events":["deployment.succeeded"]}'
vercel_api DELETE "/v1/webhooks/wh_xxx?teamId=$VERCEL_TEAM_ID"
```

`-f` (fail on HTTP error) means the function exits non-zero on 4xx/5xx, suitable for scripts.

## Endpoint categories (33 total)

The full surface has 250+ individual endpoints across these categories. The OpenAPI spec is authoritative; this is the working set most relevant to bash automation.

| Category | Count | Notes |
|---|---:|---|
| Projects | 28 | Full CRUD, members, domains, env, pause/resume, transfer |
| Deployments | 10 | List, get, create, cancel, delete, events, files |
| Environment | 11 | Bulk ops, encrypted vars, system env |
| Edge-config | 17 | Two APIs: management + read |
| Webhooks | 4 | Create, list, get, delete |
| Domains | 6 | CRUD + verify |
| Domains-registrar | 16 | Buy, transfer, WHOIS, nameservers |
| DNS | 4 | List, add, remove records |
| Aliases | 6 | Full CRUD |
| Teams | 16 | Members, invitations, billing, access |
| Drains (Log drains) | 6 | Create, list, delete log-drain configs |
| Logs | 1 | Runtime logs query |
| Access-groups | 11 | **Pro/Enterprise only** |
| Artifacts | 6 | Remote build cache (turborepo) |
| Checks-v2 | 10 | Deployment quality checks |
| Feature-flags | 19 | Full feature flag management |
| Rolling-release | 7 | Gradual rollouts |
| Microfrontends | 5 | Microfrontend group management |
| Sandboxes-v2-beta | 40 | Vercel Sandbox compute |
| Security | 9 | Password protection, OIDC, bypass tokens |
| Edge-cache | 4 | CDN cache purge |
| Marketplace | 23 | Integration marketplace |
| Connect | 6 | Secure Compute networking |
| Certs | 4 | Certificate management |
| Billing | 3 | Usage/cost read |
| User | 4 | Current user info |
| Static-ips | 1 | **Enterprise only** |
| Project-routes | 8 | Project-level routing rules |
| Bulk-redirects | 7 | Bulk redirect management |
| Api-observability | 2 | OpenAPI / observability |

## Most-used endpoints

### User & teams (no teamId scoping needed)

```http
GET /v2/user                       # current authenticated user
GET /v2/teams                      # list teams the user belongs to
GET /v2/teams/{id-or-slug}         # team details
```

### Projects

```http
GET    /v9/projects?teamId=...                       # list
GET    /v9/projects/{idOrName}?teamId=...            # find by id or name
POST   /v10/projects?teamId=...                      # create
PATCH  /v9/projects/{idOrName}?teamId=...            # update (rename, framework, autoExposeSystemEnvs, passwordProtection, etc.)
DELETE /v9/projects/{idOrName}?teamId=...            # delete
POST   /v1/projects/{idOrName}/pause?teamId=...      # pause builds
POST   /v1/projects/{idOrName}/unpause?teamId=...    # resume
GET    /v1/projects/{id}/members?teamId=...          # list members
POST   /v1/projects/{id}/members?teamId=...          # add member
DELETE /v1/projects/{id}/members/{uid}?teamId=...    # remove member
```

### Deployments

```http
GET    /v6/deployments?projectId=&teamId=&state=READY&target=production
GET    /v13/deployments/{id}?teamId=...              # full deployment details
POST   /v13/deployments?teamId=...                   # create (files[] or gitSource)
DELETE /v13/deployments/{id}?teamId=...              # delete
POST   /v12/deployments/{id}/cancel?teamId=...       # cancel in-progress
GET    /v3/deployments/{id}/events?teamId=...        # build + runtime events (paginated, supports follow=1 SSE)
GET    /v6/deployments/{id}/files?teamId=...         # list deployment files
GET    /v7/deployments/{id}/files/{fileId}?teamId=...# single file content
POST   /v13/deployments/{id}/promote?teamId=...      # promote to production
```

Response key fields: `uid`, `url`, `state` (`BUILDING`|`ERROR`|`READY`|`CANCELED`), `readyState`, `target`, `createdAt`, `buildingAt`, `ready`, `projectId`.

### Env vars

```http
GET    /v9/projects/{idOrName}/env?teamId=...        # list
POST   /v10/projects/{idOrName}/env?teamId=...       # create  body: {key, value, type, target[]}
PATCH  /v9/projects/{idOrName}/env/{id}?teamId=...   # update single
DELETE /v9/projects/{idOrName}/env/{id}?teamId=...   # delete
```

Body schema for create:
```json
{
  "key": "DATABASE_URL",
  "value": "postgres://...",
  "type": "encrypted | plain | sensitive",
  "target": ["production", "preview", "development"],
  "gitBranch": "main"
}
```

### Edge config

Management API (api.vercel.com):
```http
GET    /v1/edge-config?teamId=...
GET    /v1/edge-config/{id}?teamId=...
POST   /v1/edge-config?teamId=...                    # body: {slug}
DELETE /v1/edge-config/{id}?teamId=...
GET    /v1/edge-config/{id}/items?teamId=...
PATCH  /v1/edge-config/{id}/items?teamId=...         # bulk upsert  body: {items: [{operation, key, value}]}
GET    /v1/edge-config/{id}/item/{key}?teamId=...
GET    /v1/edge-config/{id}/token?teamId=...         # read tokens
```

Read API (high-volume reads, separate domain):
```http
GET https://edge-config.vercel.com/{id}/item/{key}
```

### Webhooks

```http
GET    /v1/webhooks?teamId=...
POST   /v1/webhooks?teamId=...                       # body: {url, events[], projectIds[]}
GET    /v1/webhooks/{id}?teamId=...
DELETE /v1/webhooks/{id}?teamId=...
```

Common events: `deployment.created`, `deployment.succeeded`, `deployment.error`, `deployment.canceled`, `deployment.ready`, `project.created`, `project.removed`, `domain.created`, `integration-configuration.removed`.

### Log drains

```http
GET    /v1/integrations/log-drains?teamId=...
POST   /v1/integrations/log-drains?teamId=...        # body: {url, deliveryFormat, headers, sources[]}
DELETE /v1/integrations/log-drains/{id}?teamId=...
```

Delivery formats: `json`, `ndjson`, `syslog`. Sources: `static`, `lambda`, `build`, `edge`, `external`.

### Domains

```http
GET    /v5/domains?teamId=...                        # list
POST   /v5/domains?teamId=...                        # add  body: {name}
GET    /v5/domains/{domain}?teamId=...
DELETE /v6/domains/{domain}?teamId=...
POST   /v5/domains/{domain}/verify?teamId=...        # trigger verification
GET    /v4/domains/{domain}/config?teamId=...        # propagation status
GET    /v4/domains/status?name={domain}              # availability check
GET    /v4/domains/price?name={domain}               # purchase price
```

### Aliases

```http
GET    /v4/aliases?projectId=&teamId=...
POST   /v2/deployments/{id}/aliases?teamId=...       # body: {alias}
DELETE /v2/aliases/{alias}?teamId=...
```

### Security / deployment protection

```http
POST   /v1/security/protection-bypass/{projectIdOrName}?teamId=...   # create bypass token
GET    /v1/security/protection-bypass/{projectIdOrName}?teamId=...   # list
DELETE /v1/security/protection-bypass/{projectIdOrName}/{tokenId}?teamId=...
```

To use a bypass secret in a request:
```bash
curl -fsSL -H "x-vercel-protection-bypass: $SECRET" "https://my-app-xyz.vercel.app/api/private"
# Or as query param:
curl -fsSL "https://my-app-xyz.vercel.app/api/private?_vercel_share=$SECRET"
```

Password protection: managed via `PATCH /v9/projects/{idOrName}` body field `passwordProtection`. Pro/Enterprise only.

### Cache (CDN + tag-based)

```http
POST /v1/edge-cache/purge?teamId=...                 # body: {projectId, type: "cdn"|"data"}
POST /v1/edge-cache/invalidate?teamId=...            # body: {projectId, tag}
```

## Polling async operations

Many writes (deployments, project deletes, domain transfers) are async. Pattern:

```bash
DEP_ID=$(vercel_api POST "/v13/deployments?teamId=$VERCEL_TEAM_ID" -H "Content-Type: application/json" -d "$BODY" | jq -r '.id')

while true; do
  STATE=$(vercel_api GET "/v13/deployments/$DEP_ID?teamId=$VERCEL_TEAM_ID" | jq -r '.readyState')
  case "$STATE" in
    READY)    echo "deployment ready"; break ;;
    ERROR|CANCELED) echo "failed: $STATE" >&2; exit 1 ;;
    *)        sleep 3 ;;
  esac
done
```

Or use `vercel inspect <url> --wait --token $VERCEL_TOKEN` (CLI-side polling).

## Rate limits

The Vercel REST API has rate limits (not publicly documented per-tier as of April 2026). On 429 responses, `curl -f` surfaces the error as non-zero exit. The `vercel_api` helper retries once with 5s delay; for higher-volume bulk ops, batch and pace your calls. Common observed thresholds: ~100 req/min for unauthenticated, much higher for authenticated personal tokens, much higher for org-scoped tokens.

```bash
if ! response=$(vercel_api GET "/v9/projects" 2>&1); then
  if echo "$response" | grep -q '429'; then
    sleep 5
    response=$(vercel_api GET "/v9/projects")
  else
    echo "API error: $response" >&2
    exit 1
  fi
fi
```

## Token generation reminder

UI: https://vercel.com/account/tokens

**Token scopes:**
- **Full account** - covers all teams the user belongs to. Highest blast radius.
- **Single team** - scoped to one team only. Lower blast radius. Recommended for AI agents.
- **Single project** - currently not supported via the dashboard UI; team-scoped is the smallest practical unit.

Tokens have an optional expiry (recommended for agent use: 30-90 days). Stored in `VERCEL_TOKEN` env var (never in a file). Rotate via the dashboard UI - there's no "rotate" REST endpoint.
