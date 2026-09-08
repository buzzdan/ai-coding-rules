#!/usr/bin/env bash
# Case C postcheck: tests/lint green, the picking step (whatever Pick now calls)
# has cognitive complexity <= 5, no suppressions, black-box suite.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

pick_file=$(grep -lE '^func \([a-z]+ \*?Placer\) Pick\(' "$EVAL_DIR"/internal/placement/*.go 2>/dev/null | grep -v _test | head -1)
pick_file=${pick_file#"$EVAL_DIR"/}
assert "Placer.Pick still exists in internal/placement" test -n "$pick_file"
if [[ -n "$pick_file" ]]; then
  worst=$(gocognit_of Pick internal/placement)
  for callee in $(receiver_calls_in Pick "$pick_file"); do
    c=$(gocognit_of "$callee" internal/placement) || continue
    echo "  gocognit($callee) = $c"
    ((c > worst)) && worst=$c
  done
  assert_le "gocognit of Pick and every receiver method it calls" "$worst" 5
fi

assert_eq "no //nolint in internal/placement production code" "$(count_matches_prod '//nolint' 'internal/placement/*.go')" 0
assert "black-box heartbeat suite" run_blackbox
finish
