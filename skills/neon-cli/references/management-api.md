# Neon Management API v2 - Direct curl

For parity gaps that have no `neonctl` equivalent (or when you need a single endpoint without spinning up `psql`), call the API directly.

**Base URL:** `https://console.neon.tech/api/v2`
**Auth:** `Authorization: Bearer $NEON_API_KEY` on every request
**Docs:** https://api-docs.neon.tech/reference/

## curl boilerplate

```bash
neon_api() {
  local method="${1:-GET}" path="$2"
  shift 2
  curl -fsS -X "$method" \
    -H "Authorization: Bearer $NEON_API_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "https://console.neon.tech/api/v2${path}" \
    "$@"
}

# Usage:
neon_api GET "/projects/$PID/operations/$OP_ID"
neon_api POST "/projects/$PID/branches" -d '{"branch":{"name":"x","parent_id":"br-..."}}'
```

`-f` (fail on HTTP error) means the function exits non-zero on 4xx/5xx, suitable for scripts.

## Endpoints used by parity gaps

### Get a single operation (neonctl only has list)

```
GET /projects/{project_id}/operations/{operation_id}
```

Useful for polling async ops (e.g., branch creation status):

```bash
OP_ID=$(bunx neonctl@latest branches create --name x --parent main --project-id $PID --output json \
  | jq -r '.operations[0].id')

while true; do
  STATUS=$(neon_api GET "/projects/$PID/operations/$OP_ID" | jq -r '.operation.status')
  case "$STATUS" in
    finished) echo "done"; break ;;
    failed)   echo "failed"; exit 1 ;;
    *)        sleep 1 ;;
  esac
done
```

### List branch computes (no neonctl equivalent)

```
GET /projects/{project_id}/endpoints
```

Filter by branch in jq:

```bash
neon_api GET "/projects/$PID/endpoints" \
  | jq --arg br "$BRANCH_ID" '.endpoints[] | select(.branch_id == $br)'
```

### Update compute settings (e.g., autoscale, suspend timeout)

```
PATCH /projects/{project_id}/endpoints/{endpoint_id}
```

```bash
neon_api PATCH "/projects/$PID/endpoints/$EP_ID" -d '{
  "endpoint": {
    "autoscaling_limit_min_cu": 0.25,
    "autoscaling_limit_max_cu": 4,
    "suspend_timeout_seconds": 300
  }
}'
```

### Restore branch (point-in-time)

`neonctl branches restore` covers this. Direct API:

```
POST /projects/{project_id}/branches/{branch_id}/restore
```

```bash
neon_api POST "/projects/$PID/branches/$BR_ID/restore" -d '{
  "source_branch_id": "br-other-branch",
  "source_timestamp": "2026-04-01T00:00:00Z"
}'
```

### VPC endpoint management (no neonctl)

```
GET    /organizations/{org_id}/vpc/endpoints
POST   /organizations/{org_id}/vpc/endpoints
DELETE /organizations/{org_id}/vpc/endpoints/{vpc_endpoint_id}
```

## SQL-over-HTTP - the catch

Some Neon docs reference a `POST /projects/{id}/query` endpoint for arbitrary SQL. **This isn't documented in the public Management API reference and isn't a stable contract.** The MCP server's `run_sql` tool actually uses the `@neondatabase/serverless` JavaScript driver (HTTP fetch mode against a per-branch endpoint), not the Management API.

**Recommendation:** for SQL execution, use `psql` via `scripts/neon-sql.sh`. It's faster than spinning up node/bun for the serverless driver and works with any future Postgres feature.

If you genuinely need SQL-over-HTTP without psql (e.g., serverless function with no postgres client), use the `@neondatabase/serverless` driver:

```ts
import { neon } from "@neondatabase/serverless";
const sql = neon(process.env.DATABASE_URL!);
const rows = await sql`SELECT count(*) FROM users`;
```

Or PostgREST via the Neon Data API (REST-style, not arbitrary SQL): https://neon.com/docs/data-api/get-started.

## Rate limits

The Neon Management API has rate limits (not publicly documented per-tier as of April 2026). On 429 responses, back off exponentially and retry. The `curl -f` flag will surface the 429 as a non-zero exit; capture and handle:

```bash
if ! response=$(neon_api GET "/projects" 2>&1); then
  if echo "$response" | grep -q '429'; then
    sleep 5
    response=$(neon_api GET "/projects")
  else
    echo "API error: $response" >&2
    exit 1
  fi
fi
```

## API key generation reminder

UI: https://console.neon.tech/app/settings?modal=create_api_key

**Key types:**
- **Personal** - full access to your account's projects. Use for personal-use agents.
- **Organization** - admin-only, scoped to one org. Use for org-wide automation.
- **Project-scoped** - member-level, single project, **cannot delete the project**. Best blast-radius containment for AI agents managing one project.

Always prefer project-scoped keys for AI agent use. Stored in `NEON_API_KEY` env var (never in a file).
