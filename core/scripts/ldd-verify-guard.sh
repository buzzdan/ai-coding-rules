#!/usr/bin/env bash
# PreToolUse hook of the {{.Plugin}} plugin: the move implementer's
# verification runs go through ldd-attempt.sh, which counts them.
#
# Claude Code runs this script before every Bash call of the plugin's agents
# and of the main thread, with the hook input as JSON on stdin. It acts only
# when the input names the move implementer as the running agent, and only
# when the command runs the language's tests, lint, build or vet (or a task
# runner's test, lint or build target) without going through the wrapper.
# Then it exits 2, which blocks the call, and the line on stderr tells the
# worker what to use. Every other call exits 0 and is not touched.
#
# Wired in hooks/hooks.json as:
#   {"matcher": "Bash", "hooks": [{"type": "command",
#    "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/ldd-verify-guard.sh\""}]}
#
# Uses only POSIX-portable tools: sed, grep, awk.

set -u

INPUT=$(cat)

agent=$(printf '%s' "$INPUT" | sed -E -n 's/.*"agent_type":"([^"]*)".*/\1/p')
case "$agent" in
  *move-implementer*) ;;
  *) exit 0 ;;
esac

# The command, as JSON spells it; \n becomes a line end so each line is judged.
command=$(printf '%s' "$INPUT" | sed -E -n 's/.*"command":"(([^"\\]|\\.)*)".*/\1/p' | sed 's/\\n/\
/g')
[[ -n "$command" ]] || exit 0

{{include "scripts/ldd-lang.sh"}}

# The command is judged segment by segment — split at &&, ||, ; and | and at
# line ends — so a run chained behind a wrapper call is still seen. A segment
# that calls the wrapper (ldd-attempt.sh before its --) is the allowed form;
# any other segment that runs a test, lint, build or vet form is denied.
while IFS= read -r segment; do
  [[ -n "$segment" ]] || continue
  case "$segment" in *ldd-attempt.sh*' -- '*) continue ;; esac
  if printf '%s\n' "$segment" | grep -qE -- "$LANG_VERIFY_RE"; then
    echo "use ldd-attempt.sh for test, lint and build runs: bash <WRAPPER> <REPORT> move-<n> <test|lint|build> -- <command>. Denied: $segment" >&2
    exit 2
  fi
done < <(printf '%s\n' "$command" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')
exit 0
