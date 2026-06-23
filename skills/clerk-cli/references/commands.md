# `clerk` CLI command reference

The official CLI is `@clerk/dev-cli`. Invoke as `bunx clerk <subcommand>` - never `npm install -g`. The CLI is interactive-friendly (browser-based auth), but every command also accepts `CLERK_SECRET_KEY` from the environment for headless use.

Sources: [clerk.com/docs/cli](https://clerk.com/docs/cli), [Introducing Clerk CLI blog post](https://clerk.com/blog/introducing-clerk-cli).

## Top-level commands

| Command | What it does |
|---|---|
| `bunx clerk auth login` | Browser-based OAuth login. Stores credentials locally (in `~/.config/clerk/`). |
| `bunx clerk auth logout` | Clears local credentials. |
| `bunx clerk auth status` | Shows the linked account + active instance. |
| `bunx clerk init` | Auto-detects framework (Next.js, React, Vue, Nuxt, Astro, React Router, TanStack Start, Expo, Express, Fastify), installs the SDK, scaffolds middleware + auth pages. |
| `bunx clerk env pull` | Writes `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` to `.env.local` for the linked instance. |
| `bunx clerk config pull > clerk-config.json` | Exports the linked instance's full config as JSON. |
| `bunx clerk config patch <patch.json>` | Applies a JSON diff to the linked instance config (with preview). |
| `bunx clerk apps list` | Lists Clerk applications visible to the logged-in account. |
| `bunx clerk apps create <name>` | Walks the dashboard creation flow (interactive). |
| `bunx clerk open [page]` | Opens the dashboard for the linked instance. Pages: `dashboard`, `users`, `organizations`, `webhooks`, `api-keys`, etc. |
| `bunx clerk doctor` | Validates the integration in the current repo (publishable key, middleware setup, env vars). |
| `bunx clerk skill install` | Installs Clerk's "agent knowledge modules" (markdown docs/snippets) into the project. |
| `bunx clerk update` | Self-updates the CLI. |
| `bunx clerk deploy` | **Coming soon** - ship reviewed auth changes from the CLI. Not available as of Apr 2026. |

## `clerk api` - Backend API proxy

This is the most useful command for replacing MCP-style operations. It forwards any `GET`/`POST`/`PATCH`/`DELETE` to the linked instance's Backend API with the secret key already attached.

```bash
# Discover all available endpoints (includes path patterns + methods)
bunx clerk api ls

# GET (default)
bunx clerk api /users
bunx clerk api /users/user_xxx
bunx clerk api "/users?limit=50&order_by=-created_at"

# POST with body
bunx clerk api /organizations -X POST \
  -d '{"name":"Acme","created_by":"user_xxx"}'

# PATCH
bunx clerk api /users/user_xxx -X PATCH \
  -d '{"public_metadata":{"plan":"pro"}}'

# DELETE
bunx clerk api /sessions/sess_xxx -X DELETE
```

The CLI auto-injects `Authorization: Bearer <secret>` and `Clerk-API-Version: 2025-11-10` (matches the SKILL default).

**Caveat:** if you have multiple instances linked, `clerk api` uses whichever is "active." Switch with `bunx clerk auth login` and pick the right instance, or unset and re-export `CLERK_SECRET_KEY` to override.

## When to use the CLI vs. `scripts/`

| Use case | Reach for |
|---|---|
| One-off ad-hoc read | `bunx clerk api /users/user_xxx` |
| Discovering the API surface | `bunx clerk api ls` |
| Scripted, repeatable workflow | `scripts/clerk-*.sh` (rate-limit-aware, jq-formatted) |
| Multi-instance switching | Profile env files + `scripts/clerk-api.sh` |
| One-time framework scaffold | `bunx clerk init` |
| Pulling `.env.local` for local dev | `bunx clerk env pull` |
| Verifying integration in a repo | `bunx clerk doctor` |

## Auth flow nuances for headless use

The CLI's interactive `clerk auth login` won't work in CI or agent contexts. For those:

```bash
export CLERK_SECRET_KEY=sk_live_<redacted>
bunx clerk api /users   # secret key from env takes precedence
```

The CLI honors `CLERK_SECRET_KEY` even without a login session. This is the supported pattern for headless agents.

## Output format

All `clerk api` calls return raw JSON to stdout - no pretty-printing. Pipe through `jq`:

```bash
bunx clerk api /users | jq '.[] | {id, email: .email_addresses[0].email_address}'
```

The `scripts/clerk-*.sh` helpers pre-pipe through `jq .` so you get readable output by default.
