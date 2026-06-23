# vercel CLI - Full Command Reference

All commands assume `VERCEL_TOKEN` is exported. Replace `$PID` with your project ID. The CLI doesn't expose a universal `--output json` flag; use `vercel api` (beta) or the REST API helpers in `scripts/` when you need JSON.

## Auth & global flags

```bash
# Auth - always with the token flag in agent contexts
bunx vercel@latest whoami --token "$VERCEL_TOKEN"

# Logout (rare in agent contexts)
bunx vercel@latest logout
```

| Flag | Short | Purpose |
|---|---|---|
| `--token <tok>` | `-t` | Auth token; overrides `VERCEL_TOKEN` |
| `--scope <slug\|id>` | `-S` | Team scope; overrides active scope and `VERCEL_ORG_ID` |
| `--team <slug\|id>` | `-T` | Alias for `--scope` |
| `--project <name\|id>` | - | Overrides `VERCEL_PROJECT_ID` |
| `--cwd <path>` | - | Working directory |
| `--debug` | `-d` | Verbose output |
| `--no-color` | - | Strip ANSI codes |
| `--local-config <path>` | `-A` | Path to `vercel.json` |
| `--global-config <path>` | `-Q` | Global config directory |
| `--yes` | `-y` | Skip interactive confirmations (safe to always set in agents) |

## projects (alias: `project`)

```bash
bunx vercel@latest project ls --token "$VERCEL_TOKEN"
bunx vercel@latest project add <name> --token "$VERCEL_TOKEN"
bunx vercel@latest project rm <name> --token "$VERCEL_TOKEN" --yes
bunx vercel@latest project inspect <name> --token "$VERCEL_TOKEN"

# Link the current directory to a project (writes .vercel/project.json)
bunx vercel@latest link --token "$VERCEL_TOKEN" --yes
bunx vercel@latest link --project my-app --token "$VERCEL_TOKEN" --yes
```

## deploy

```bash
# Preview deploy (default)
bunx vercel@latest deploy --token "$VERCEL_TOKEN" --yes

# Production deploy
bunx vercel@latest deploy --prod --token "$VERCEL_TOKEN" --yes

# Custom environment / target
bunx vercel@latest deploy --target=staging --token "$VERCEL_TOKEN" --yes

# Pre-build only (no deploy)
bunx vercel@latest build --prod --token "$VERCEL_TOKEN"
```

The CLI prints the deployment URL on stdout. Use `scripts/vercel-deploy.sh` to get structured `{url, id, state, target}` JSON.

## list / inspect / promote / rollback / redeploy / remove

```bash
# List recent deployments for the current project
bunx vercel@latest ls --token "$VERCEL_TOKEN"

# Filter by environment
bunx vercel@latest ls --prod --token "$VERCEL_TOKEN"

# Deep details about a deployment (URL, build settings, env, regions)
bunx vercel@latest inspect <url-or-id> --token "$VERCEL_TOKEN"

# Inspect with build logs
bunx vercel@latest inspect <url-or-id> --logs --token "$VERCEL_TOKEN"

# Wait for an in-progress deployment to finish
bunx vercel@latest inspect <url-or-id> --wait --token "$VERCEL_TOKEN"

# Promote a preview to production
bunx vercel@latest promote <url-or-id> --token "$VERCEL_TOKEN"

# Check promotion status
bunx vercel@latest promote status <project> --token "$VERCEL_TOKEN"

# Rollback production to a prior deployment
bunx vercel@latest rollback <url-or-id> --token "$VERCEL_TOKEN"
bunx vercel@latest rollback status <project> --token "$VERCEL_TOKEN"

# Re-run a deployment with the same source
bunx vercel@latest redeploy <url-or-id> --token "$VERCEL_TOKEN"

# Remove a single deployment OR every deployment of a project
bunx vercel@latest rm <url-or-id> --token "$VERCEL_TOKEN" --yes
bunx vercel@latest rm <project-name> --token "$VERCEL_TOKEN" --yes  # ALL deployments
```

## env

```bash
# List
bunx vercel@latest env ls --token "$VERCEL_TOKEN"
bunx vercel@latest env ls production --token "$VERCEL_TOKEN"

# Add (interactive - better to use scripts/vercel-env.sh in agents)
bunx vercel@latest env add NAME production --token "$VERCEL_TOKEN"

# Update
bunx vercel@latest env update NAME production --token "$VERCEL_TOKEN"

# Remove
bunx vercel@latest env rm NAME production --token "$VERCEL_TOKEN" --yes

# Pull to .env.local
bunx vercel@latest env pull --environment=production --token "$VERCEL_TOKEN"

# Run a command with env vars injected
bunx vercel@latest env run --token "$VERCEL_TOKEN" -- bun run dev
```

