---
model: opus
name: clerk-cli
description: "Manage Clerk applications, users, organizations, sessions, JWT templates, instances, and allowlists from bash via the official @clerk/dev-cli + Backend API, replacing the @clerk/agent-toolkit MCP server. Covers all agent-toolkit MCP tool equivalents (users, orgs, memberships, invitations) plus the broader Backend API surface (~25 resource categories, 100+ endpoints) the MCP doesn't expose. Authenticates with a personal CLERK_SECRET_KEY - no OAuth, no separate process. Use when the user asks to list/create/update/delete users or organizations, manage memberships, invite/revoke members, list or revoke sessions, mint sign-in/actor tokens, manage JWT templates, read or patch instance settings, manage allowlist/blocklist, or says 'clerk-cli', 'clerk CLI', 'manage my Clerk users', 'list Clerk organizations', 'Clerk Backend API'. Do NOT use when the user wants to write application code that authenticates against Clerk at runtime (use @clerk/nextjs / @clerk/clerk-react skills instead) or to manage the Clerk MCP server itself."
argument-hint: "[command or natural-language request]"
---

# clerk-cli - Clerk via bash, no MCP

Replace the `@clerk/agent-toolkit` MCP server with the official `clerk` CLI + a few `curl`-backed bash helpers for the REST gaps. Everything runs in your shell with `CLERK_SECRET_KEY`.

## Why this exists

Clerk ships **two MCP surfaces** today and neither is sufficient on its own:

1. **`mcp.clerk.com/mcp`** - exposes only 2 tools (`clerk_sdk_snippet`, `list_clerk_sdk_snippets`). It's a docs/snippet retrieval server, not a management API.
2. **`@clerk/agent-toolkit`** - wraps Backend API operations as MCP tools but only covers Users, Organizations, Memberships, and Invitations. Sessions, JWT templates, allowlists, instance settings, OAuth applications, SAML, sign-in tokens, and actor tokens are NOT exposed as MCP tools.

The official **`clerk` CLI** (`@clerk/dev-cli`) ships a `clerk api <path>` proxy that hits any Backend API endpoint with the linked instance's secret key - that closes most of the gap. The remaining ergonomics (subcommand patterns, JSON shaping, multi-instance profiles, rate-limit retry) are filled by direct REST calls against `https://api.clerk.com/v1` - that's what `scripts/` contains.

Latency is lower than MCP (no JSON-RPC roundtrip), the surface is git-greppable, and the same `CLERK_SECRET_KEY` works for both the CLI and every REST endpoint.

## Hard prerequisites

Before any command in this skill works, verify:

1. **`bunx`** - comes with bun. The user's global rule mandates bun, never npm/npx.
2. **`curl`** - install it with your OS package manager if it is not already available. Used for REST endpoints.
3. **`jq`** - used by helper scripts for JSON parsing. `sudo dnf install jq` if missing.
4. **`CLERK_SECRET_KEY`** - auto-loaded from the project's `.env.local` (then `.env`) walking up from cwd to the git repo root, or pulled from the shell environment if already exported. Generate the key at Dashboard → Configure → API Keys (per instance). Format `sk_test_...` (development) or `sk_live_...` (production). Two ways to provide it:
   ```bash
   # A) From the project - the same .env.local Next.js / @clerk/nextjs / clerk env pull use
   cd ~/code/myapp                     # has .env.local with CLERK_SECRET_KEY=...
   scripts/clerk-users.sh ls           # auto-loaded, no export needed

   # B) Headless / CI - export in the shell
   export CLERK_SECRET_KEY=sk_live_<redacted>
   ```
5. **(Optional) `CLERK_API_VERSION`** - default `2025-11-10`. Pin if you need a different stable version. Without an explicit version header the API silently resolves to legacy `2021-02-05`. Also auto-loaded from `.env(.local)` if present.

Run `scripts/clerk-ensure.sh` to verify all of the above at once, including a live auth call to `GET /v1/instance`.

## Invocation patterns (always use one of these)

**Official CLI proxy** - easiest for ad-hoc reads:
```bash
bunx clerk api /users/<id>                     # GET
bunx clerk api /users -X POST -d '{...}'       # POST
bunx clerk api ls                              # discover all available endpoints
```

