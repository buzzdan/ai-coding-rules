#!/usr/bin/env bash
# Case B postcheck: behavior preserved, lint green, one owner for the port
# range, a new validating constructor in transport, no suppressions.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

assert_le "port range predicate (65535 or a named max port) has one owner" \
  "$(count_matches_prod '(<|>) ?(65535|[a-zA-Z_.]*[mM]ax[A-Za-z_]*[Pp]ort[A-Za-z_]*)\b' 'internal/transport/*.go')" 1
assert_le "scheme decided once inside transport" \
  "$(count_matches_prod 'if [a-z.]*tls \{|if [a-z.]*TLS \{' 'internal/transport/*.go')" 1

new_ctors=$(new_func_names 'func (Parse|New)[A-Za-z]+\([^)]*\) \(\*?[A-Za-z]+, error\)' 'internal/transport/*.go' || true)
echo "new constructors: ${new_ctors:-<none>}"
assert_ge "a new validating constructor (X, error) exists in internal/transport" "$(wc -w <<<"$new_ctors")" 1

assert_eq "no //nolint added to internal/transport" "$(count_matches '//nolint' 'internal/transport/*.go')" 0
assert "black-box heartbeat suite" run_blackbox
finish
