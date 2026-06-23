# neonctl v2.22.0 - Full Command Reference

All commands assume `NEON_API_KEY` is exported. Replace `$PID` with your project ID. Add `--output json` to any command for machine-readable output.

## Global flags (work on every command)

| Flag | Purpose |
|---|---|
| `--api-key <key>` | Override `NEON_API_KEY` env var |
| `--output json\|yaml\|table` | Output format (default: `table`) |
| `--project-id <id>` | Project to operate on (omit if pinned via `set-context`) |
| `--org-id <id>` | Org to operate on |
| `--context-file <path>` | Use a non-default context file (per-repo workflows) |
| `--config-dir <path>` | Override `~/.config/neonctl/` |
| `--no-color` | Strip ANSI codes (use when piping to other tools) |

## projects

```bash
# List all projects
bunx neonctl@latest projects list --output json

# Create a project (region IDs: aws-us-east-1, aws-us-east-2, aws-us-west-2,
# aws-eu-central-1, aws-ap-southeast-1, aws-ap-southeast-2, azure-eastus2)
bunx neonctl@latest projects create \
  --name my-app-db \
  --region-id aws-eu-central-1 \
  --cu 0.5-2 \
  --database neondb \
  --role neondb_owner \
  --org-id org-acme-123 \
  --set-context \
  --output json

# Get a project
bunx neonctl@latest projects get $PID --output json

# Update (rename / change autoscaling / block public connections)
bunx neonctl@latest projects update $PID \
  --name renamed-project \
  --cu 1-4 \
  --block-public-connections

# Delete (irreversible after grace period)
bunx neonctl@latest projects delete $PID

# Recover within grace period
bunx neonctl@latest projects recover $PID
```

## branches

```bash
# List branches
bunx neonctl@latest branches list --project-id $PID --output json

# Create from parent HEAD
bunx neonctl@latest branches create \
  --project-id $PID \
  --name feature/add-users \
  --parent main \
  --type read_write \
  --cu 0.5-1 \
  --suspend-timeout 300 \
  --output json

# Create schema-only (zero data copy - for migration preview)
bunx neonctl@latest branches create \
  --project-id $PID \
  --name migration-preview \
  --parent main \
  --schema-only

# Create from point in time
bunx neonctl@latest branches create \
  --project-id $PID \
  --name restore-point \
  --parent "main@2026-04-01T00:00:00Z"

# Get
bunx neonctl@latest branches get feature/add-users --project-id $PID --output json

# Delete (NEVER works on default branch - Neon refuses)
bunx neonctl@latest branches delete feature/add-users --project-id $PID

# Reset to parent HEAD (DESTRUCTIVE - overwrites branch data)
bunx neonctl@latest branches reset feature/add-users \
  --parent --project-id $PID

# Reset with backup
bunx neonctl@latest branches reset feature/add-users \
  --parent --preserve-under-name feature/add-users-backup \
  --project-id $PID

# Restore (point-in-time, from another branch, or from own LSN)
bunx neonctl@latest branches restore main "feature/add-users@2026-04-20T12:00:00Z" \
  --project-id $PID

bunx neonctl@latest branches restore main "^self@0/1A2B3C4D" \
  --project-id $PID

# Rename
bunx neonctl@latest branches rename feature/add-users feature/users-v2 \
  --project-id $PID

# Set default
bunx neonctl@latest branches set-default main --project-id $PID

# Set / clear expiration (TTL - branch auto-deletes at the timestamp)
bunx neonctl@latest branches set-expiration feature/add-users \
  --expires-at 2026-05-01T00:00:00Z --project-id $PID

# Add a compute endpoint to a branch
bunx neonctl@latest branches add-compute feature/add-users --project-id $PID

# Schema diff (output is unified diff text, NOT JSON)
bunx neonctl@latest branches schema-diff main feature/add-users \
  --project-id $PID --database neondb

# Diff against parent HEAD
bunx neonctl@latest branches schema-diff feature/add-users ^parent \
  --project-id $PID

# Diff against own past LSN
bunx neonctl@latest branches schema-diff feature/add-users "^self@0/1A2B3C" \
  --project-id $PID
```

