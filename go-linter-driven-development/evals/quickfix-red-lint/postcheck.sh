#!/usr/bin/env bash
# quickfix-red-lint postcheck — runs in the kept scaffold after /go-ldd-quickfix.
#   1. .golangci.yaml is byte-identical to the fixture's original (lint-fixer hard limit)
#   2. task test is green
#   3. task lint issue count is reported (informational — escalations may be pending)
#   4. no _test.go lost an assertion line versus postcheck/assertion-counts.txt
set -uo pipefail
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$here/../postcheck/lib.sh"

if ! cmp -s "$EVAL_DIR/.golangci.yaml" "$LDD_POSTCHECK_DIR/golangci.orig.yaml"; then
	diff -u "$LDD_POSTCHECK_DIR/golangci.orig.yaml" "$EVAL_DIR/.golangci.yaml" | head -n 40 || true
fi
assert ".golangci.yaml unchanged from the fixture's original" \
	cmp -s "$EVAL_DIR/.golangci.yaml" "$LDD_POSTCHECK_DIR/golangci.orig.yaml"

assert "task test green" run_task test

echo "info  task lint issues remaining: $(lint_issue_count)"
echo "info  commits since scaffold: $(commits_since_base)"

assert_assertions_kept "$LDD_POSTCHECK_DIR/assertion-counts.txt"

finish
