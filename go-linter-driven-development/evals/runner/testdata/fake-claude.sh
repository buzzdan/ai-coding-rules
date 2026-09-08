#!/usr/bin/env bash
# Fake `claude` binary for the runner's tests (no network, no cost).
#
# Judge mode  (an argument equals "json", i.e. `--output-format json`): swallows the
#              prompt on stdin and prints one result object whose verdict is
#              $FAKE_JUDGE_VERDICT (default PASS).
# Agent mode  (anything else): writes hello.go into the cwd — mimicking the Write
#              tool call recorded in the trace — appends its argv to
#              $FAKE_CLAUDE_ARGS_OUT (one arg per line, if set) and streams the
#              trace file named by $FAKE_CLAUDE_TRACE to stdout.
set -euo pipefail

mode=agent
for a in "$@"; do
  if [[ "$a" == "json" ]]; then mode=judge; fi
done

if [[ "$mode" == "judge" ]]; then
  cat >/dev/null
  verdict="${FAKE_JUDGE_VERDICT:-PASS}"
  printf '{"type":"result","subtype":"success","is_error":false,"result":"The focus text satisfies the criteria.\\nVERDICT: %s","total_cost_usd":0.001,"duration_ms":10,"num_turns":1}\n' "$verdict"
  exit 0
fi

printf 'package x\n\n// Hello greets.\nfunc Hello() string { return "hi" }\n' > hello.go
if [[ -n "${FAKE_CLAUDE_ARGS_OUT:-}" ]]; then
  printf '%s\n' "$@" > "$FAKE_CLAUDE_ARGS_OUT"
fi
cat "${FAKE_CLAUDE_TRACE:?set FAKE_CLAUDE_TRACE to a .jsonl trace}"
