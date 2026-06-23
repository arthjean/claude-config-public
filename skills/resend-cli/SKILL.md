---
model: opus
name: resend-cli
description: "Manage every Resend resource - transactional and broadcast emails, batch sends, scheduled emails, received (inbound) emails, attachments, sending domains and DKIM verification, API keys (full_access and sending_access), contacts, contact properties, segments, subscription topics, broadcasts, templates (publish, duplicate), webhooks (including local tunnel), automations (CRUD + stop), automation events (send/trigger), event schemas, and API request logs - from bash via the Resend REST API at api.resend.com, replacing the resend-mcp server. Covers all ~50+ resend-mcp tools plus the broader REST surface the MCP doesn't expose: automations CRUD, events/event-schemas, logs, and email attachment retrieval. Authenticates with a single RESEND_API_KEY (re_*) - no OAuth, no separate MCP process. Honors User-Agent header (required), Idempotency-Key (on /emails and /emails/batch only), and 429 Retry-After. Use when the user asks to send an email, list/query/create/update/delete any Resend resource, manage domains or DKIM, schedule or cancel emails, manage contacts/audiences/segments/topics, create or send broadcasts, manage webhooks, trigger or define automations, inspect API logs, switch Resend teams or domains, or says 'resend-cli', 'resend CLI', 'send via Resend', 'Resend API', 'manage my Resend domains', 'replace Resend MCP'. Do NOT use when the user wants to write application code that calls Resend at runtime from a server (use the resend Node/Python/Ruby SDK in code instead), to manage the Resend MCP server itself, or to deal with non-Resend email providers (Postmark, SendGrid, SES)."
argument-hint: "[command or natural-language request]"
---

# resend-cli - Resend via bash, no MCP

Replace the `resend/resend-mcp` server with direct `curl` calls against the Resend REST API. Everything runs in your shell with `RESEND_API_KEY`.

## Why this exists

The official `resend-mcp` server covers ~50 tools across emails, contacts, broadcasts, templates, domains, segments, topics, contact properties, API keys, and webhooks. But the public REST surface is broader - automations, automation events, event schemas, request logs, and per-attachment retrieval are absent from the MCP. Bash + REST gives:

- **Lower latency** - no JSON-RPC roundtrip, no separate MCP process to start.
- **Greppable surface** - every endpoint is a line in a shell script in your repo.
- **Same auth as the MCP** - `RESEND_API_KEY` (`re_*`) is exactly what the MCP uses.
- **Wider coverage** - automations CRUD, events/event-schemas, and logs are exposed here as first-class subcommands.

The official `resend-cli` is mature and excellent for interactive use (especially `webhooks listen` for local tunnels and React Email `.tsx` rendering), but it's a separate process and a separate dependency tree. This bash skill is the management-API counterpart that lives alongside it: use the official CLI for tunnels and `.tsx` rendering, use this skill for everything else.

## Hard prerequisites

1. **`bun`** - global rule mandates bun, never npm/npx. Used for the optional `resend-cli` (only needed for `webhooks listen` and React Email rendering).
2. **`curl`** - install it with your OS package manager if it is not already available. Every API call goes through curl.
3. **`jq`** - required for JSON shaping. `sudo dnf install jq` if missing.
4. **`RESEND_API_KEY`** - auto-loaded from the project's `.env.local` (then `.env`) walking up to the git repo root, or pulled from the shell environment if exported. Format `re_...`. Two ways to provide it:
   ```bash
   # A) From a project - the same .env.local your app uses for the resend SDK
   cd ~/code/myapp                          # .env.local has RESEND_API_KEY=re_...
   scripts/resend-emails.sh ls              # auto-loaded, no export needed

   # B) Headless / CI / global use - export in the shell
   export RESEND_API_KEY=re_<redacted>
   ```
5. **(Optional) `RESEND_FROM`** - default sender used by `resend-emails.sh send` and `resend-broadcasts.sh create` when `--from` is omitted. Format `'Acme <hi@acme.com>'`.
6. **(Optional) `RESEND_HOST`** - defaults to `https://api.resend.com`. Override only for proxies, mocks, or dev tunnels.
7. **(Optional) `RESEND_USER_AGENT`** - Resend **requires** a non-empty User-Agent (error code 1010 / 403 if missing). The skill sends `resend-cli-skill/1.0` by default. Set the env var to override.

