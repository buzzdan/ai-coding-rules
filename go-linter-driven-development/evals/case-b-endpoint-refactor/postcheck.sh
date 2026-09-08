#!/usr/bin/env bash
# Case B postcheck: behavior preserved, lint green, one owner for the port
# range, a new validating constructor in transport, no suppressions.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"

assert "task test green" run_task test
assert "task lint green" run_task lint

assert_le "port range predicate (65535 or a named max port) has one owner" \
  "$(count_matches_prod '(<|>) ?(65535|[a-zA-Z_.]*[mM]ax[A-Za-z_]*[Pp]ort[A-Za-z_]*)\b' 'internal/transport/*.go')" 1
# The scheme is chosen wherever "https" is spelled; the TLS flag may still be
# consulted elsewhere for a different question (wrapping the dialed socket).
assert_le "scheme decided once inside transport" \
  "$(count_matches_prod '"https"' 'internal/transport/*.go')" 1

# A new constructor owns the trio. Either shape earns it: a validating
# (X, error) constructor, or a normalizing one that is the single owner of the
# port rule (the fixture's public NewClient contract, pinned by its test, is
# "an out-of-range port falls back to the default", so preserving it is legal).
new_ctors=$(new_func_names 'func (Parse|New|new)[A-Za-z]+\([^)]*\) \(?\*?[A-Za-z]+(, error)?\)?' 'internal/transport/*.go' || true)
echo "new constructors: ${new_ctors:-<none>}"
assert_ge "a new constructor for the endpoint value exists in internal/transport" "$(wc -w <<<"$new_ctors")" 1

assert_eq "no //nolint added to internal/transport" "$(count_matches '//nolint' 'internal/transport/*.go')" 0
assert "black-box heartbeat suite" run_blackbox
finish