## domains / dns / certs

```bash
# Domains
bunx vercel@latest domains ls --token "$VERCEL_TOKEN"
bunx vercel@latest domains add example.com <project> --token "$VERCEL_TOKEN"
bunx vercel@latest domains rm example.com --token "$VERCEL_TOKEN" --yes
bunx vercel@latest domains buy example.com --token "$VERCEL_TOKEN"
bunx vercel@latest domains transfer-in example.com --token "$VERCEL_TOKEN"
bunx vercel@latest domains move example.com <other-team> --token "$VERCEL_TOKEN"
bunx vercel@latest domains inspect example.com --token "$VERCEL_TOKEN"

# DNS records
bunx vercel@latest dns ls example.com --token "$VERCEL_TOKEN"
bunx vercel@latest dns add example.com www CNAME cname.vercel-dns.com --token "$VERCEL_TOKEN"
bunx vercel@latest dns rm <record-id> --token "$VERCEL_TOKEN"

# Certificates
bunx vercel@latest certs ls --token "$VERCEL_TOKEN"
bunx vercel@latest certs issue example.com --token "$VERCEL_TOKEN"
bunx vercel@latest certs rm <cert-id> --token "$VERCEL_TOKEN"
```

## aliases

```bash
bunx vercel@latest alias ls --token "$VERCEL_TOKEN"
bunx vercel@latest alias set <deployment-url> custom.example.com --token "$VERCEL_TOKEN"
bunx vercel@latest alias rm custom.example.com --token "$VERCEL_TOKEN" --yes
```

## logs

```bash
# Runtime logs (one-shot)
bunx vercel@latest logs <deployment-url> --token "$VERCEL_TOKEN"

# Live tail
bunx vercel@latest logs <deployment-url> --follow --token "$VERCEL_TOKEN"
```

For build logs use `vercel inspect --logs <url>` or `scripts/vercel-logs.sh build <url>`.

## teams

```bash
bunx vercel@latest teams list --token "$VERCEL_TOKEN"
bunx vercel@latest teams add --token "$VERCEL_TOKEN"          # interactive
bunx vercel@latest teams invite user@example.com --token "$VERCEL_TOKEN"
bunx vercel@latest switch <team-slug> --token "$VERCEL_TOKEN" # switch active scope
```

## git & integrations

```bash
# Git connect / disconnect
bunx vercel@latest git ls --token "$VERCEL_TOKEN"
bunx vercel@latest git connect --token "$VERCEL_TOKEN"
bunx vercel@latest git disconnect github --token "$VERCEL_TOKEN"

# Marketplace integrations
bunx vercel@latest integration list --token "$VERCEL_TOKEN"
bunx vercel@latest integration add <name> --token "$VERCEL_TOKEN"
bunx vercel@latest integration remove <name> --token "$VERCEL_TOKEN"
bunx vercel@latest integration discover --token "$VERCEL_TOKEN"
bunx vercel@latest integration guide <name> --token "$VERCEL_TOKEN"
bunx vercel@latest integration balance <name> --token "$VERCEL_TOKEN"
bunx vercel@latest integration open <name> [resource] --token "$VERCEL_TOKEN"

# Integration resources (provisioned instances)
bunx vercel@latest integration-resource remove <resource> --token "$VERCEL_TOKEN"
bunx vercel@latest integration-resource disconnect <resource> [project] --token "$VERCEL_TOKEN"
```

## blob (Vercel Blob storage)

```bash
bunx vercel@latest blob list --token "$VERCEL_TOKEN"
bunx vercel@latest blob put <file> --token "$VERCEL_TOKEN"
bunx vercel@latest blob get <url-or-pathname> --token "$VERCEL_TOKEN"
bunx vercel@latest blob copy <from-url> <to-pathname> --token "$VERCEL_TOKEN"
bunx vercel@latest blob del <url-or-pathname> --token "$VERCEL_TOKEN"
```

KV and Postgres are managed via `integration` commands or REST - no dedicated CLI subcommand.

## cache

```bash
# Purge CDN or data cache
bunx vercel@latest cache purge --type cdn --token "$VERCEL_TOKEN"
bunx vercel@latest cache purge --type data --token "$VERCEL_TOKEN"

# Tag-based invalidation
bunx vercel@latest cache invalidate --tag user-profile --token "$VERCEL_TOKEN"

# Hard delete (irreversible)
bunx vercel@latest cache dangerously-delete --tag stale-tag --token "$VERCEL_TOKEN" --yes
```

## redirects & routes

