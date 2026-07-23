#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_root=$(dirname "$script_dir")
failed=0

report_failure() {
  printf '%s\n' "guidance check: $1" >&2
  failed=1
}

check_map() {
  map_path=$1
  max_lines=$2
  max_bytes=$3
  map_file="$config_root/$map_path"

  if [ ! -f "$map_file" ]; then
    report_failure "missing $map_path"
    return
  fi

  line_count=$(wc -l < "$map_file")
  byte_count=$(wc -c < "$map_file")

  [ "$line_count" -le "$max_lines" ] || report_failure "$map_path exceeds $max_lines lines ($line_count)"
  [ "$byte_count" -le "$max_bytes" ] || report_failure "$map_path exceeds $max_bytes bytes ($byte_count)"

  if grep -Fq '—' "$map_file"; then
    report_failure "$map_path contains an em dash glyph"
  fi
}

check_map CLAUDE.md 160 20480
check_map AGENTS.md 140 16384

for relative_path in \
  docs/user-context.md \
  docs/engineering.md \
  docs/design.md \
  docs/research-and-delegation.md \
  docs/git-and-delivery.md \
  docs/harness.md
do
  document="$config_root/$relative_path"

  if [ ! -f "$document" ]; then
    report_failure "missing $relative_path"
    continue
  fi

  if ! grep -Eq '^> Status: (current|review-needed) \| Owner: .+ \| Last verified: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$document"; then
    report_failure "invalid metadata in $relative_path"
  fi

  for map_path in CLAUDE.md AGENTS.md
  do
    if ! grep -Fq "\`$relative_path\`" "$config_root/$map_path"; then
      report_failure "$relative_path is not referenced by $map_path"
    fi
  done

  if grep -Fq '—' "$document"; then
    report_failure "$relative_path contains an em dash glyph"
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

printf '%s\n' "guidance check: passed"
