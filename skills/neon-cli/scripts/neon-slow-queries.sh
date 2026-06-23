#!/usr/bin/env bash
# neon-slow-queries.sh - list the slowest queries from pg_stat_statements.
# Replaces MCP `list_slow_queries`. Requires pg_stat_statements extension (default on Neon).
#
# Usage:
#   ./neon-slow-queries.sh <branch> [limit] [database] [project_id]
#
# Examples:
#   ./neon-slow-queries.sh main
#   ./neon-slow-queries.sh main 50
#   ./neon-slow-queries.sh main 20 neondb
#
# Output: JSON array sorted by mean execution time (desc), with calls/total/mean ms and rows.

source "$(dirname "$0")/_lib.sh"
require_neon_api_key

[[ $# -ge 1 ]] || err "usage: $0 <branch> [limit] [database] [project_id]"

branch="$1"
limit="${2:-20}"
db="${3:-}"
pid="${4:-}"

# Sanitize limit (must be a positive int)
[[ "$limit" =~ ^[0-9]+$ ]] || err "limit must be a positive integer, got: $limit"

conn=$(neon_conn "$branch" pooled "$pid")
if [[ -n "$db" ]]; then
  conn=$(echo "$conn" | sed -E "s#(postgres(ql)?://[^/]+/)[^?]*#\1$db#")
fi

# First check the extension is loaded
ext_check=$(psql "$conn" -At -c "SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'" 2>/dev/null || echo "")
if [[ -z "$ext_check" ]]; then
  err "pg_stat_statements extension is not loaded on this branch. Enable it via Neon console: Settings → Compute → pg_stat_statements"
fi

psql "$conn" -At -v "lim=$limit" <<'SQL'
SELECT COALESCE(json_agg(t), '[]'::json)
FROM (
  SELECT
    query,
    calls,
    rows,
    round(mean_exec_time::numeric, 2)  AS mean_ms,
    round(total_exec_time::numeric, 2) AS total_ms,
    round((100.0 * total_exec_time
            / NULLIF(SUM(total_exec_time) OVER (), 0))::numeric, 2) AS pct_total_time
  FROM pg_stat_statements
  WHERE query NOT ILIKE '%pg_stat_statements%'
    AND query NOT ILIKE 'EXPLAIN%'
  ORDER BY mean_exec_time DESC
  LIMIT :lim
) t;
SQL
