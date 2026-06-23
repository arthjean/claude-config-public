# SQL Execution Patterns (psql + neonctl)

`neonctl` doesn't ship a query subcommand. SQL goes through `psql` against a connection string from `neonctl cs`. These patterns cover everything the MCP `run_sql` / `run_sql_transaction` tools do.

## Pattern 1 - Single statement, plain output

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -c "SELECT count(*) FROM users;"
```

Use `--no-color` on `neonctl cs` so the URI doesn't pick up ANSI codes when stdout is captured.

## Pattern 2 - Single statement, JSON output

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -At -c "SELECT row_to_json(u) FROM users u LIMIT 5;"
```

`-A` (unaligned) `-t` (tuples-only) gives clean newline-separated JSON rows. Pipe through `jq -s '.'` to wrap in an array.

## Pattern 3 - Multi-statement transaction (heredoc)

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" <<'SQL'
BEGIN;
ALTER TABLE users ADD COLUMN verified_at TIMESTAMPTZ;
UPDATE users SET verified_at = created_at WHERE email_verified = true;
COMMIT;
SQL
```

Quote the heredoc delimiter (`'SQL'`) to disable variable expansion - prevents accidental `$` interpolation in your SQL.

`psql` runs in autocommit by default. Wrap in `BEGIN; ... COMMIT;` for atomicity. To force the entire script to roll back on any error:

```bash
psql -v ON_ERROR_STOP=1 -1 "$(bunx neonctl@latest cs main --project-id $PID --no-color)" <<'SQL'
ALTER TABLE users ADD COLUMN verified_at TIMESTAMPTZ;
UPDATE users SET verified_at = created_at WHERE email_verified = true;
SQL
```

`-1` (single transaction) + `-v ON_ERROR_STOP=1` is the safe default for migrations.

## Pattern 4 - Run a .sql file

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -v ON_ERROR_STOP=1 -1 -f migration.sql
```

Or via `neonctl --psql` (passes through to psql):

```bash
bunx neonctl@latest cs main --project-id $PID \
  --psql -- -v ON_ERROR_STOP=1 -1 -f migration.sql
```

## Pattern 5 - Capture as JSON for further processing

```bash
CONN="$(bunx neonctl@latest cs main --project-id $PID --no-color)"

ROWS=$(psql "$CONN" -At -c \
  "SELECT json_agg(row_to_json(t)) FROM (SELECT id, email FROM users LIMIT 10) t;")

echo "$ROWS" | jq '.[] | .email'
```

`json_agg(row_to_json(t))` returns a single JSON array - easier to consume than line-by-line.

## Pattern 6 - Describe a table (replaces MCP `describe_table_schema`)

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -c "\d+ users"
```

For machine-readable output:

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" -At -c "
SELECT json_build_object(
  'columns', (SELECT json_agg(json_build_object(
    'name', column_name,
    'type', data_type,
    'nullable', is_nullable,
    'default', column_default
  )) FROM information_schema.columns WHERE table_name = 'users'),
  'indexes', (SELECT json_agg(indexname) FROM pg_indexes WHERE tablename = 'users'),
  'constraints', (SELECT json_agg(conname) FROM pg_constraint WHERE conrelid = 'public.users'::regclass)
);"
```

Wrapped in `scripts/neon-describe.sh`.

## Pattern 7 - List all tables (replaces MCP `get_database_tables`)

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" -At -c "
SELECT json_agg(json_build_object('schema', schemaname, 'name', tablename))
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema');"
```

Wrapped in `scripts/neon-tables.sh`.

## Pattern 8 - EXPLAIN ANALYZE (replaces MCP `explain_sql_statement`)

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" -At -c "
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM users WHERE email = 'x@example.com';"
```

`FORMAT JSON` gives a structured plan. Wrapped in `scripts/neon-explain.sh`.

**Caution:** `EXPLAIN ANALYZE` actually executes the query. For destructive statements (`UPDATE`, `DELETE`, `INSERT`) wrap in a transaction and roll back:

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" <<'SQL'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) DELETE FROM users WHERE inactive = true;
ROLLBACK;
SQL
```

## Pattern 9 - Slow queries (replaces MCP `list_slow_queries`)

Requires the `pg_stat_statements` extension. Most Neon projects have it enabled by default.

```bash
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" -At -c "
SELECT json_agg(t) FROM (
  SELECT
    query,
    calls,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round(total_exec_time::numeric, 2) AS total_ms,
    rows
  FROM pg_stat_statements
  WHERE query NOT LIKE '%pg_stat_statements%'
  ORDER BY mean_exec_time DESC
  LIMIT 20
) t;"
```

If `pg_stat_statements` isn't loaded, enable it via the Neon console (Settings → Compute → pg_stat_statements). Wrapped in `scripts/neon-slow-queries.sh`.

## Pattern 10 - `\copy` for bulk import/export

`COPY` from a file path runs server-side (won't work - Neon's compute can't read your local FS). Use `\copy` (psql client-side):

```bash
# Export
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -c "\copy users TO 'users.csv' WITH CSV HEADER"

# Import
psql "$(bunx neonctl@latest cs main --project-id $PID --no-color)" \
  -c "\copy users FROM 'users.csv' WITH CSV HEADER"
```

Always use direct (non-pooled) for `\copy` - pooler rejects it.

## Pooled vs direct - when each matters

| Operation | Use |
|---|---|
| `SELECT` (read) | pooled |
| `INSERT/UPDATE/DELETE` (single-stmt) | pooled |
| `BEGIN; ... COMMIT;` (transaction) | pooled (PgBouncer transaction mode handles this) |
| `CREATE/ALTER/DROP` (DDL) | direct |
| `COPY`, `\copy` | direct |
| `LISTEN/NOTIFY` | direct |
| Prepared statements | direct |
| `SET search_path` (session-scoped) | direct |
| Migrations (any) | direct |

Connect to pooled by adding `--pooled` to `neonctl cs`. Default is direct.

## Connection-string caching (within one shell)

Each `neonctl cs` call is a network roundtrip to Neon. For scripts that run many SQL statements, capture once:

```bash
CONN_DIRECT="$(bunx neonctl@latest cs main --project-id $PID --no-color)"
CONN_POOLED="$(bunx neonctl@latest cs main --project-id $PID --pooled --no-color)"

psql "$CONN_DIRECT" -c "..."
psql "$CONN_POOLED" -c "..."
```

The connection string contains the role password - **never log it, never commit it, never echo it**. Treat it like a secret.

## Error handling

`psql` exit codes:
- `0` - success
- `1` - fatal error (e.g., couldn't connect)
- `2` - bad command-line option
- `3` - script error (with `-v ON_ERROR_STOP=1`)

Always check `$?` after psql in a script. The helper scripts in `scripts/` propagate non-zero exits.
