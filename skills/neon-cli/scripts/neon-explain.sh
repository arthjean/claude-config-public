#!/usr/bin/env bash
# neon-explain.sh - EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) a SQL statement.
# Replaces MCP `explain_sql_statement`. Returns the structured query plan.
#
# WARNING: ANALYZE actually executes the query. For destructive statements
# (UPDATE/DELETE/INSERT), use the --safe flag - it wraps in BEGIN/ROLLBACK.
#
# Usage:
#   ./neon-explain.sh <branch> "<sql>" [--safe] [project_id]
#
# Examples:
#   ./neon-explain.sh main "SELECT * FROM users WHERE email = 'x@example.com'"
#   ./neon-explain.sh main "DELETE FROM users WHERE inactive = true" --safe

source "$(dirname "$0")/_lib.sh"
require_neon_api_key

[[ $# -ge 2 ]] || err "usage: $0 <branch> \"<sql>\" [--safe] [project_id]"

branch="$1"
sql="$2"
shift 2

safe=0
pid=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe) safe=1; shift ;;
    *)      pid="$1";  shift ;;
  esac
done

conn=$(neon_conn "$branch" direct "$pid")  # direct: avoids pooler limits on BEGIN/ROLLBACK

if [[ $safe -eq 1 ]]; then
  psql "$conn" -At <<SQL
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) $sql;
ROLLBACK;
SQL
else
  psql "$conn" -At -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) $sql"
fi
