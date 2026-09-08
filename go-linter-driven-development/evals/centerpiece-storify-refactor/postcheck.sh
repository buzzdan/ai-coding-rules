#!/usr/bin/env bash
# Centerpiece postcheck: complexity of ProcessHeartbeat, the R1/R8/R10/R12
# oracles scoped to internal/services (baselines read from the base commit so
# the fixture's unrelated plants do not fail the case), rung-0 parse test,
# tests/lint green, and the hidden black-box suite as the behavior oracle.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

echo "== complexity =="
assert_le "gocognit(ProcessHeartbeat) (was 76)" "$(gocognit_of ProcessHeartbeat internal/services)" 10
assert_le "gocyclo(ProcessHeartbeat) (was 40)" "$(gocyclo_of ProcessHeartbeat internal/services)" 8

ph_file=$(grep -lE '^func \(\w+ \*DeviceService\) ProcessHeartbeat\(' "$EVAL_DIR"/internal/services/*.go 2>/dev/null | head -1)
ph_file=${ph_file#"$EVAL_DIR"/}
assert "ProcessHeartbeat still defined in internal/services" test -n "$ph_file"
if [[ -n "$ph_file" ]]; then
  body=$(func_body ProcessHeartbeat "$ph_file")
  assert_eq "R1 Q3: no status string-literal comparison inside ProcessHeartbeat" "$(grep -cE '(==|!=) "[A-Z]+"' <<<"$body")" 0
  assert_eq "R3 Q2: no strings./index manipulation inside ProcessHeartbeat" "$(grep -cE 'strings\.|\[[0-9]+\]|\[[0-9]+:\]' <<<"$body")" 0
  assert_eq "no //nolint on ProcessHeartbeat" "$(grep -B4 -E '^func \(\w+ \*DeviceService\) ProcessHeartbeat\(' "$EVAL_DIR/$ph_file" | grep -c nolint)" 0
fi

echo "== services-scoped oracles (baseline = scaffold base commit) =="
base=$(base_commit)
svc_prod=('internal/services/*.go' ':(exclude)*_test.go')
assert_eq "R8 Q3: context.Background() gone from internal/services" "$(count_matches_prod 'context\.Background\(\)' 'internal/services/*.go')" 0
assert_le "context.TODO() not used as an escape hatch" "$(count_matches_prod 'context\.TODO\(\)' 'internal/services/*.go')" \
  "$(count_matches_at "$base" 'context\.TODO\(\)' "${svc_prod[@]}")"
assert_le "R10 Q5: the retry sleep is gone (time.Sleep count below baseline)" "$(count_matches_prod 'time\.Sleep' 'internal/services/*.go')" \
  "$(( $(count_matches_at "$base" 'time\.Sleep' "${svc_prod[@]}") - 1 ))"
assert_le "R1 Q5: functions returning >3 values (ProcessHeartbeat's gone)" "$(count_matches_prod '\) \([^)]*,[^)]*,[^)]*,[^)]*\)' 'internal/services/*.go')" \
  "$(( $(count_matches_at "$base" '\) \([^)]*,[^)]*,[^)]*,[^)]*\)' "${svc_prod[@]}") - 1 ))"
assert_le "R1 Q3: \"READY\" literal has one owner on the heartbeat path (3 fewer than baseline)" "$(count_matches_prod '"READY"' 'internal/services/*.go')" \
  "$(( $(count_matches_at "$base" '"READY"' "${svc_prod[@]}") - 2 ))"
assert_le "R3 Q4: the labeled-continue dedupe left ProcessHeartbeat" "$(count_matches_prod 'continue outer' 'internal/services/*.go')" \
  "$(( $(count_matches_at "$base" 'continue outer' "${svc_prod[@]}") - 1 ))"

echo "== the parse leaf =="
parse_total=$(count_matches_prod 'Parse\w*Heartbeat\w*\(' 'internal/**/*.go')
parse_decls=$(count_matches_prod '^func .*Parse\w*Heartbeat\w*\(|^\s*//.*Parse\w*Heartbeat\w*\(' 'internal/**/*.go')
assert_ge "production code CALLS a Parse*Heartbeat* constructor (declarations and comments excluded)" "$((parse_total - parse_decls))" 1
assert_ge "R7: an external-package _test.go calls Parse*Heartbeat*( with a literal" \
  "$(external_test_calls 'Parse\w*Heartbeat\w*\("' 'internal/**/*_test.go')" 1

assert "black-box heartbeat suite" run_blackbox
finish
