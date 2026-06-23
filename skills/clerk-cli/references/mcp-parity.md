# MCP ↔ clerk-cli Parity Map

Clerk ships **two distinct MCP surfaces**, each with a different scope. This file maps every tool from both to its bash equivalent in this skill.

## Surface 1 - `mcp.clerk.com/mcp` (docs/snippets server)

Streamable HTTP MCP at `https://mcp.clerk.com/mcp`. **Public, no secret key required.** Exposes 2 tools.

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `clerk_sdk_snippet` | `bunx clerk skill install` (downloads SDK snippet bundles into the project) **or** `WebFetch https://clerk.com/docs/...` | The MCP returns one snippet by name - no public REST equivalent. |
| `list_clerk_sdk_snippets` | n/a - the bundles are documented at [clerk.com/docs/guides/ai/overview](https://clerk.com/docs/guides/ai/overview) | Bundles: `b2b-saas`, `waitlist`, `auth-basics`, `custom-flows`, `organizations`, `server-side`. |

This is a **documentation assistant** - there is no overlap with the management Backend API. If you only need code snippets, keep the docs MCP enabled and lean on this skill for everything else.

## Surface 2 - `@clerk/agent-toolkit` (Backend API ops MCP)

NPM package: [`@clerk/agent-toolkit`](https://github.com/clerk/javascript/tree/HEAD/packages/agent-toolkit). Local MCP via `npx @clerk/agent-toolkit -p local-mcp`. **Requires `CLERK_SECRET_KEY`.** This is what this skill replaces.

The toolkit exposes ~17 tools across 4 categories. Every one has a bash equivalent below. **Bold rows** are tools where the bash version exposes more functionality than the MCP.

### Users

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `getUser` | `scripts/clerk-users.sh get <user_id>` | Full parity |
| `getUserList` | `scripts/clerk-users.sh ls [limit] [offset] [order_by]` | Full parity + explicit pagination + ordering |
| `getUserCount` | `scripts/clerk-users.sh count` | Full parity |
| `createUser` | `scripts/clerk-users.sh create <email> <password> [first] [last]` | Full parity |
| **`updateUser`** | `scripts/clerk-users.sh update <id> <patch-json>` **or** `scripts/clerk-users.sh metadata <id> {public\|private\|unsafe} <merge-json>` | The `metadata` subcommand does a deep merge so you don't clobber existing keys - the MCP requires you to pass the full new metadata object. |
| `deleteUser` | `scripts/clerk-users.sh rm <user_id>` | Full parity. Irreversible. |

### Organizations

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `getOrganization` | `scripts/clerk-orgs.sh get <org_id>` | Full parity |
| `getOrganizationList` | `scripts/clerk-orgs.sh ls [limit] [offset]` | Full parity |
| `createOrganization` | `scripts/clerk-orgs.sh create <name> <created_by_user_id> [slug]` | Full parity |
| `updateOrganization` | `scripts/clerk-orgs.sh update <org_id> <patch-json>` **or** `metadata <org_id> {public\|private} <merge-json>` | Same metadata-merge advantage |
| `deleteOrganization` | `scripts/clerk-orgs.sh rm <org_id>` | Full parity |

### Memberships

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `getOrganizationMembershipList` | `scripts/clerk-orgs.sh members <org_id> [limit] [offset]` | Full parity |
| `createOrganizationMembership` | `scripts/clerk-orgs.sh add-member <org_id> <user_id> <role>` | Full parity |
| `updateOrganizationMembership` | `scripts/clerk-orgs.sh update-role <org_id> <user_id> <new_role>` | Full parity |
| `deleteOrganizationMembership` | `scripts/clerk-orgs.sh rm-member <org_id> <user_id>` | Full parity |

### Invitations

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `createInvitation` | `scripts/clerk-invitations.sh create <email> [redirect] [meta]` | App-level invitation |
| **`getInvitationList`** | `scripts/clerk-invitations.sh ls [status] [limit] [offset]` | Full parity + status filter |
| `revokeInvitation` | `scripts/clerk-invitations.sh revoke <invitation_id>` | Full parity |
| **(MCP gap)** | `scripts/clerk-invitations.sh bulk <emails-file> [redirect]` | The MCP does not expose `POST /invitations/bulk`. This skill does. |

## Beyond the agent-toolkit MCP

The agent-toolkit only covers **users, orgs, memberships, invitations**. This skill adds full coverage for the rest of the Backend API:

| Resource category | bash entrypoint | Backend API path |
|---|---|---|
| Sessions (list / revoke / verify / mint JWT) | `scripts/clerk-sessions.sh` | `/sessions/*` |
| JWT templates | `scripts/clerk-jwt.sh` | `/jwt_templates/*` |
| Instance settings + restrictions | `scripts/clerk-instance.sh` | `/instance`, `/instance/restrictions`, `/instance/organization_settings` |
| Allowlist / blocklist | `scripts/clerk-allowlist.sh` | `/allowlist_identifiers`, `/blocklist_identifiers` |
| Domains + redirect URLs | `scripts/clerk-domains.sh` | `/domains`, `/redirect_urls` |
| OAuth applications (Clerk as IdP) | `scripts/clerk-oauth.sh apps-*` | `/oauth_applications/*` |
| SAML connections | `scripts/clerk-oauth.sh saml-*` | `/saml_connections/*` |
| Sign-in / actor / testing tokens | `scripts/clerk-oauth.sh signin-token / actor-token / testing-token` | `/sign_in_tokens`, `/actor_tokens`, `/testing_tokens` |
| Org domains (B2B SAML enrollment) | `scripts/clerk-orgs.sh domains / add-domain / rm-domain` | `/organizations/{id}/domains` |
| Bulk org invitations | `scripts/clerk-orgs.sh invite` (loop in shell) | `/organizations/{id}/invitations/bulk` |
| User ban / unban / lock / unlock | `scripts/clerk-users.sh ban\|unban\|lock\|unlock` | `/users/{id}/{action}` |
| User-scoped session revocation | `scripts/clerk-sessions.sh revoke-user-sessions <user_id>` | (loops `/sessions?user_id=…&status=active` + revoke) |
| Generic raw call | `scripts/clerk-api.sh <METHOD> <PATH> [body]` | any of 100+ endpoints |

## Workflow comparison

### MCP recipe: "List inactive users from the last 6 months and revoke their sessions"

```
getUserList(limit=500, offset=0) →
  filter where last_sign_in_at < cutoff →
for each user:
  // No bulk session-revoke MCP tool - must call session APIs separately
```

### bash equivalent

```bash
cutoff=$(date -d '6 months ago' +%s)000
inactive=$(scripts/clerk-api.sh GET "/users?limit=500&order_by=-created_at" \
  | jq --argjson c "$cutoff" -r '.[] | select(.last_sign_in_at == null or .last_sign_in_at < $c) | .id')

for u in $inactive; do
  scripts/clerk-sessions.sh revoke-user-sessions "$u"
done
```

### MCP recipe: "Promote user to org admin"

```
getOrganizationMembershipList(orgId) →
  find member by user_id →
updateOrganizationMembership(membershipId, {role: "org:admin"})
```

### bash equivalent

```bash
scripts/clerk-orgs.sh update-role org_xxx user_yyy org:admin
```

(One call instead of two - the bash helper PATCHes by `{org_id, user_id}` directly.)

## Auth model difference

| | agent-toolkit MCP | bash skill |
|---|---|---|
| Auth | `CLERK_SECRET_KEY` env var | `CLERK_SECRET_KEY` env var |
| Headless | Yes | Yes |
| Multi-instance | Single instance per process - restart to switch | Switch with `export CLERK_SECRET_KEY=...` or profile files |
| Token rotation | Manual via dashboard | Manual via dashboard |
| Process model | Separate MCP server process | Same shell, no extra process |
| Latency per call | ~100-300ms (JSON-RPC over stdio/HTTP) | ~50-150ms (direct HTTPS) |
| Resource coverage | Users, orgs, memberships, invitations only | Full Backend API (~25 categories, 100+ endpoints) |
| Custom workflows | Limited to predefined tools | Arbitrary `clerk-api.sh METHOD PATH BODY` |
| Discoverability | Static tool list | `bunx clerk api ls` returns the live endpoint list |