## databases

```bash
# List
bunx neonctl@latest databases list \
  --project-id $PID --branch main --output json

# Create
bunx neonctl@latest databases create \
  --project-id $PID --branch main \
  --name analytics --owner-name neondb_owner --output json

# Delete
bunx neonctl@latest databases delete analytics \
  --project-id $PID --branch main
```

`--branch` defaults to the default branch.

## roles

```bash
# List
bunx neonctl@latest roles list \
  --project-id $PID --branch main --output json

# Create with login
bunx neonctl@latest roles create \
  --project-id $PID --branch main \
  --name readonly_api --output json

# Create passwordless (no login - for RLS or grants only)
bunx neonctl@latest roles create \
  --project-id $PID --name app_role --no-login

# Delete
bunx neonctl@latest roles delete readonly_api \
  --project-id $PID --branch main
```

## connection-string (alias: `cs`)

The most-used command. Returns a `postgres://` URI ready for `psql` or any pg client.

```bash
# Direct (non-pooled), default branch, default db, default role
bunx neonctl@latest cs --project-id $PID

# Specific branch, pooled, specific role/db
bunx neonctl@latest cs feature/add-users \
  --project-id $PID \
  --role-name neondb_owner \
  --database-name neondb \
  --pooled \
  --ssl require

# Prisma (appends pgbouncer=true)
bunx neonctl@latest cs main --project-id $PID --pooled --prisma

# Read-only replica
bunx neonctl@latest cs main --project-id $PID --endpoint-type read_only

# Point-in-time
bunx neonctl@latest cs "main@2026-04-01T00:00:00Z" --project-id $PID

# Extended (host/port/user/db separately)
bunx neonctl@latest cs main --project-id $PID --extended --output json

# Launch psql inline (everything after -- is passed to psql)
bunx neonctl@latest cs main --project-id $PID --psql -- -c "SELECT version();"
```

SSL choices: `require` (default), `verify-ca`, `verify-full`, `omit`.

## operations

```bash
# List recent async operations (only `list` exists in v2.22.0 - no `get`)
bunx neonctl@latest operations list --project-id $PID --output json
```

For a single operation, use the Management API: `GET /api/v2/projects/$PID/operations/$OP_ID` (see [management-api.md](management-api.md)).

## ip-allow

```bash
# List
bunx neonctl@latest ip-allow list --project-id $PID --output json

# Add (variadic)
bunx neonctl@latest ip-allow add 203.0.113.10 203.0.113.11 \
  --project-id $PID --protected-only

# Remove
bunx neonctl@latest ip-allow remove 203.0.113.10 --project-id $PID

# Reset (replaces entire list, or clears if no IPs given)
bunx neonctl@latest ip-allow reset --project-id $PID
```

## orgs

```bash
bunx neonctl@latest orgs list --output json
```

Only `list`. Org create/delete is web-console only.

## me

```bash
bunx neonctl@latest me --output json
```

Returns authenticated user info.

## set-context

Pin project / org so you don't pass `--project-id` on every command.

```bash
# Global pin
bunx neonctl@latest set-context --project-id $PID --org-id org-acme-123

# Per-repo
bunx neonctl@latest set-context --project-id $PID \
  --context-file .neon/context.json

# Clear
bunx neonctl@latest set-context

# Inspect
cat ~/.config/neonctl/context.json
```

## auth (interactive only - avoid in agent contexts)

```bash
bunx neonctl@latest auth
```

Opens a browser for OAuth. Writes credentials to `~/.config/neonctl/credentials.json`. **Don't use this in a Claude session - set `NEON_API_KEY` instead.**

## Auth precedence

1. `--api-key <token>` flag on the command
2. `NEON_API_KEY` env var
3. `~/.config/neonctl/credentials.json` (from `auth`)

For agent use: always env var.
