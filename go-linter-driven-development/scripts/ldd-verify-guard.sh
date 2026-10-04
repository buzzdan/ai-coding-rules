#!/usr/bin/env bash
# PreToolUse hook of the go-linter-driven-development plugin: the move implementer's
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

# ======================= language block: go =======================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here; a build of the script
# for another language replaces this block and nothing else.
#
# Contract:
#   LANG_SRC_GLOB       find(1) -name pattern for the language's source files
#   LANG_EXCLUDE_RE     ERE over a relative path: directories never in scope
#   LANG_SUPPRESS_RE    ERE: a lint-suppression directive on a source line
#   LANG_COMMENT_RE     ERE: a source line that carries a comment
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_configure      reads OPT_GLOB / OPT_TEST_RE (set by --glob / --test-re)
#   lang_is_test <path> exit 0 iff the path is a test file
#   LANG_VERIFY_RE      ERE: a shell command that runs the language's tests, lint,
#                       build or vet, or a task runner's test/lint/build target —
#                       the runs the move implementer must send through
#                       ldd-attempt.sh
#   lang_lint_delta <base> <files...>
#                       prints the lint command over the slice's changes only
#   LANG_LINT_CONFIG_RE ERE over a relative path: a linter's configuration file,
#                       which no refactoring slice may touch (every language's
#                       forms, since a repository may carry several)
LANG_SRC_GLOB='*.go'
LANG_EXCLUDE_RE='(^|/)(vendor|\.git|testdata)/'
LANG_SUPPRESS_RE='//nolint'
LANG_COMMENT_RE='//'
LANG_DIRECTIVE_RE='//(go:|nolint| Output:|line |export |extern )'
LANG_GENERATED_RE='Code generated .* DO NOT EDIT|DO NOT EDIT|@generated'

LANG_VERIFY_RE='(^|[^A-Za-z0-9_./-])((\S*/)?(go\s+(-C\s+\S+\s+)?(test|vet|build)|golangci-lint|staticcheck|gofmt)|task\s+\S*(test|lint|build|check|vet)\S*|make\s+(-[A-Za-z]\s+\S+\s+)*\S*(test|lint|build|check|vet)\S*)([^A-Za-z0-9_-]|$)'
LANG_LINT_CONFIG_RE='(^|/)(\.golangci\.ya?ml|pyproject\.toml|setup\.cfg|ruff\.toml|\.flake8)$'

lang_configure() {
  [[ -n "${OPT_GLOB:-}" ]] && LANG_SRC_GLOB="$OPT_GLOB"
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  [[ "$1" == *_test.go ]]
}
# lang_lint_delta <base> <files...> — the Go linter over the changes since the
# base commit, in the packages of the given files; parallel runners allowed, so
# the workers of one wave do not wait on each other's lock.
lang_lint_delta() {
  local base="$1"; shift
  local pkgs
  pkgs=$(for f in "$@"; do d=$(dirname "$f"); printf './%s\n' "${d#./}"; done | LC_ALL=C sort -u | tr '\n' ' ')
  printf 'golangci-lint run --allow-parallel-runners --new-from-rev=%s %s\n' "$base" "${pkgs% }"
}
# ===================== end language block: go =====================

# The command is judged segment by segment — split at &&, ||, ; and | outside
# quotes, and at line ends — so a run chained behind a wrapper call is still
# seen, while a quoted compound command handed to the wrapper (`-- sh -c "a && b"`)
# stays one segment. A segment that calls the wrapper (ldd-attempt.sh before its
# --) is the allowed form; any other segment that runs a test, lint, build or vet
# form is denied.
split_segments() {
  awk '{
    s = $0; out = ""; sq = 0; dq = 0; n = length(s)
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1); nx = substr(s, i + 1, 1)
      if (sq) { out = out c; if (c == "\047") sq = 0; continue }
      if (dq) { out = out c; if (c == "\\") { out = out nx; i++; continue } if (c == "\"") dq = 0; continue }
      if (c == "\047") { sq = 1; out = out c; continue }
      if (c == "\"") { dq = 1; out = out c; continue }
      if (c == "&" && nx == "&") { out = out "\n"; i++; continue }
      if (c == "|" && nx == "|") { out = out "\n"; i++; continue }
      if (c == ";" || c == "|") { out = out "\n"; continue }
      out = out c
    }
    print out
  }'
}
while IFS= read -r segment; do
  [[ -n "$segment" ]] || continue
  case "$segment" in *ldd-attempt.sh*' -- '*) continue ;; esac
  if printf '%s\n' "$segment" | grep -qE -- "$LANG_VERIFY_RE"; then
    echo "use ldd-attempt.sh for test, lint and build runs: bash <WRAPPER> <REPORT> move-<n> <test|lint|build> -- <command>. Denied: $segment" >&2
    exit 2
  fi
done < <(printf '%s\n' "$command" | split_segments)
exit 0
