#!/usr/bin/env bash
# Case D postcheck: ReplicaCount is gone or untouched (never grown), tests and
# lint green, black-box suite.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint
assert_le "ReplicaCount has at most its original single method (deleted or untouched, never grown)" \
  "$(count_matches_prod 'func \([a-z]+ \*?ReplicaCount\)' 'internal/**/*.go')" 1
assert_le "ReplicaCount is declared at most once" "$(count_matches_prod '^type ReplicaCount' 'internal/**/*.go')" 1
assert_eq "no TraceID-like wrapper appeared anywhere" "$(count_matches_prod '^type Trace(ID|Id) ' 'internal/**/*.go' 'cmd/**/*.go')" 0
assert "black-box heartbeat suite" run_blackbox
finish