**Generic REST wrapper** - better for scripts (returns clean JSON, retries on 429):
```bash
scripts/clerk-api.sh GET    /users
scripts/clerk-api.sh POST   /organizations '{"name":"Acme","created_by":"user_..."}'
scripts/clerk-api.sh PATCH  /users/$USER_ID   '{"public_metadata":{"plan":"pro"}}'
scripts/clerk-api.sh DELETE /sessions/$SID
```

**Resource-specific helpers** - best for repeatable workflows (subcommand pattern):
```bash
scripts/clerk-users.sh ls
scripts/clerk-users.sh create user@example.com Secure1234!
scripts/clerk-orgs.sh add-member org_xxx user_yyy admin
scripts/clerk-sessions.sh revoke sess_xxx
```

Never `npm install -g clerk` - use `bunx clerk` so it always pins to the latest published version.

## Multi-instance / multi-project context

Each Clerk **instance** has its own secret key - there is **no account-wide personal access token**. The skill solves this by auto-loading `CLERK_SECRET_KEY` from the project's own `.env.local` / `.env` (the same file `clerk env pull` and `@clerk/nextjs` already use), so just `cd` into a project and the right key is active.

**Resolution order** (highest precedence first):
1. **`CLERK_SECRET_KEY` already exported** in your shell - wins, useful for CI or one-shot overrides.
2. **`.env.local`** in cwd, walking up parents until a git repo root (`.git`) or `$HOME`.
3. **`.env`** in the same walk.
4. Fail with a clear message.

Same walk applies to `CLERK_API_VERSION`. Only the two `CLERK_*` keys are extracted - the rest of the file is ignored, never sourced.

```bash
# Working on app A - its .env.local has the right sk_live_*
cd ~/code/myapp-a
scripts/clerk-users.sh ls         # uses myapp-a's secret automatically

# Working on app B - different .env.local
cd ~/code/myapp-b
scripts/clerk-users.sh ls         # uses myapp-b's secret automatically

# Override for a single call (e.g. talk to a third app from any cwd)
CLERK_SECRET_KEY=sk_live_other scripts/clerk-users.sh ls

# Bootstrap a new project
cd ~/code/new-app
bunx clerk env pull               # writes .env.local with the linked instance's keys
scripts/clerk-ensure.sh           # confirms the auto-load worked
```

`scripts/clerk-ensure.sh` reports the source of the loaded key (`shell environment` vs an absolute `.env.local` path) so you can confirm which instance you're about to operate on. If you operate from outside any project (cwd has no `.env*`), export the key manually.

Helpers in `scripts/` never persist, cache, or write the key anywhere - they read it once per invocation.

## Quick map - "I want to..." → command

