#!/usr/bin/env bash
# check-manifest.sh — keeps violations.yaml honest against fixtures/go-mini.
#
# For every entry: each listed file exists under the fixture and the entry's
# anchor (an ERE) matches at least one line in EACH listed file. Every rule
# R1..R12 must carry at least one plant and one control. The fixture itself
# must carry no hints: no PLANT markers, no rule names in comments or docs,
# none of the words violation / falsifying / smell.
#
# The manifest is parsed line by line with awk — no YAML library. Keep the
# shape flat: `- id:` opens an entry; `rule:`, `control:`, `files: [a, b]`
# and `anchor: '...'` each sit on their own line inside it.
#
# Usage: check-manifest.sh [violations.yaml] [fixture-dir]
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
manifest="${1:-$here/violations.yaml}"
fixture="${2:-$here/fixtures/go-mini}"

fail=0
problem() { printf 'FAIL  %s\n' "$*"; fail=1; }

[ -f "$manifest" ] || { problem "manifest not found: $manifest"; exit 1; }
[ -d "$fixture" ] || { problem "fixture not found: $fixture"; exit 1; }

# One tab-separated record per entry: id, rule, control, files, anchor.
records=$(awk '
  function flush() {
    if (id != "") printf "%s\t%s\t%s\t%s\t%s\n", id, rule, control, files, anchor
    id = ""; rule = ""; control = "false"; files = ""; anchor = ""
  }
  /^- id:[[:space:]]*/ { flush(); id = $0; sub(/^- id:[[:space:]]*/, "", id); sub(/[[:space:]]+#.*$/, "", id); next }
  /^[[:space:]]+rule:[[:space:]]*/ && id != "" { rule = $0; sub(/^[[:space:]]+rule:[[:space:]]*/, "", rule); sub(/[[:space:]]+#.*$/, "", rule); next }
  /^[[:space:]]+control:[[:space:]]*/ && id != "" { control = $0; sub(/^[[:space:]]+control:[[:space:]]*/, "", control); sub(/[[:space:]]+#.*$/, "", control); next }
  /^[[:space:]]+files:[[:space:]]*\[/ && id != "" {
    files = $0; sub(/^[[:space:]]+files:[[:space:]]*\[/, "", files); sub(/\].*$/, "", files)
    gsub(/[[:space:]]*,[[:space:]]*/, " ", files); gsub(/^[[:space:]]+|[[:space:]]+$/, "", files); next
  }
  /^[[:space:]]+anchor:[[:space:]]*'\''/ && id != "" {
    anchor = $0; sub(/^[[:space:]]+anchor:[[:space:]]*'\''/, "", anchor); sub(/'\''[[:space:]]*(#.*)?$/, "", anchor)
    gsub(/'\'''\''/, "'\''", anchor); next
  }
  END { flush() }
' "$manifest")

[ -n "$records" ] || problem "no entries parsed from $manifest"

declare -A plants controls seen
for r in 1 2 3 4 5 6 7 8 9 10 11 12; do plants[R$r]=0; controls[R$r]=0; done
entries=0

while IFS=$'\t' read -r id rule control files anchor; do
  [ -n "$id" ] || continue
  entries=$((entries + 1))
  if [ -n "${seen[$id]:-}" ]; then problem "$id: duplicate id"; fi
  seen[$id]=1
  case "$rule" in
    R1|R2|R3|R4|R5|R6|R7|R8|R9|R10|R11|R12) ;;
    *) problem "$id: rule '$rule' is not R1..R12" ;;
  esac
  [ -n "$files" ] || problem "$id: no files listed"
  [ -n "$anchor" ] || problem "$id: no anchor"
  for f in $files; do
    if [ ! -f "$fixture/$f" ]; then
      problem "$id: file missing: $f"
      continue
    fi
    if [ -n "$anchor" ] && ! grep -Eq -- "$anchor" "$fixture/$f"; then
      problem "$id: anchor '$anchor' matches nothing in $f"
    fi
  done
  if [ "$control" = "true" ]; then
    controls[$rule]=$(( ${controls[$rule]:-0} + 1 ))
  else
    plants[$rule]=$(( ${plants[$rule]:-0} + 1 ))
  fi
done <<< "$records"

printf '\n%-6s %7s %9s\n' RULE PLANTS CONTROLS
for r in 1 2 3 4 5 6 7 8 9 10 11 12; do
  rule=R$r
  printf '%-6s %7d %9d\n' "$rule" "${plants[$rule]}" "${controls[$rule]}"
  [ "${plants[$rule]}" -ge 1 ] || problem "$rule has no plant"
  [ "${controls[$rule]}" -ge 1 ] || problem "$rule has no control"
done
printf '%-6s %7d entries\n\n' TOTAL "$entries"

# Hint scan over the fixture tree. Comments in Go, whole text in Markdown.
scan() { grep -rnE --exclude-dir=.git --exclude-dir=bin "$@" "$fixture" 2>/dev/null; }
hints=$(
  scan 'PLANT'
  scan -i 'violation|falsifying|smell'
  scan --include='*.go' '//.*\bR[0-9]+\b'
  scan --include='*.md' '\bR[0-9]+\b'
)
if [ -n "$hints" ]; then
  problem "fixture contains hint words:"
  printf '%s\n' "$hints" | sed 's/^/      /'
fi

if [ "$fail" -ne 0 ]; then
  echo "check-manifest: FAILED"
  exit 1
fi
echo "check-manifest: OK ($entries entries, no hints)"