Generate an API key at **Resend → Settings → API Keys → "+ Create API Key"**. Two permission tiers:
- **`full_access`** - manage everything (domains, contacts, broadcasts, templates, webhooks, automations, api-keys).
- **`sending_access`** - send emails only, optionally scoped to a single `domain_id`. Use these in your production app; use `full_access` for ops/admin scripts.

Keys can be created/listed/deleted via the API (no rotation - delete + recreate). The raw token is shown **once** at creation time.

Run `scripts/resend-ensure.sh` to verify prerequisites, including a live call to `GET /domains` that prints your team's domains and probes whether the key is `full_access` or `sending_access`.

## Invocation patterns (always use one of these)

**Generic REST wrapper** - best for ad-hoc reads + writes (returns clean JSON, retries on 429):
```bash
scripts/resend-api.sh GET    /domains
scripts/resend-api.sh GET    "/emails?limit=20"
scripts/resend-api.sh POST   /emails '{"from":"a@b.com","to":["c@d.com"],"subject":"hi","html":"<p>hi</p>"}'
scripts/resend-api.sh PATCH  /domains/abc-123 '{"name":"new-name"}'
scripts/resend-api.sh DELETE /api-keys/xyz
```

For idempotent POSTs to `/emails` or `/emails/batch` (Resend supports `Idempotency-Key` on these two endpoints only, 256 chars, 24h TTL):
```bash
RESEND_IDEMPOTENCY_KEY=signup-1234 scripts/resend-api.sh POST /emails "$body"
```

**Resource-specific helpers** - best for repeatable workflows (subcommand pattern):
```bash
scripts/resend-emails.sh send --to user@x.com --subject Hi --html '<p>Hi</p>'
scripts/resend-domains.sh verify dom-abc-123
scripts/resend-contacts.sh create --email a@b.com --first Ada --last Lovelace --prop plan=pro
scripts/resend-broadcasts.sh send broadcast-id-xyz --scheduled-at "in 1 hour"
scripts/resend-webhooks.sh create --url https://my.app/hook --events email.delivered,email.bounced
scripts/resend-logs.sh ls --status 422 --limit 50 | jq '.path'
```

**Official `resend-cli`** - use ONLY when bash cannot do the job (local tunnel, React Email `.tsx` rendering):
```bash
bunx --bun resend-cli webhooks listen --port 3000             # local webhook tunnel
bunx --bun resend-cli send --from a@b.com --to c@d.com email.tsx  # renders React Email template
bunx --bun resend-cli doctor                                  # diagnose CLI env
```

The skill exposes `scripts/resend-webhooks.sh listen` as a thin wrapper around `bunx resend-cli webhooks listen`.

## Multi-team / multi-environment context

Resend has a **Teams** concept - each team is isolated (its own keys, domains, contacts, billing). The recommended pattern: one `.env.<team>` file per team, sourced before running scripts.

```bash
# .env.acme - production
export RESEND_API_KEY=re_acme_full_access_key
export RESEND_FROM='Acme <hi@acme.com>'

# .env.staging - staging team
export RESEND_API_KEY=re_staging_full_access_key
export RESEND_FROM='Acme Staging <hi@staging.acme.com>'

# switch teams
set -a; source .env.acme; set +a
scripts/resend-emails.sh ls
```

The `.env(.local)` auto-loader walks up to the git repo root and stops there, so each repo can carry its own team key safely.

## Quick map - "I want to..." → command

