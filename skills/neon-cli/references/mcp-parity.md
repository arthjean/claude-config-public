# MCP ↔ neonctl Parity Map

The Neon MCP server exposes 26 tools. This table maps each one to its bash equivalent.

| MCP tool | bash equivalent | Notes |
|---|---|---|
| `list_projects` | `bunx neonctl@latest projects list --output json` | Full parity |
| `list_shared_projects` | `bunx neonctl@latest projects list --output json` (filter `shared:true` in jq) | Full parity (filter client-side) |
| `describe_project` | `bunx neonctl@latest projects get $PID --output json` | Full parity |
| `create_project` | `bunx neonctl@latest projects create --name X --region-id Y --output json` | Full parity |
| `delete_project` | `bunx neonctl@latest projects delete $PID` | Full parity |
| `list_organizations` | `bunx neonctl@latest orgs list --output json` | Full parity |
| `create_branch` | `bunx neonctl@latest branches create --name X --parent main --project-id $PID` | Full parity |
| `delete_branch` | `bunx neonctl@latest branches delete X --project-id $PID` | Full parity (guard against default branch in caller) |
| `describe_branch` | `bunx neonctl@latest branches get X --project-id $PID --output json` | Full parity |
| `list_branch_computes` | `curl /api/v2/projects/$PID/endpoints` | No CLI command - use Management API |
| `compare_database_schema` | `bunx neonctl@latest branches schema-diff main feature/x --project-id $PID --database neondb` | Full parity (output is unified diff text) |
| `reset_from_parent` | `bunx neonctl@latest branches reset X --parent --project-id $PID` | Full parity |
| `get_connection_string` | `bunx neonctl@latest cs main --project-id $PID` | Full parity |
| **`run_sql`** | `scripts/neon-sql.sh main "SELECT ..."` | Wraps `psql -c` |
| **`run_sql_transaction`** | `scripts/neon-tx.sh main < transaction.sql` | Wraps `psql -1 -v ON_ERROR_STOP=1` |
| **`get_database_tables`** | `scripts/neon-tables.sh main` | Wraps SQL against `pg_tables` |
| **`describe_table_schema`** | `scripts/neon-describe.sh main users` | Wraps `\d+` + `information_schema` |
| **`prepare_database_migration`** | Manual: `branches create --schema-only` + `psql -f migration.sql` | See [SKILL.md migration workflow](../SKILL.md#migration-workflow) |
| **`complete_database_migration`** | Manual: `branches schema-diff` then `psql -f migration.sql` on main | See [SKILL.md migration workflow](../SKILL.md#migration-workflow) |
| **`list_slow_queries`** | `scripts/neon-slow-queries.sh main` | Queries `pg_stat_statements` |
| **`explain_sql_statement`** | `scripts/neon-explain.sh main "SELECT ..."` | Wraps `EXPLAIN (ANALYZE, FORMAT JSON)` |
| **`prepare_query_tuning`** | Manual: branch + run EXPLAIN before/after on the branch | No native equivalent |
| **`complete_query_tuning`** | Manual: apply tuning DDL on main, drop branch | No native equivalent |
| `provision_neon_auth` | Web console only | Not a CLI capability |
| `provision_neon_data_api` | Web console only | Not a CLI capability |
| `search` | n/a (MCP-internal docs search) | Use the Neon docs site directly |
| `fetch` | n/a (MCP-internal doc fetch) | Use `WebFetch` or `curl` |
| `list_docs_resources` | n/a (MCP-internal) | - |
| `get_doc_resource` | n/a (MCP-internal) | - |

**Bold rows** are the MCP tools with no native `neonctl` command - they require the bash helpers in `scripts/`.

## Tools that map 1:1 to neonctl flags

For these, no helper is needed - call neonctl directly:

```bash
# Equivalent of MCP get_connection_string
bunx neonctl@latest cs main --project-id $PID

# Equivalent of MCP create_branch with options
bunx neonctl@latest branches create \
  --name dev/$(date +%s) \
  --parent main \
  --type read_write \
  --cu 0.5-1 \
  --project-id $PID --output json
```

## Tools that need the helpers in `scripts/`

These wrap `psql` because neonctl can't run SQL:

```bash
# run_sql equivalent
scripts/neon-sql.sh main "SELECT count(*) FROM users"

# run_sql_transaction equivalent
scripts/neon-tx.sh main <<'SQL'
ALTER TABLE users ADD COLUMN verified_at TIMESTAMPTZ;
UPDATE users SET verified_at = created_at WHERE email_verified = true;
SQL

# describe_table_schema equivalent
scripts/neon-describe.sh main users

# get_database_tables equivalent
scripts/neon-tables.sh main

# explain_sql_statement equivalent
scripts/neon-explain.sh main "SELECT * FROM users WHERE email = 'x@example.com'"

# list_slow_queries equivalent
scripts/neon-slow-queries.sh main
```

All scripts default to the project pinned via `set-context` if `--project-id` isn't passed via `NEON_PROJECT_ID` env var.

## Migration workflow - MCP vs bash

The MCP wraps the migration in two tool calls:
1. `prepare_database_migration` → returns a temp branch with the migration applied + a diff
2. User reviews → `complete_database_migration` applies on main

In bash, the same flow takes ~5 commands but is more transparent. See [SKILL.md → Migration workflow](../SKILL.md#migration-workflow) for the recipe.
