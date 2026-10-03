#!/usr/bin/env bash
# Verification wrapper of the move implementer for the go-linter-driven-development plugin.
#
# Every test, lint and build run of a move goes through this script. It writes
# the run's output to a numbered file under the report directory, prints the
# tail, and counts: a move gets three runs of any kind together, and the
# fourth is refused. The worker's hook (ldd-verify-guard.sh) denies a test,
# lint or build command that does not go through here, so the count is a
# bound and not a promise.
#
# Usage:  bash scripts/ldd-attempt.sh <report-dir> <move> <kind> -- <command...>
#         <report-dir>      the worker's REPORT: directory (created as needed)
#         <move>            move-<n> or <n>, the move's number in the slice
#         <kind>            test | lint | build
#         <command...>      the command to run; one argument is run through
#                           the shell, several are run as given
#         bash scripts/ldd-attempt.sh --lint-delta <base> <files...>
#                           print the lint command over the slice's changes
#                           since the base commit (the LINT: line the parent
#                           hands the worker) and exit
#
# Output: "<kind> run <k>/3: exit <code>" and the last 40 lines of the output;
#         the whole output is in <report-dir>/move-<n>/run-<k>-<kind>.txt.
#
# Exit codes: the command's exit code · 3 the move has had three runs
#             ("BOUND: move <n> has had three runs — defer it") · 2 usage error
#
# Uses only POSIX-portable tools: ls, tail, tr, sort.

set -u

SCRIPT_NAME="ldd-attempt"
RUNS_PER_MOVE=3
TAIL_LINES=40

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

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

LANG_VERIFY_RE='(^|[^A-Za-z0-9_./-])(go (test|vet|build)|golangci-lint|staticcheck|gofmt|task (test|lint|build)|make (test|lint|build))([^A-Za-z0-9_-]|$)'
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
# base commit, in the packages of the given files.
lang_lint_delta() {
  local base="$1"; shift
  local pkgs
  pkgs=$(for f in "$@"; do d=$(dirname "$f"); printf './%s\n' "${d#./}"; done | LC_ALL=C sort -u | tr '\n' ' ')
  printf 'golangci-lint run --new-from-rev=%s %s\n' "$base" "${pkgs% }"
}
# ===================== end language block: go =====================

if [[ "${1:-}" == "--lint-delta" ]]; then
  shift
  (( $# >= 2 )) || die "--lint-delta takes a base commit and at least one file"
  lang_lint_delta "$@"
  exit 0
fi

(( $# >= 4 )) || usage
REPORT="$1"; MOVE="$2"; KIND="$3"; shift 3
[[ "$1" == "--" ]] || die "expected -- before the command, got: $1"
shift
(( $# >= 1 )) || die "no command after --"
MOVE="${MOVE#move-}"
[[ "$MOVE" =~ ^[0-9]+$ ]] || die "move is move-<n> or <n>, got: $MOVE"
case "$KIND" in test|lint|build) ;; *) die "kind is test, lint or build, got: $KIND" ;; esac

DIR="$REPORT/move-$MOVE"
mkdir -p "$DIR" || die "cannot create $DIR"
had=$(ls "$DIR" 2>/dev/null | grep -c '^run-[0-9]*-.*\.txt$')
if (( had >= RUNS_PER_MOVE )); then
  echo "BOUND: move $MOVE has had three runs — defer it"
  exit 3
fi
k=$(( had + 1 ))
OUTFILE="$DIR/run-$k-$KIND.txt"

if (( $# == 1 )); then
  bash -c "$1" > "$OUTFILE" 2>&1
else
  "$@" > "$OUTFILE" 2>&1
fi
code=$?
echo "$KIND run $k/$RUNS_PER_MOVE: exit $code"
tail -n "$TAIL_LINES" "$OUTFILE"
exit "$code"