| Intent | Command |
|---|---|
| Verify environment + auth | `scripts/resend-ensure.sh` |
| Send a single email | `scripts/resend-emails.sh send --to addr --subject S --html '<p>...</p>'` |
| Send with idempotency | `scripts/resend-emails.sh send ... --idempotency-key signup-42` |
| Send a batch (≤100, no attachments, no scheduled_at) | `scripts/resend-emails.sh batch @emails.json` |
| Schedule an email | `scripts/resend-emails.sh send ... --scheduled-at "in 1 hour"` |
| Cancel a scheduled email | `scripts/resend-emails.sh cancel <id>` |
| Reschedule a scheduled email | `scripts/resend-emails.sh reschedule <id> "2026-06-01T10:00:00Z"` |
| List recent sent emails | `scripts/resend-emails.sh ls --limit 50` |
| Get a sent email | `scripts/resend-emails.sh get <id>` |
| Get a sent email's attachments | `scripts/resend-emails.sh attachments <id>` *(MCP gap - exposed here)* |
| List inbound received emails | `scripts/resend-received.sh ls` |
| Download an inbound attachment | `scripts/resend-received.sh attachment <eid> <aid> --out file.pdf` |
| Add a sending domain | `scripts/resend-domains.sh create --name acme.com --region us-east-1` |
| Show DNS records for a domain | `scripts/resend-domains.sh dns <domain_id>` |
| Verify a domain | `scripts/resend-domains.sh verify <domain_id>` |
| Create an API key (sending-scoped) | `scripts/resend-api-keys.sh create --name CI --permission sending_access --domain <dom_id>` |
| List API keys | `scripts/resend-api-keys.sh ls` |
| Add a contact | `scripts/resend-contacts.sh create --email a@b.com --first A --last B --prop plan=pro` |
| List contacts | `scripts/resend-contacts.sh ls` |
| Add a contact to a segment | `scripts/resend-contacts.sh add-segment <cid> <seg_id>` |
| Update a contact's topic subs | `scripts/resend-contacts.sh set-topics <cid> @topics.json` |
| Create a custom contact property | `scripts/resend-contact-properties.sh create --name plan --type string` |
| Create a segment | `scripts/resend-segments.sh create --name VIPs --filter @filter.json` |
| List contacts in a segment | `scripts/resend-segments.sh contacts <seg_id>` |
| Create a subscription topic | `scripts/resend-topics.sh create --name marketing --description "..."` |
| Create a broadcast | `scripts/resend-broadcasts.sh create --subject ... --html @body.html --segment <seg_id>` |
| Send a broadcast | `scripts/resend-broadcasts.sh send <bid>` (or with `--scheduled-at`) |
| Create a template | `scripts/resend-templates.sh create --name Welcome --subject ... --html @welcome.html` |
| Publish a template | `scripts/resend-templates.sh publish <tid>` |
| Duplicate a template | `scripts/resend-templates.sh duplicate <tid> --name "Welcome v2"` |
| Create a webhook | `scripts/resend-webhooks.sh create --url ... --events email.delivered,email.bounced` |
| Local webhook tunnel | `scripts/resend-webhooks.sh listen --port 3000` (delegates to `bunx resend-cli`) |
| Create an automation | `scripts/resend-automations.sh create --name onboarding --trigger user.created` *(MCP gap)* |
| Trigger an automation event | `scripts/resend-events.sh send --event user.created --email a@b.com --payload '{"plan":"pro"}'` *(MCP gap)* |
| Stop a running automation | `scripts/resend-automations.sh stop <aid>` *(MCP gap)* |
| Inspect API request logs | `scripts/resend-logs.sh ls --status 422 --limit 50` *(MCP gap)* |
| Ad-hoc REST call | `scripts/resend-api.sh GET /domains` |

## Key facts (operational)

- **Base URL:** `https://api.resend.com` (HTTPS only).
- **Rate limit:** 5 req/sec per team (across all keys). 429 responses include `Retry-After: <seconds>` - the skill retries automatically up to 3 times, but clamps at 60s to avoid sleeping for daily/monthly quota resets.
- **Pagination:** cursor-based. Response shape: `{ object: "list", has_more: bool, data: [...] }`. `scripts/_lib.sh:resend_paginate` follows `has_more` automatically using `data[-1].id` as the next `after=` cursor.
- **Idempotency-Key:** supported on `POST /emails` and `POST /emails/batch` only (256 chars max, 24h TTL). Pass via `--idempotency-key <key>` on `resend-emails.sh send` or `RESEND_IDEMPOTENCY_KEY` env var on `resend-api.sh`.
- **User-Agent:** required - calls without it get a 403 with error code 1010. The skill always sends one.
- **Batch caveat:** `POST /emails/batch` accepts up to 100 emails but **forbids** `attachments` and `scheduled_at` on any item. The skill warns when those fields are present in the array.
- **Attachment size:** 40 MB total per email. Inline images via CID (`{filename, content_id, content}`) are supported.
- **No API version header.** Resend uses unversioned paths; calendar versioning is planned but not shipped as of May 2026. Watch [resend.com/changelog](https://resend.com/changelog) for breaking changes.

## References

- [references/rest-api.md](references/rest-api.md) - full REST endpoint catalog (every resource, every method, every path), auth, pagination loop, error code table.
- [references/mcp-parity.md](references/mcp-parity.md) - MCP tool ↔ bash command mapping. Highlights the **MCP gaps** this skill fills (automations, events, logs, attachments retrieval).
- [references/cli-parity.md](references/cli-parity.md) - official `resend-cli` command ↔ bash mapping. When to delegate to the CLI (tunnels, `.tsx` rendering) vs use bash.
- [references/commands.md](references/commands.md) - flat quick-reference index of every bash subcommand exposed.
