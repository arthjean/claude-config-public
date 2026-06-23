#!/usr/bin/env bash
# neon-sql.sh - run a single SQL statement on a Neon branch.
# Replaces MCP `run_sql`. Uses pooled connection by default (safe for SELECT/INSERT/UPDATE).
#
# Usage:
#   ./neon-sql.sh <branch> "<sql>" [direct|pooled] [project_id]
#
# Examples:
#   ./neon-sql.sh main "SELECT count(*) FROM users"
#   ./neon-sql.sh feature/x "SELECT * FROM users LIMIT 5" pooled
#   ./neon-sql.sh main "ALTER TABLE x ADD COLUMN y TEXT" direct  # DDL needs direct

source "$(dirname "$0")/_lib.sh"
require_neon_api_key

[[ $# -ge 2 ]] || err "usage: $0 <branch> \"<sql>\" [direct|pooled] [project_id]"

branch="$1"
sql="$2"
mode="${3:-pooled}"
pid="${4:-}"

neon_psql_c "$branch" "$sql" "$mode" "$pid"