```bash
bunx vercel@latest redirects list --token "$VERCEL_TOKEN"
bunx vercel@latest redirects add /old /new --status 301 --token "$VERCEL_TOKEN"
bunx vercel@latest redirects upload redirects.csv --overwrite --token "$VERCEL_TOKEN"
bunx vercel@latest redirects promote <version-id> --token "$VERCEL_TOKEN"

bunx vercel@latest routes list --token "$VERCEL_TOKEN"
bunx vercel@latest routes add --ai "Description of the route" --token "$VERCEL_TOKEN"
bunx vercel@latest routes edit "name" --dest "https://..." --token "$VERCEL_TOKEN"
bunx vercel@latest routes publish --token "$VERCEL_TOKEN"
```

## webhooks (beta)

```bash
bunx vercel@latest webhooks list --token "$VERCEL_TOKEN"
bunx vercel@latest webhooks get <id> --token "$VERCEL_TOKEN"
bunx vercel@latest webhooks create https://hooks.example.com --event deployment.succeeded --token "$VERCEL_TOKEN"
bunx vercel@latest webhooks rm <id> --token "$VERCEL_TOKEN" --yes
```

For CRUD with explicit project filtering use `scripts/vercel-webhooks.sh`.

## flags (Feature Flags)

```bash
bunx vercel@latest flags list --token "$VERCEL_TOKEN"
bunx vercel@latest flags create my-feature --token "$VERCEL_TOKEN"
bunx vercel@latest flags set my-feature --environment production --variant on --token "$VERCEL_TOKEN"
bunx vercel@latest flags open my-feature --token "$VERCEL_TOKEN"
```

## target (Custom Environments)

```bash
bunx vercel@latest target list --token "$VERCEL_TOKEN"
bunx vercel@latest deploy --target=staging --token "$VERCEL_TOKEN"
```

## rolling-release

```bash
bunx vercel@latest rolling-release configure --cfg='[config]' --token "$VERCEL_TOKEN"
bunx vercel@latest rolling-release start --dpl=<id> --token "$VERCEL_TOKEN"
bunx vercel@latest rolling-release approve --dpl=<id> --token "$VERCEL_TOKEN"
bunx vercel@latest rolling-release complete --dpl=<id> --token "$VERCEL_TOKEN"
```

## observability

```bash
bunx vercel@latest metrics vercel.request.count --token "$VERCEL_TOKEN"
bunx vercel@latest metrics schema --token "$VERCEL_TOKEN"
bunx vercel@latest activity ls --since 30d --type deployment --token "$VERCEL_TOKEN"
bunx vercel@latest alerts --all --project my-app --token "$VERCEL_TOKEN"
bunx vercel@latest usage --from 2026-01-01 --to 2026-01-31 --breakdown daily --token "$VERCEL_TOKEN"
```

## misc

```bash
# Raw authenticated REST call (beta - equivalent to scripts/vercel-api.sh)
bunx vercel@latest api /v9/projects --token "$VERCEL_TOKEN"
bunx vercel@latest api /v1/webhooks -X POST -F url=https://... -F events=deployment.succeeded --token "$VERCEL_TOKEN"

# Bisect a regression across deployments
bunx vercel@latest bisect --good <good-url> --bad <bad-url> --token "$VERCEL_TOKEN"

# Curl a deployment URL with auto-injected bypass cookie
bunx vercel@latest curl /api/private --deployment <url> --token "$VERCEL_TOKEN"

# HTTP timing breakdown
bunx vercel@latest httpstat /api/health --token "$VERCEL_TOKEN"

# Buy credits / addons / pro
bunx vercel@latest buy credits v0 100 --token "$VERCEL_TOKEN"
bunx vercel@latest buy addon siem 1 --token "$VERCEL_TOKEN"

# Inspect plan/contract
bunx vercel@latest contract --format json --token "$VERCEL_TOKEN"

# Open the project dashboard in a browser
bunx vercel@latest open --token "$VERCEL_TOKEN"

# Telemetry / guidance toggles (CLI behavior, not project state)
bunx vercel@latest telemetry status
bunx vercel@latest telemetry disable
bunx vercel@latest guidance status
```

## Auth precedence

1. `--token <tok>` flag on the command
2. `VERCEL_TOKEN` env var
3. `~/.local/share/com.vercel.cli/auth.json` (from interactive `vercel login`)

For agent use: always env var or flag. **Don't run `vercel login` in a Claude session** - it opens a browser.

## Deprecations

- `vercel secrets` - fully deprecated. Use `vercel env` (encrypted type) instead.
- `vercel switch` (no args) - interactive only. Use `--scope` flag explicitly.
