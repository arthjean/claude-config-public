---
model: opus
name: neon-cli
description: "Manage a Neon Postgres database from bash via the official neonctl CLI + psql, replacing the Neon MCP server. Covers projects, branches, databases, roles, connection strings, SQL execution (single/transaction/file), schema diffs, migrations, EXPLAIN, slow queries, and all 26 MCP tool equivalents. Use when the user asks to query/inspect/modify a Neon database, create/restore/diff branches, run migrations, get connection strings, manage roles or projects, or says 'neon-cli', 'neonctl', 'query my Neon DB', 'create a Neon branch', 'list my Neon projects'. Do NOT use when the user wants to write application code that connects to Neon at runtime (use the Drizzle/serverless driver skills instead) or to manage Neon MCP server itself."
argument-hint: "[command or natural-language request]"
---

# neon-cli - Neon Postgres via bash, no MCP

Replace the Neon MCP server with the official `neonctl` CLI + `psql` + a few bash helpers for parity gaps. Everything runs in your shell with `NEON_API_KEY`.

## Why this exists

The Neon MCP server exposes 26 tools. `neonctl` covers ~20 of them natively. The remaining 6 (`run_sql`, `run_sql_transaction`, `describe_table_schema`, `list_slow_queries`, `explain_sql_statement`, the migration pair) need bash wrappers that combine `neonctl connection-string` + `psql` (or direct calls to `https://console.neon.tech/api/v2`). That's what `scripts/` contains.

Latency is lower than MCP (no JSON-RPC roundtrip), the surface is git-greppable, and there's no separate process to manage.

## Hard prerequisites

Before any command in this skill works, verify:

1. **`bunx`** - comes with bun. The user's global rule mandates bun, never npm/npx.
2. **`psql`** - install the PostgreSQL client with your OS package manager (client only, no daemon). Required for the SQL-execution helpers.
3. **`NEON_API_KEY`** - generate at https://console.neon.tech/app/settings?modal=create_api_key. Project-scoped if managing one project, personal if managing many. Export in shell:
   ```bash
   export NEON_API_KEY=neon_api_xxxxxxxxxxxx
   ```
4. **`jq`** - used by helper scripts for JSON parsing. `sudo dnf install jq` if missing.

Run `scripts/neon-ensure.sh` to verify all four at once.

## Invocation pattern (always use this)

```bash
bunx neonctl@latest <command> [args] --output json
```

Never `npm install -g neonctl`. Never `neonctl` (assumes global install - fragile). `bunx neonctl@latest` always pins to the latest published version and respects the user's bun-only rule.

For repeated use in a single shell session, alias it:
```bash
alias n='bunx neonctl@latest'
```

## Project context - set it once, forget it

Most commands need `--project-id`. Pin it once with `set-context` to avoid passing it every time:

```bash
bunx neonctl@latest set-context \
  --project-id polished-wind-123456 \
  --org-id org-acme-123
```

Per-repo context (useful when a repo is tied to one Neon project):
```bash
bunx neonctl@latest set-context \
  --project-id polished-wind-123456 \
  --context-file .neon/context.json
```

Then on every subsequent command, pass `--context-file .neon/context.json` (or omit if you used the global location).

## Quick map - "I want to..." → command

| Intent | Command |
|---|---|
| List my projects | `bunx neonctl@latest projects list --output json` |
| Get connection string for main | `bunx neonctl@latest cs main --project-id $PID` |
| Open a psql shell | `bunx neonctl@latest cs main --project-id $PID --psql` |
| Run a single SELECT | `scripts/neon-sql.sh main "SELECT count(*) FROM users"` |
| Run a transaction | `scripts/neon-tx.sh main < migration.sql` |
| List tables | `scripts/neon-tables.sh main` |
| Describe a table | `scripts/neon-describe.sh main users` |
| Explain a query | `scripts/neon-explain.sh main "SELECT * FROM users WHERE email = 'x'"` |
| Find slow queries | `scripts/neon-slow-queries.sh main` |
| Create a dev branch | `bunx neonctl@latest branches create --name dev/$(date +%s) --parent main --project-id $PID` |
| Diff schema between branches | `bunx neonctl@latest branches schema-diff main feature/x --project-id $PID --database neondb` |
| Reset a branch to parent HEAD | `bunx neonctl@latest branches reset feature/x --parent --project-id $PID` |
| List branches as JSON | `bunx neonctl@latest branches list --project-id $PID --output json` |

