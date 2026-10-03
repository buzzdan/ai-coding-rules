#!/usr/bin/env bash
# PreToolUse hook of the linter-driven-development plugin: the move implementer's
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
LANG_VERIFY_RE='(^|[^A-Za-z0-9_./-])((\S*/)?(go\s+(-C\s+\S+\s+)?(test|vet|build)|golangci-lint|staticcheck|gofmt|pytest|python[0-9.]*\s+-m\s+(pytest|unittest|ruff|mypy|pyright|flake8|pylint)|ruff\s+(check|format)|mypy|pyright|flake8|pylint|tox|nox|npm\s+(test|run\s+(test|lint|build))|yarn\s+(test|lint|build)|pnpm\s+(test|lint|build)|cargo\s+(test|build|clippy|check)|mvn\s+(test|verify|compile)|gradle\s+(test|build|check)|dotnet\s+(test|build))|task\s+\S*(test|lint|build|check|vet)\S*|make\s+(-[A-Za-z]\s+\S+\s+)*\S*(test|lint|build|check|vet)\S*)([^A-Za-z0-9_-]|$)'
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
      printf 'golangci-lint run --allow-parallel-runners --new-from-rev=%s %s\n' "$base" "${pkgs% }" ;;
    python)
      printf 'ruff check %s\n' "$(printf '%s\n' "$@" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')" ;;
    *)
      printf '<the project'"'"'s lint command> %s\n' "$(printf '%s\n' "$@" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')" ;;
  esac
}
# ================== end language block: detected ==================

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
