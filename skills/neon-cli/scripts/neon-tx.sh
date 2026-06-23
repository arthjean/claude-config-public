#!/usr/bin/env bash
# neon-tx.sh - run a multi-statement transaction on a Neon branch.
# Replaces MCP `run_sql_transaction`. Defaults to direct connection (DDL-safe).
# Wraps in a single transaction with ON_ERROR_STOP - any failed statement rolls back the entire script.
#
# Usage:
#   ./neon-tx.sh <branch> [-f file.sql] [pooled|direct] [project_id]
#   ./neon-tx.sh <branch> < file.sql                      # stdin
#   echo "SELECT 1; SELECT 2" | ./neon-tx.sh main         # heredoc-style
#
# Examples:
#   ./neon-tx.sh main -f migration.sql
#   ./neon-tx.sh main <<'SQL'
#     ALTER TABLE users ADD COLUMN verified_at TIMESTAMPTZ;
#     UPDATE users SET verified_at = created_at WHERE email_verified = true;
#   SQL

source "$(dirname "$0")/_lib.sh"
require_neon_api_key

[[ $# -ge 1 ]] || err "usage: $0 <branch> [-f file.sql] [pooled|direct] [project_id]"

branch="$1"; shift
file=""

# Optional -f <file>
if [[ "${1:-}" == "-f" ]]; then
  shift
  file="${1:?missing filename after -f}"; shift
  [[ -f "$file" ]] || err "file not found: $file"
fi

mode="${1:-direct}"
pid="${2:-}"

neon_psql_tx "$branch" "$file" "$mode" "$pid"
