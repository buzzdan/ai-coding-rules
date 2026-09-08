#!/usr/bin/env bash
# wire-repo-brain postcheck — the plugin's own gate is the oracle.
#   1. the INSTALLED scripts/check-repo-brain.sh runs in the scaffold:
#        exit 0 → pass
#        exit 1 → pass only if every violation is a [Q2] finding (the content
#                 doc's file:line citation / phantom symbol, which BOOTSTRAP
#                 reports but may not rewrite); any [Q1]/[Q3]/[Q7] line fails
#        exit 2 → fail (scanner error / usage)
#   2. the installed script is byte-identical to the plugin's (verify-or-copy,
#      never a diverged fork) — the cheap stand-in for a second idempotence run
set -uo pipefail
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$here/../postcheck/lib.sh"
plugin_root="$(cd "$here/../.." && pwd)"

gate="$EVAL_DIR/scripts/check-repo-brain.sh"
if [[ ! -f "$gate" ]]; then
	echo "FAIL  scripts/check-repo-brain.sh not installed"
	_pc_failures=$((_pc_failures + 1))
	finish
fi

err=$(mktemp) out=$(mktemp)
(cd "$EVAL_DIR" && bash scripts/check-repo-brain.sh . >"$out" 2>"$err")
rc=$?
echo "info  installed gate exit $rc"
sed 's/^/      /' "$out"
sed 's/^/      stderr: /' "$err"
gate_ok() {
	case "$rc" in
	0) return 0 ;;
	1) ! grep -qE '\[Q[137]\]' "$err" ;;
	*) return 1 ;;
	esac
}
assert "installed gate clean, or red only on [Q2] content-doc citations (no Q1/Q3/Q7)" gate_ok
rm -f "$err" "$out"

assert "installed gate byte-identical to the plugin's scripts/check-repo-brain.sh" \
	cmp -s "$gate" "$plugin_root/scripts/check-repo-brain.sh"

finish
