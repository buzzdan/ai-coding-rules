#!/usr/bin/env bash
# Case F postcheck: the ratchet over the commit history, clean islands, the
# shallow fix rejected, end state, test payoff, tests/lint green, black-box.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

echo "== the ratchet: env.Config references outside cmd/, per commit =="
assert_ge "at least 3 commits after the scaffold base" "$(commits_since_base)" 3
assert "env.Config references outside cmd/ never rise and end at 0" \
  ratchet_nonincreasing 'env\.Config\b' '*.go' ':(exclude)cmd/'
assert_le "no commit touches non-test code in more than 2 packages (island + its caller)" \
  "$(max_pkgs_touched_per_commit)" 2

echo "== islands are clean =="
assert_eq "pool no longer imports env" "$(count_matches 'example\.com/go-mini/internal/env"' 'internal/pool/*.go')" 0
assert_eq "jobs no longer imports env" "$(count_matches 'example\.com/go-mini/internal/env"' 'internal/jobs/*.go')" 0
assert_eq "shallow fix rejected: env.Configuration is not a param/field type in pool, jobs or handlers" \
  "$(count_matches 'env\.Configuration' 'internal/pool/*.go' 'internal/jobs/*.go' 'internal/handlers/*.go')" 0

echo "== end state =="
assert_eq "R8 Q1: no package-level var left in internal/env" "$(count_matches_prod '^var ' 'internal/env/*.go')" 0
assert_eq "R8 Q2: no init() left in internal/env" "$(count_matches_prod '^func init\(\)' 'internal/env/*.go')" 0
assert_eq "no //nolint in internal/env" "$(count_matches '//nolint' 'internal/env/*.go')" 0
assert_eq "no //nolint in internal/pool" "$(count_matches '//nolint' 'internal/pool/*.go')" 0
assert_eq "no nolint:gochecknoglobals anywhere for the config global" "$(count_matches 'nolint:gochecknoglobals' 'internal/env/*.go' 'internal/pool/*.go' 'cmd/**/*.go')" 0

echo "== test payoff =="
assert_eq "R8 Q6: no test mutates env.Config" "$(count_matches 'env\.Config\.\w+ =' 'internal/**/*_test.go' 'cmd/**/*_test.go')" 0
assert_ge "t.Parallel() in internal/pool tests" "$(count_matches 't\.Parallel\(\)' 'internal/pool/*_test.go')" 1
assert_ge "a pool constructor is called with a literal number in its tests" "$(count_matches 'New\w+\([0-9]+' 'internal/pool/*_test.go')" 1

assert "black-box heartbeat suite" run_blackbox
finish