| Intent | Command |
|---|---|
| Verify auth + show instance info | `scripts/clerk-ensure.sh` |
| Discover all available API endpoints | `bunx clerk api ls` |
| Open the dashboard for the linked instance | `bunx clerk open` |
| List users (paginated, newest first) | `scripts/clerk-users.sh ls [limit] [offset]` |
| Get a single user | `scripts/clerk-users.sh get <user_id>` |
| Search users by email | `scripts/clerk-users.sh find <email-substring>` |
| Create a user | `scripts/clerk-users.sh create <email> <password>` |
| Update user metadata (merges) | `scripts/clerk-users.sh metadata <user_id> public '{"plan":"pro"}'` |
| Delete a user | `scripts/clerk-users.sh rm <user_id>` |
| Count total users | `scripts/clerk-users.sh count` |
| Ban / unban a user | `scripts/clerk-users.sh ban <user_id>` / `unban <user_id>` |
| List organizations | `scripts/clerk-orgs.sh ls [limit] [offset]` |
| Create an organization | `scripts/clerk-orgs.sh create <name> <created_by_user_id>` |
| Add a member to an org | `scripts/clerk-orgs.sh add-member <org_id> <user_id> <role>` |
| Update a member's role | `scripts/clerk-orgs.sh update-role <org_id> <user_id> <role>` |
| Remove a member from an org | `scripts/clerk-orgs.sh rm-member <org_id> <user_id>` |
| Invite someone to an org | `scripts/clerk-orgs.sh invite <org_id> <email> <role> <inviter_user_id>` |
| Delete an org | `scripts/clerk-orgs.sh rm <org_id>` |
| List sessions for a user | `scripts/clerk-sessions.sh ls [user_id] [status]` |
| Get session details | `scripts/clerk-sessions.sh get <session_id>` |
| Revoke a session (force-logout) | `scripts/clerk-sessions.sh revoke <session_id>` |
| Mint a session token from a template | `scripts/clerk-sessions.sh token <session_id> <template_name>` |
| List JWT templates | `scripts/clerk-jwt.sh ls` |
| Create a JWT template | `scripts/clerk-jwt.sh create <name> <claims-json> [lifetime]` |
| Update a JWT template | `scripts/clerk-jwt.sh update <id> <claims-json>` |
| Delete a JWT template | `scripts/clerk-jwt.sh rm <id>` |
| Read instance settings | `scripts/clerk-instance.sh get` |
| Patch instance restrictions (allow/block lists) | `scripts/clerk-instance.sh restrictions '{"allowlist":true}'` |
| Patch organization settings (instance-wide) | `scripts/clerk-instance.sh org-settings '{"max_allowed_memberships":10}'` |
| Send an app-level invitation | `scripts/clerk-invitations.sh create <email> [redirect_url]` |
| List invitations (pending) | `scripts/clerk-invitations.sh ls [status]` |
| Revoke an invitation | `scripts/clerk-invitations.sh revoke <invitation_id>` |
| Bulk invitations from CSV (one email per line) | `scripts/clerk-invitations.sh bulk emails.txt` |
| Add an email/phone to allowlist | `scripts/clerk-allowlist.sh add allow <identifier>` |
| List blocklist entries | `scripts/clerk-allowlist.sh ls block` |
| Remove an allowlist entry | `scripts/clerk-allowlist.sh rm allow <id>` |
| Mint a sign-in token (one-time, magic-link style) | `scripts/clerk-api.sh POST /sign_in_tokens '{"user_id":"user_xxx","expires_in_seconds":3600}'` |
| Mint a testing token (E2E test infra) | `scripts/clerk-api.sh POST /testing_tokens '{}'` |
| Pull instance config to a JSON file | `bunx clerk config pull > clerk-config.json` |
| Pull `.env.local` for the linked instance | `bunx clerk env pull` |
| Search Clerk SDK snippets | `bunx clerk skill install` (or query `mcp.clerk.com` directly) |

For the full CLI surface, see [references/commands.md](references/commands.md).
For raw REST endpoints, see [references/rest-api.md](references/rest-api.md).
For 1:1 agent-toolkit MCP tool mapping, see [references/mcp-parity.md](references/mcp-parity.md).

## Pagination workflow - Backend API uses limit/offset

Clerk's Backend API uses classic offset pagination (no cursors). `limit` is capped at **500**, default `10`. Iterate manually:

```bash
total=$(scripts/clerk-users.sh count | jq -r '.total_count')
offset=0
while [[ $offset -lt $total ]]; do
  scripts/clerk-users.sh ls 500 "$offset" | jq -c '.[]' >> all-users.ndjson
  offset=$((offset + 500))
done
```

For very large user bases (>50k), pace your calls - see "Rate limits" in Guardrails.

## Rate-limit aware retry - built into `scripts/clerk-api.sh`

Production: 1,000 req / 10s. Development: 100 req / 10s. On HTTP 429 the API returns a `Retry-After` header (seconds). The wrapper re-reads it and retries once with that delay. For higher concurrency, batch with explicit sleep:

```bash
for u in $(jq -r '.[].id' users.json); do
  scripts/clerk-users.sh metadata "$u" public '{"migrated":true}'
  sleep 0.02   # 50 req/s leaves headroom under the 100 req/s prod ceiling
done
```

## JWT template workflow - for issuing custom tokens to integrations

Clerk's JWT templates issue session tokens with custom claims for downstream services (Supabase, Hasura, etc.):

