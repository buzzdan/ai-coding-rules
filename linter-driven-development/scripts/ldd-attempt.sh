#!/usr/bin/env bash
# Verification wrapper of the move implementer for the linter-driven-development plugin.
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

# ==================== language block: detected ====================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here. This is the generic
# plugin's block: it picks a language from the repository's marker file at run
# time — go.mod selects Go, pyproject.toml (or setup.cfg / setup.py) selects
# Python — and a repository with neither takes the source glob from --glob and
# the test-file pattern from --test-re.
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
LANG_VERIFY_RE='(^|[^A-Za-z0-9_./-])(go (test|vet|build)|golangci-lint|staticcheck|gofmt|pytest|python[0-9.]* -m (pytest|unittest|ruff|mypy|pyright|flake8|pylint)|ruff (check|format)|mypy|pyright|flake8|pylint|tox|nox|npm (test|run (test|lint|build))|yarn (test|lint|build)|pnpm (test|lint|build)|cargo (test|build|clippy|check)|mvn (test|verify|compile)|gradle (test|build|check)|dotnet (test|build)|task (test|lint|build)|make (test|lint|build))([^A-Za-z0-9_-]|$)'
LANG_LINT_CONFIG_RE='(^|/)(\.golangci\.ya?ml|pyproject\.toml|setup\.cfg|ruff\.toml|\.flake8)$'

detect_language() {
  if [[ -f go.mod ]]; then printf 'go\n'; return; fi
  if [[ -f pyproject.toml || -f setup.cfg || -f setup.py ]]; then printf 'python\n'; return; fi
  if find . -name go.mod -not -path '*/vendor/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
    printf 'go\n'; return
  fi
  if find . \( -name pyproject.toml -o -name setup.cfg -o -name setup.py \) \
       -not -path '*/.venv/*' -not -path '*/node_modules/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
    printf 'python\n'; return
  fi
  printf 'unknown\n'
}

DETECTED_LANGUAGE=""
lang_configure() {
  DETECTED_LANGUAGE=$(detect_language)
  case "$DETECTED_LANGUAGE" in
    go)
      LANG_SRC_GLOB='*.go'
      LANG_EXCLUDE_RE='(^|/)(vendor|\.git|testdata)/'
      LANG_SUPPRESS_RE='//nolint'
      LANG_COMMENT_RE='//'
      LANG_DIRECTIVE_RE='//(go:|nolint| Output:|line |export |extern )'
      LANG_GENERATED_RE='Code generated .* DO NOT EDIT|DO NOT EDIT|@generated'
      ;;
    python)
      LANG_SRC_GLOB='*.py'
      LANG_EXCLUDE_RE='(^|/)(\.venv|venv|\.git|node_modules|__pycache__|\.tox|build|dist)/'
      LANG_SUPPRESS_RE='#\s*(noqa|type:\s*ignore|ty:\s*ignore)'
      LANG_COMMENT_RE='(#|""")'
      LANG_DIRECTIVE_RE='#\s*(noqa|type:|ty:|pragma|fmt:|pylint:|ruff:|isort:|!)|>>>'
      LANG_GENERATED_RE='Generated by|DO NOT EDIT|@generated|automatically generated'
      ;;
    *)
      if [[ -z "${OPT_GLOB:-}" ]]; then
        echo "$SCRIPT_NAME: no go.mod or pyproject.toml found; pass --glob '<source glob>' (and --test-re '<ERE>' for test files)" >&2
        return 2
      fi
      LANG_SRC_GLOB="$OPT_GLOB"
      LANG_EXCLUDE_RE='(^|/)(vendor|\.git|node_modules|\.venv|target|build|dist)/'
      LANG_SUPPRESS_RE='nolint|noqa|eslint-disable|#\[allow\(|@SuppressWarnings|type:\s*ignore|NOSONAR|rubocop:disable'
      LANG_COMMENT_RE='(//|#|/\*|--|""")'
      LANG_DIRECTIVE_RE='//go:|nolint|#\s*(noqa|type:|pragma|!)|eslint-|@ts-|pragma'
      LANG_GENERATED_RE='DO NOT EDIT|@generated|automatically generated|Generated by'
      ;;
  esac
  [[ -n "${OPT_GLOB:-}" ]] && LANG_SRC_GLOB="$OPT_GLOB"
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  case "$DETECTED_LANGUAGE" in
    go) [[ "$1" == *_test.go ]] ;;
    python)
      case "$1" in
        *_test.py|test_*.py|*/test_*.py|conftest.py|*/conftest.py|tests/*|*/tests/*) return 0 ;;
      esac
      return 1 ;;
    *)
      case "$1" in
        *_test.*|*.test.*|*.spec.*|*Test.*|test_*|*/test_*|test/*|*/test/*|tests/*|*/tests/*|spec/*|*/spec/*|__tests__/*|*/__tests__/*) return 0 ;;
      esac
      return 1 ;;
  esac
}
# lang_lint_delta <base> <files...> — the lint command over the slice's changes
# for the language the repository's marker names; a repository with neither
# marker gets a placeholder the parent replaces with the project's lint command.
lang_lint_delta() {
  local base="$1"; shift
  case "$(detect_language)" in
    go)
      local pkgs
      pkgs=$(for f in "$@"; do d=$(dirname "$f"); printf './%s\n' "${d#./}"; done | LC_ALL=C sort -u | tr '\n' ' ')
      printf 'golangci-lint run --new-from-rev=%s %s\n' "$base" "${pkgs% }" ;;
    python)
      printf 'ruff check %s\n' "$(printf '%s\n' "$@" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')" ;;
    *)
      printf '<the project'"'"'s lint command> %s\n' "$(printf '%s\n' "$@" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')" ;;
  esac
}
# ================== end language block: detected ==================

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
