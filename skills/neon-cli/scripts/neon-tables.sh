#!/usr/bin/env bash
# neon-tables.sh - list user tables in a database, returning JSON.
# Replaces MCP `get_database_tables`.
#
# Usage:
#   ./neon-tables.sh <branch> [database] [project_id]
#
# Examples:
#   ./neon-tables.sh main
#   ./neon-tables.sh main neondb
#
# Output: JSON array of {schema, name, owner, has_indexes, row_estimate}

source "$(dirname "$0")/_lib.sh"
require_neon_api_key

[[ $# -ge 1 ]] || err "usage: $0 <branch> [database] [project_id]"

branch="$1"
db="${2:-}"
pid="${3:-}"

# If a database is specified, append it to the connection URI. Otherwise use the default.
conn=$(neon_conn "$branch" pooled "$pid")
if [[ -n "$db" ]]; then
  # Replace the database segment in the URI (postgres://...host/<db>?...)
  conn=$(echo "$conn" | sed -E "s#(postgres(ql)?://[^/]+/)[^?]*#\1$db#")
fi

psql "$conn" -At <<'SQL'
SELECT COALESCE(json_agg(t), '[]'::json)
FROM (
  SELECT
    schemaname AS schema,
    tablename AS name,
    tableowner AS owner,
    hasindexes AS has_indexes,
    (SELECT reltuples::bigint
       FROM pg_class
       WHERE oid = (schemaname || '.' || tablename)::regclass) AS row_estimate
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY schemaname, tablename
) t;
SQL