```bash
# 1. Define a template that mirrors Supabase's expected claims
CLAIMS='{"role":"authenticated","user_id":"{{user.id}}","email":"{{user.primary_email_address}}"}'
scripts/clerk-jwt.sh create supabase "$CLAIMS" 60

# 2. From the user's session, mint a JWT against that template
scripts/clerk-sessions.sh token sess_xxx supabase
# → returns {"jwt":"eyJ..."}

# 3. Update the template if claims change
scripts/clerk-jwt.sh update jtpl_xxx '{"role":"authenticated","org_id":"{{org.id}}"}'
```

## Guardrails (don't skip)

These prevent the most common destructive accidents:

1. **Never embed `CLERK_SECRET_KEY` in a script committed to git.** Always read from env. The helpers in `scripts/` enforce this.
2. **`scripts/clerk-users.sh rm <id>` is irreversible.** It deletes the user, their sessions, organization memberships, and metadata. There is no soft-delete. Use `ban` if you only need to deny access:
   ```bash
   scripts/clerk-users.sh ban user_xxx       # reversible - preserves data
   scripts/clerk-users.sh rm  user_xxx       # irreversible
   ```
3. **`scripts/clerk-instance.sh` patches affect ALL users immediately.** Changes to `allowlist_enabled`, `blocklist_enabled`, or `max_allowed_memberships` propagate without redeployment. Verify staging first.
4. **JWT template name is the lookup key for `clerk-sessions.sh token <session> <name>`.** Renaming a template breaks every integration that mints tokens against the old name. Use `update` to change claims; create a new template if the contract changes.
5. **OAuth provider credentials are dashboard-only.** The Backend API can read which providers are enabled but cannot configure client IDs / secrets. Don't try to automate Google/GitHub/etc. OAuth setup with this skill.
6. **Webhook signing secrets are write-once.** `whsec_...` is shown once at endpoint creation in the dashboard and cannot be retrieved again via API. Capture it at creation time or rotate the endpoint.
7. **Application creation is dashboard-only.** There is no `POST /v1/applications` - `clerk apps create` walks the dashboard. The bash skill operates **within** an existing instance.
8. **Rate limits are tight on invitations.** `POST /v1/invitations` caps at 100/hour, bulk at 25/hour. For migration scripts use `scripts/clerk-invitations.sh bulk` (which respects the bulk endpoint) and pace at <25 batches/hour.
9. **Pin the API version header.** Without `Clerk-API-Version: 2025-11-10` the API resolves to legacy `2021-02-05` semantics - JSON shapes differ (e.g., `payment_source_id` vs `payment_method_id`). The helpers always pin; raw `curl` must too.

## When to reach for the references

- **[references/commands.md](references/commands.md)** - Full `clerk` CLI command reference. `auth`, `init`, `env`, `config`, `api`, `apps`, `open`, `doctor`, `skill`, `update` - every subcommand and flag.
- **[references/rest-api.md](references/rest-api.md)** - Direct `curl` patterns against `https://api.clerk.com/v1`. The `clerk_api()` boilerplate, endpoint paths by resource category, pagination patterns, rate-limit handling, version pinning.
- **[references/mcp-parity.md](references/mcp-parity.md)** - Mapping table: every `@clerk/agent-toolkit` MCP tool ↔ its CLI/script equivalent + comparison vs `mcp.clerk.com` doc server.

## When NOT to use this skill

- Writing application code that authenticates against Clerk at runtime (Next.js middleware, React hooks, Express middleware) → that's regular code authoring. Use `@clerk/nextjs`, `@clerk/clerk-react`, or `@clerk/express` directly.
- Frontend-side auth flows (sign-in/sign-up/SSO redirects) → those use the **publishable key** and the Frontend API at `<instance>.clerk.accounts.dev/v1`, not the Backend API. This skill never touches the Frontend API.
- Configuring OAuth providers, billing, or creating new Clerk applications → dashboard-only.
- Continuous user-event monitoring → use Clerk webhooks (Svix) + your own listener, not bash polling against `/v1/users`.
- Rotating instance signing keys (JWKS) → dashboard-only, no API surface.
