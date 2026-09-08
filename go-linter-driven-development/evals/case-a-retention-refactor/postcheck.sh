#!/usr/bin/env bash
# Case A postcheck: behavior preserved, lint green, the retention rule has one
# owner, the new type answers R2's falsifying questions, rung-0 test exists.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

# R1 Q2 oracle: the range predicate (literal 365 or a named max) has one owner.
owners=$(count_matches_prod '(>|<=?) ?(365|[a-zA-Z_.]*[mM]ax[A-Za-z_]*)\b' 'internal/snapshot/*.go')
assert_le "retention range predicate has one owner in internal/snapshot" "$owners" 1
assert_le "strconv.Atoi on retention happens once (one boundary parse)" \
  "$(count_matches_prod 'strconv\.Atoi' 'internal/snapshot/*.go')" 1
assert_le "raw retention value inspected at most once downstream" \
  "$(count_matches_prod 'raw\["retention"\]' 'internal/snapshot/*.go')" 1

# A NEW validating constructor exists (ParseWindow/NewPlan pre-exist, so only
# constructors absent at the base commit count).
new_ctors=$(new_func_names 'func (Parse|New)[A-Za-z]+\([^)]*\) \([A-Za-z]+, error\)' 'internal/snapshot/*.go' || true)
echo "new constructors: ${new_ctors:-<none>}"
assert_ge "a new (Parse|New)X(...) (X, error) constructor exists in internal/snapshot" "$(wc -w <<<"$new_ctors")" 1

# R7: a rung-0 test in package snapshot_test calls a new constructor with a literal.
calls=0
for c in $new_ctors; do
  n=$(external_test_calls "snapshot\.$c\(\"" 'internal/snapshot/*_test.go')
  calls=$((calls + n))
done
assert_ge "snapshot_test calls a new constructor with a string literal" "$calls" 1

# R2 Q1: the new type cannot be built invalid — no exported fields, no literal
# construction outside its own file (non-test).
for c in $new_ctors; do
  typ=$(grep -hoE "func $c\([^)]*\) \([A-Za-z]+, error\)" internal/snapshot/*.go | sed -E 's/.*\) \(([A-Za-z]+), error\)/\1/' | head -1)
  [[ -z "$typ" ]] && continue
  def=$(grep -lE "^type $typ struct" internal/snapshot/*.go | head -1)
  [[ -z "$def" ]] && continue
  exported=$(awk -v t="$typ" '$0 ~ ("^type " t " struct") {p=1; next} p && /^}/ {exit} p && /^\t[A-Z]/ {n++} END {print n+0}' "$def")
  assert_eq "$typ has no exported fields" "$exported" 0
  literals=$(grep -lE "\b$typ\{" internal/snapshot/*.go | grep -v _test | grep -v "^$def$" | wc -l)
  assert_eq "$typ is never built by literal outside $def" "$literals" 0
done

assert_eq "no //nolint added to internal/snapshot" "$(count_matches '//nolint' 'internal/snapshot/*.go')" 0
assert "black-box heartbeat suite" run_blackbox
finish
