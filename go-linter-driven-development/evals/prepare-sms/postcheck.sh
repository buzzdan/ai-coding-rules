#!/usr/bin/env bash
# prepare-sms postcheck — runs in the kept scaffold after /go-ldd-prepare.
#   1. ≥1 prep commit on top of the scaffold's base commit
#   2. no SMS code landed in non-test Go files (prep reshapes; it never builds the feature)
#   3. task test green after prep
#   4. the god file is either untouched or explicitly reported PREP-DEFERRED
set -uo pipefail
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$here/../postcheck/lib.sh"

assert_ge "prep commits after the scaffold base" "$(commits_since_base)" 1
if [[ -n "$(git -C "$EVAL_DIR" status --porcelain --untracked-files=all)" ]]; then
	echo "info  working tree has uncommitted changes (prep work must land as commits):"
	git -C "$EVAL_DIR" status --porcelain --untracked-files=all | head -n 20
fi

sms=$(cd "$EVAL_DIR" && grep -rlE '[Ss][Mm][Ss]' --include='*.go' --exclude='*_test.go' --exclude-dir=.git . || true)
[[ -n "$sms" ]] && printf 'info  SMS symbols found in: %s\n' "$sms"
assert "no SMS feature code in non-test Go files" test -z "$sms"

assert "task test green after prep" run_task test

god=internal/services/device_service.go
if file_unchanged_since_base "$god"; then
	echo "PASS  $god untouched"
else
	assert "$god changed, so the PREPARATION LOG must report PREP-DEFERRED" \
		last_message_contains 'PREP-DEFERRED'
fi

finish