For the full command surface, see [references/commands.md](references/commands.md).

## SQL execution - the canonical pattern

`neonctl` has **no `query` subcommand**. SQL goes through `psql` over a connection string from `neonctl cs`:

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -c "SELECT count(*) FROM users;"
```

The helpers in `scripts/` wrap this so you don't repeat the pattern. Multi-statement transactions, JSON output capture, and DDL guards are documented in [references/sql-execution.md](references/sql-execution.md).

**Pooled vs direct (matters):**
- DDL (`CREATE`, `ALTER`, `DROP`), `COPY`, `LISTEN/NOTIFY`, prepared statements → **direct** (no `--pooled`)
- App reads/writes, high-concurrency → **pooled** (`--pooled`)

PgBouncer in transaction mode breaks DDL and prepared statements. Migrations always use direct.

## Migration workflow (replaces MCP `prepare_database_migration` + `complete_database_migration`)

The MCP wraps this in two tool calls. In bash you orchestrate explicitly - which is actually clearer:

```bash
PID=polished-wind-123456
TS=$(date +%Y%m%d-%H%M%S)
BRANCH="migration/$TS"

# 1. Create a schema-only branch from main (zero data copy, instant)
bunx neonctl@latest branches create \
  --name "$BRANCH" --parent main --schema-only \
  --project-id "$PID" --output json

# 2. Apply the migration on the branch
psql "$(bunx neonctl@latest cs "$BRANCH" --project-id "$PID" --no-color)" \
  -f migration.sql

# 3. Review the diff against main
bunx neonctl@latest branches schema-diff main "$BRANCH" \
  --project-id "$PID" --database neondb

# 4. If diff looks right, apply on main
psql "$(bunx neonctl@latest cs main --project-id "$PID" --no-color)" \
  -f migration.sql

# 5. Cleanup
bunx neonctl@latest branches delete "$BRANCH" --project-id "$PID"
```

For complex migrations, keep the branch around for a day in case you need to inspect the pre-migration state via point-in-time restore.

## Guardrails (don't skip)

These prevent the most common destructive accidents:

1. **Never delete the default branch.** Always check first:
   ```bash
   bunx neonctl@latest branches list --project-id $PID --output json \
     | jq -e ".[] | select(.name==\"$BRANCH_TO_DELETE\") | .default | not" >/dev/null \
     || { echo "REFUSED: $BRANCH_TO_DELETE is the default branch" >&2; exit 1; }
   ```
2. **Never run DDL on a pooled connection.** Migrations always use the direct connection string (no `--pooled`).
3. **Never embed `NEON_API_KEY` in a script committed to git.** Always read from env. The helpers in `scripts/` enforce this.
4. **Watch branch count vs plan limit.** Free/Launch = 10, Scale = 25. Each extra branch is ~$1.50/month. Run `bunx neonctl@latest branches list --project-id $PID --output json | jq 'length'` before bulk-creating dev branches.
5. **Reset is destructive.** `branches reset --parent` overwrites the branch's data with the parent's. Use `--preserve-under-name backup-$(date +%s)` if you might need the pre-reset state.

## When to reach for the references

- **[references/commands.md](references/commands.md)** - Full neonctl v2.22.0 command reference. Read this when you need a flag you don't remember.
- **[references/sql-execution.md](references/sql-execution.md)** - psql patterns: heredocs, JSON capture, file execution, transactional groups, `\copy`, `\d` introspection.
- **[references/mcp-parity.md](references/mcp-parity.md)** - Mapping table: every MCP tool ↔ its CLI/script equivalent. Read this when porting a workflow that previously used MCP.
- **[references/management-api.md](references/management-api.md)** - Direct `curl` against `https://console.neon.tech/api/v2`. Used for parity gaps that have no neonctl command (slow queries, SQL-over-HTTP, restore-from-LSN, endpoint mgmt).

## When NOT to use this skill

- Writing application code that connects to Neon at runtime → use the Drizzle ORM or `@neondatabase/serverless` driver, not bash. This skill is for ops/admin tasks done by an agent in a shell.
- Continuous monitoring or alerting → use Neon's native alerting + observability, not bash polling.
- Schema generation from scratch → use Drizzle's introspection or a dedicated schema modeller, not raw psql.
