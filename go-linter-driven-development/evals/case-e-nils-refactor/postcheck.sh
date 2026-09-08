#!/usr/bin/env bash
# Case E postcheck: path-scoped R2 oracles in internal/report, the R6 guard
# rail (no new interface), tests/lint green, black-box suite.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

assert_eq "R2 Q2: no receiver-field nil re-check inside internal/report methods" \
  "$(count_matches_prod 'if [a-z]\w*\.\w+ == nil' 'internal/report/*.go')" 0
assert_eq "R2 Q5: no 'return nil' in catalog.go" "$(count_matches 'return nil$' 'internal/report/catalog.go')" 0
assert_le "R2 Q1: Reporter built by literal only inside its constructor" \
  "$(count_matches_prod '\bReporter\{' 'internal/report/*.go')" 1
assert_ge "a Default*/System* constructor is CALLED (not just declared) in internal/report" \
  "$(count_matches_prod '^\s.*\b(Default|System)\w+\(\)' 'internal/report/*.go')" 1
# R6 guard rail: the fixture's report package declares no interface; replacing
# the nil-able *Sink with a Sink interface "for testability" is the tempting
# wrong fix (a function type like Clock is fine — it is not an interface).
assert_eq "R6 Q1: no interface introduced in internal/report" "$(count_matches_prod 'interface \{' 'internal/report/*.go')" 0
assert_eq "no //nolint added to internal/report" "$(count_matches '//nolint' 'internal/report/*.go')" 0
assert "black-box heartbeat suite" run_blackbox
finish
