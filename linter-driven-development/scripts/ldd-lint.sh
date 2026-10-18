#!/usr/bin/env bash
# Gap linter of the linter-driven-development plugin.
#
# Measures the design triggers no linter holds, or that the repository's linter
# does not hold yet: lines per source file and source files per directory. It
# never edits a file. Where the repository's linter holds a limit, that limit
# is the one applied, counted the way that linter counts.
#
# Usage:  bash scripts/ldd-lint.sh <subcommand> [options]
#   file-length            source files over the file-length limit
#   package-size           directories at or over the warning size or the limit
#   --root <dir>           the repository (default: cwd)
#   --files <list>         measure the source files this list names, one
#                          relative path per line (a scope bundle's files.txt
#                          works: a "(not bundled: …)" suffix is ignored);
#                          default: every source file of the repository
#   --tsv                  findings as rows: path TAB line TAB message, line 0;
#                          the threshold lines then go to stderr
#   --glob <pattern>       source-file glob, for a language the table does not
#                          know (any-language block below)
#   --test-re <ERE>        test-file pattern over relative paths
#
# Thresholds, per language, first that applies — the "threshold:" line says
# which one a run used:
#   1. the repository's linter config holds the rule: its limit, counted the
#      way that linter counts (file-length only; no linter counts files per
#      directory); a config the table cannot read is named, then skipped
#   2. .ldd-lint.yaml at the repository root: file_max_lines,
#      package_warn_files, package_max_files, each a positive integer
#   3. the plugin's defaults: 450 code lines per file (blank and
#      comment-only lines not counted); a warning at 8 source files per
#      directory and the limit at 13; for file-length, the line also
#      prints the setting that makes the repository's linter hold the limit
#
# What is measured: the language's source files, minus test files, generated
# files and the directories the language block excludes. A directory count
# also leaves out the files the linter table names (an index module, a package
# marker, generated stubs). A file is over the limit when its count is above
# it; a directory is in the warning zone at the warning size and over the
# limit at the limit.
#
# Exit codes: 0 measured, with or without findings · 2 usage error, a --files
#             list that does not exist, or a .ldd-lint.yaml value that is not a
#             positive integer (inconclusive, never silently clean)
#
# Uses only POSIX-portable tools plus git when the root is a repository:
# grep, sed, awk, sort, find, head.

set -u

SCRIPT_NAME="ldd-lint"
DEFAULT_FILE_MAX_LINES=450
DEFAULT_PACKAGE_WARN_FILES=8
DEFAULT_PACKAGE_MAX_FILES=13
OVERRIDE_FILE=".ldd-lint.yaml"
ROOT="$(pwd)"
FILES_LIST=""
TSV=0
OPT_GLOB=""
OPT_TEST_RE=""
SUBCOMMAND=""

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

while (( $# > 0 )); do
  case "$1" in
    file-length|package-size) [[ -n "$SUBCOMMAND" ]] && die "one subcommand, got also: $1"; SUBCOMMAND="$1"; shift ;;
    --root)    ROOT="${2:-}"; shift 2 ;;
    --files)   FILES_LIST="${2:-}"; shift 2 ;;
    --tsv)     TSV=1; shift ;;
    --glob)    OPT_GLOB="${2:-}"; shift 2 ;;
    --test-re) OPT_TEST_RE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *)         die "unknown argument: $1 (see --help)" ;;
  esac
done
[[ -n "$SUBCOMMAND" ]] || die "name a subcommand: file-length or package-size (see --help)"
[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
if [[ -n "$FILES_LIST" ]]; then
  [[ -f "$FILES_LIST" ]] || die "no such file list: $FILES_LIST"
  FILES_LIST=$(cd "$(dirname "$FILES_LIST")" && pwd)/$(basename "$FILES_LIST")
fi
cd "$ROOT" || exit 2

# ==================== language table ====================
# How a file's language is told, and which plugin owns a language. The same
# table is rendered into every plugin, so two plugins that split one scope
# agree on every file. The language block below says which of these ids this
# plugin reviews itself; the rest are routed to the plugin that owns them.
# residue-exempt: the table names every language's extension and plugin on
# purpose, the same in every rendering.
#
#   lang_of_path <path>       the language id of a source file, by extension:
#                             "custom" for a file matching --glob (then nothing
#                             else is a source file), "" for a file that is not
#                             source (a manifest, a doc, a build file)
#   dedicated_plugin_for <id> the plugin written for that language, or ""
#   GENERIC_PLUGIN            the plugin that reviews any language
#   installed_plugin_dir <n>  where plugin <n> is installed, from the
#                             installed-plugins file, or "" when it is not;
#                             LDD_INSTALLED_PLUGINS names another file
GENERIC_PLUGIN='linter-driven-development'

# A .h header is C++ when the repository has C++ sources, C otherwise.
HEADER_LANG=""
header_lang() {
  [[ -n "$HEADER_LANG" ]] && { printf '%s' "$HEADER_LANG"; return; }
  if { git ls-files -- '*.cpp' '*.cc' '*.cxx' '*.hpp' 2>/dev/null || find . -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' -o -name '*.hpp' \) -not -path './.git/*' 2>/dev/null; } | head -1 | grep -q .; then
    HEADER_LANG=cpp
  else
    HEADER_LANG=c
  fi
  printf '%s' "$HEADER_LANG"
}

lang_of_path() {
  local b="${1##*/}"
  if [[ -n "${OPT_GLOB:-}" ]]; then
    case "$b" in $OPT_GLOB) printf 'custom' ;; esac
    return 0
  fi
  case "$b" in
    *.go)                                   printf 'go' ;;
    *.py)                                   printf 'python' ;;
    *.d|*.di)                               printf 'd' ;;
    *.rs)                                   printf 'rust' ;;
    *.c)                                    printf 'c' ;;
    *.h)                                    header_lang ;;
    *.cpp|*.cc|*.cxx|*.hpp|*.hh|*.hxx)      printf 'cpp' ;;
    *.java)                                 printf 'java' ;;
    *.kt|*.kts)                             printf 'kotlin' ;;
    *.rb)                                   printf 'ruby' ;;
    *.sh|*.bash)                            printf 'shell' ;;
    *.ts|*.tsx)                             printf 'typescript' ;;
    *.js|*.jsx|*.mjs|*.cjs)                 printf 'javascript' ;;
    *.cs)                                   printf 'csharp' ;;
  esac
  return 0
}

dedicated_plugin_for() {
  case "$1" in
    go|python)              printf '%s-linter-driven-development' "$1" ;;
    typescript|javascript)  printf 'ts-react-linter-driven-development' ;;
  esac
  return 0
}

installed_plugin_dir() {
  local f="${LDD_INSTALLED_PLUGINS:-$HOME/.claude/plugins/installed_plugins.json}"
  [[ -f "$f" ]] || return 0
  awk -v key="\"$1@" '
    index($0, key) { found = 1; next }
    found && /"installPath"/ { sub(/^[^:]*:[ \t]*"/, ""); sub(/".*$/, ""); print; exit }
  ' "$f"
}
# ================== end language table ==================

# ==================== language block: any language ====================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here. This is the generic
# plugin's block: one row per language the language table above names, so a
# group of any of them is reviewed here when no plugin written for that
# language is installed. Which file is which language is the table, shared by
# every plugin; this block only says how each language writes a comment, a
# suppression directive and a test file.
#
# Contract:
#   LANG_NATIVE         the language ids this plugin reviews itself; a group of
#                       any other id is routed to the plugin that owns it
#   lang_configure <id> sets the variables below for that id; "custom" is the
#                       --glob override: a language the table does not know,
#                       reviewed with the broad row at the end;
#                       exit 2 for an id this block has no row for
#   LANG_EXCLUDE_RE     ERE over a relative path: directories never in scope
#   LANG_SUPPRESS_RE    ERE: a lint-suppression directive on a source line
#   LANG_COMMENT_RE     ERE: a source line that carries a comment (bracket
#                       expressions, no backslashes: the driver hands it to
#                       awk -v, which eats `\*` under gawk)
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_is_test <path> exit 0 iff the path is a test file (--test-re overrides)
LANG_NATIVE="go python d rust c cpp java kotlin ruby shell typescript javascript csharp custom"
LANG_ID=""

lang_configure() {
  LANG_ID="$1"
  LANG_GENERATED_RE='Code generated .* DO NOT EDIT|DO NOT EDIT|@generated|automatically generated|Generated by'
  case "$1" in
    go)
      LANG_EXCLUDE_RE='(^|/)(vendor|\.git|testdata)/'
      LANG_SUPPRESS_RE='//nolint'
      LANG_COMMENT_RE='//'
      LANG_DIRECTIVE_RE='//(go:|nolint| Output:|line |export |extern )'
      ;;
    python)
      LANG_EXCLUDE_RE='(^|/)(\.venv|venv|\.git|node_modules|__pycache__|\.tox|build|dist)/'
      LANG_SUPPRESS_RE='#\s*(noqa|type:\s*ignore|ty:\s*ignore)'
      LANG_COMMENT_RE='(#|""")'
      LANG_DIRECTIVE_RE='#\s*(noqa|type:|ty:|pragma|fmt:|pylint:|ruff:|isort:|!)|>>>'
      ;;
    d)
      # D comments: // line, /* block */ and /+ nested +/. D-Scanner's
      # suppression is a comment: // @suppress(dscanner.<check>). A file's
      # inline `unittest` blocks test the production code beside them and keep
      # the file a production file; a test file is one under a test directory
      # or named *_test.d.
      LANG_EXCLUDE_RE='(^|/)(\.git|\.dub|vendor)/'
      LANG_SUPPRESS_RE='@suppress\('
      LANG_COMMENT_RE='(//|/[*]|/[+])'
      LANG_DIRECTIVE_RE='@suppress\(|dfmt (on|off)|#!'
      ;;
    rust)
      LANG_EXCLUDE_RE='(^|/)(\.git|target|vendor)/'
      LANG_SUPPRESS_RE='#!?\[allow\('
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='rustfmt::skip|clippy::'
      ;;
    c|cpp)
      LANG_EXCLUDE_RE='(^|/)(\.git|third_party|vendor)/'
      LANG_SUPPRESS_RE='NOLINT|cppcheck-suppress|#pragma (warning\s*\(\s*disable|GCC diagnostic ignored|clang diagnostic ignored)'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='NOLINT|cppcheck-suppress|clang-format (on|off)|IWYU'
      ;;
    java|kotlin)
      LANG_EXCLUDE_RE='(^|/)(\.git|target|build|\.gradle)/'
      LANG_SUPPRESS_RE='@Suppress(Warnings)?\(|NOSONAR|noinspection|CHECKSTYLE:OFF|ktlint-disable|detekt:'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='noinspection|CHECKSTYLE|NOSONAR|@formatter:|ktlint-|detekt:'
      ;;
    ruby)
      LANG_EXCLUDE_RE='(^|/)(\.git|vendor/bundle|tmp)/'
      LANG_SUPPRESS_RE='rubocop:disable|steep:ignore'
      LANG_COMMENT_RE='(#|=begin)'
      LANG_DIRECTIVE_RE='rubocop:|frozen_string_literal|encoding:|#!'
      ;;
    shell)
      LANG_EXCLUDE_RE='(^|/)(\.git)/'
      LANG_SUPPRESS_RE='shellcheck disable'
      LANG_COMMENT_RE='#'
      LANG_DIRECTIVE_RE='shellcheck|#!'
      ;;
    typescript|javascript)
      LANG_EXCLUDE_RE='(^|/)(\.git|node_modules|dist)/'
      LANG_SUPPRESS_RE='eslint-disable|@ts-(ignore|expect-error|nocheck)|biome-ignore'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='eslint-|@ts-|prettier-ignore|biome-ignore|/// *<reference|#!'
      ;;
    csharp)
      LANG_EXCLUDE_RE='(^|/)(\.git|bin|obj)/'
      LANG_SUPPRESS_RE='#pragma warning disable|\[SuppressMessage'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='ReSharper|#pragma'
      ;;
    custom)
      # A language the table does not know: every common comment marker and
      # suppression spelling, so --glob reviews it without a row of its own.
      LANG_EXCLUDE_RE='(^|/)(vendor|\.git|node_modules|\.venv|target|build|dist)/'
      LANG_SUPPRESS_RE='nolint|noqa|eslint-disable|#\[allow\(|@SuppressWarnings|type:\s*ignore|NOSONAR|rubocop:disable|shellcheck disable'
      LANG_COMMENT_RE='(//|#|/[*]|--|""")'
      LANG_DIRECTIVE_RE='//go:|nolint|#\s*(noqa|type:|pragma|!)|eslint-|@ts-|pragma'
      ;;
    *) return 2 ;;
  esac
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  case "$LANG_ID" in
    go) [[ "$1" == *_test.go ]] ;;
    python)
      case "$1" in
        *_test.py|test_*.py|*/test_*.py|conftest.py|*/conftest.py|tests/*|*/tests/*) return 0 ;;
      esac
      return 1 ;;
    d)
      case "$1" in
        *_test.d|test/*|*/test/*|tests/*|*/tests/*|testing/*|*/testing/*) return 0 ;;
      esac
      return 1 ;;
    rust)
      case "$1" in
        *_test.rs|tests/*|*/tests/*|benches/*|*/benches/*) return 0 ;;
      esac
      return 1 ;;
    java|kotlin)
      case "$1" in
        *Test.java|*Tests.java|*IT.java|*Test.kt|*Tests.kt|src/test/*|*/src/test/*|src/*Test/*|*/src/*Test/*) return 0 ;;
      esac
      return 1 ;;
    ruby)
      case "$1" in
        *_spec.rb|*_test.rb|spec/*|*/spec/*|test/*|*/test/*) return 0 ;;
      esac
      return 1 ;;
    csharp)
      case "$1" in
        *Test.cs|*Tests.cs|*.Tests/*|*/*.Tests/*|test/*|*/test/*|tests/*|*/tests/*) return 0 ;;
      esac
      return 1 ;;
    *)
      case "$1" in
        *_test.*|*.test.*|*.spec.*|*Test.*|test_*|*/test_*|test/*|*/test/*|tests/*|*/tests/*|spec/*|*/spec/*|__tests__/*|*/__tests__/*) return 0 ;;
      esac
      return 1 ;;
  esac
}
# ================== end language block: any language ==================

# ==================== linter table ====================
# What the gap linter needs to know per language id: how a comment is written,
# which source files a directory count leaves out, and where the repository's
# own linter sets a file-length limit. The same table is rendered into every
# plugin, so two plugins measure one file the same way.
# residue-exempt: the table names every language's linter and config file on
# purpose, the same in every rendering.
#
#   lint_comment_style <id>         c (// and /* */), d (also /+ +/) or hash (#)
#   lint_package_skip_re <id>       ERE over a relative path: source files a
#                                   directory count leaves out (an index module,
#                                   a package marker, generated stubs); "" for none
#   lint_file_length_config <id>    one line, from the repository root:
#                                   covered TAB <max> TAB <skip-comments 0|1> TAB
#                                     <skip-blank 0|1> TAB <rule and file>
#                                   unreadable TAB <rule and file>
#                                   none
#   lint_file_length_snippet <id> <max>  the setting that makes the repository's
#                                   linter hold the limit, or how to set it when
#                                   no linter rule is known

lint_comment_style() {
  case "$1" in
    python|ruby|shell) printf 'hash' ;;
    d)                 printf 'd' ;;
    *)                 printf 'c' ;;
  esac
}

lint_package_skip_re() {
  case "$1" in
    go)                    printf '%s' '(_gen|\.pb)\.go$' ;;
    python)                printf '%s' '(^|/)(__init__|conftest)\.py$|_pb2(_grpc)?\.py$' ;;
    typescript|javascript) printf '%s' '(^|/)index\.[cm]?[jt]sx?$' ;;
  esac
  return 0
}

# _lint_window <key ERE> <file> — the key's line and the lines after it, up to
# the next rule entry or 15 lines, joined by spaces; one window per match. The
# patterns reach awk as strings, so they use bracket expressions, never
# backslash escapes, which awk -v would rewrite.
_lint_window() {
  awk -v key="$1" -v q="'" '
    BEGIN {
      entry = "^[[:space:]]*-[[:space:]]*[{]?[[:space:]]*name:"
      qkey = "^[[:space:]]*[\"" q "][^\"" q "]+[\"" q "][[:space:]]*:"
    }
    function flush() { if (w != "") print w; w = ""; n = 0 }
    {
      if (n > 0 && ($0 ~ entry || $0 ~ qkey) && $0 !~ key) flush()
      if ($0 ~ key) { flush(); n = 1; w = $0; next }
      if (n > 0) { w = w " " $0; if (++n > 15) flush() }
    }
    END { flush() }
  ' "$2"
}

# _lint_number <ERE ending in the number> <text> — the first match's digits
_lint_number() {
  printf '%s\n' "$2" | awk -v re="$1" 'match($0, re) { v = substr($0, RSTART, RLENGTH); sub(/.*[^0-9]/, "", v); print v; exit }'
}

# _lint_off <text> — exit 0 when the rule in the window is switched off
_lint_off() {
  printf '%s\n' "$1" | grep -qE "max-lines[\"']?[[:space:]]*:[[:space:]]*[[]?[[:space:]]*[\"']?(off|0)([^0-9]|$)"
}

_lint_config_go() {
  local f w max sc sb unread=""
  for f in .golangci.yaml .golangci.yml .golangci.toml .golangci.json; do
    [[ -f "$f" ]] || continue
    grep -q 'file-length-limit' "$f" 2>/dev/null || continue
    case "$f" in *.toml|*.json) unread="revive file-length-limit in $f"; continue ;; esac
    while IFS= read -r w; do
      [[ "$w" =~ disabled:[[:space:]]*true ]] && continue
      max=$(_lint_number 'max:[[:space:]]*[0-9]+' "$w")
      [[ -z "$max" ]] && max=$(_lint_number 'arguments:[[:space:]]*[[][[:space:]]*[0-9]+' "$w")
      [[ -z "$max" ]] && max=$(_lint_number 'arguments:[[:space:]]*-[[:space:]]*[0-9]+' "$w")
      if [[ -z "$max" ]]; then unread="revive file-length-limit in $f"; continue; fi
      (( max > 0 )) || continue
      sc=0; sb=0
      [[ "$w" =~ skip-comments:[[:space:]]*true ]] && sc=1
      [[ "$w" =~ skip-blank-lines:[[:space:]]*true ]] && sb=1
      printf 'covered\t%s\t%s\t%s\trevive file-length-limit in %s\n' "$max" "$sc" "$sb" "$f"
      return 0
    done < <(_lint_window "name:[[:space:]]*[\"']?file-length-limit" "$f")
  done
  [[ -n "$unread" ]] && { printf 'unreadable\t%s\n' "$unread"; return 0; }
  printf 'none\n'
}

_lint_config_eslint() {
  local f w max sc sb
  for f in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts \
           .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml; do
    [[ -f "$f" ]] || continue
    grep -q 'max-lines' "$f" 2>/dev/null || continue
    # sonarjs/max-lines counts lines of code: blank and comment-only lines are skipped.
    while IFS= read -r w; do
      w="${w%%]*}"
      _lint_off "$w" && continue
      max=$(_lint_number 'maximum[[:space:]]*:[[:space:]]*[0-9]+' "$w")
      printf 'covered\t%s\t1\t1\tsonarjs/max-lines in %s\n' "${max:-1000}" "$f"
      return 0
    done < <(_lint_window "sonarjs/max-lines[\"']?[[:space:]]*:" "$f")
    # ESLint's own max-lines counts every line unless skipComments or skipBlankLines say otherwise.
    while IFS= read -r w; do
      w="${w%%]*}"
      _lint_off "$w" && continue
      max=$(_lint_number '[^a-zA-Z]max[[:space:]]*:[[:space:]]*[0-9]+' "$w")
      [[ -z "$max" ]] && max=$(_lint_number "(error|warn|[12])[\"']?[[:space:]]*,[[:space:]]*[0-9]+" "$w")
      sc=0; sb=0
      [[ "$w" =~ skipComments[[:space:]]*:[[:space:]]*true ]] && sc=1
      [[ "$w" =~ skipBlankLines[[:space:]]*:[[:space:]]*true ]] && sb=1
      printf 'covered\t%s\t%s\t%s\tmax-lines in %s\n' "${max:-300}" "$sc" "$sb" "$f"
      return 0
    done < <(_lint_window "(^|[^/A-Za-z-])[\"']?max-lines[\"']?[[:space:]]*:" "$f")
  done
  printf 'none\n'
}

_lint_config_python() {
  local f line max unread=""
  for f in pyproject.toml .pylintrc pylintrc setup.cfg tox.ini; do
    [[ -f "$f" ]] || continue
    line=$(grep -E '^[[:space:]]*max-module-lines[[:space:]]*=' "$f" 2>/dev/null | head -1)
    [[ -n "$line" ]] || continue
    max=$(_lint_number "=[[:space:]]*[\"']?[0-9]+" "$line")
    if [[ -z "$max" ]]; then unread="pylint max-module-lines in $f"; continue; fi
    (( max > 0 )) || continue
    # pylint counts every line of the module.
    printf 'covered\t%s\t0\t0\tpylint max-module-lines in %s\n' "$max" "$f"
    return 0
  done
  [[ -n "$unread" ]] && { printf 'unreadable\t%s\n' "$unread"; return 0; }
  printf 'none\n'
}

lint_file_length_config() {
  case "$1" in
    go)                    _lint_config_go ;;
    typescript|javascript) _lint_config_eslint ;;
    python)                _lint_config_python ;;
    *)                     printf 'none\n' ;;
  esac
}

lint_file_length_snippet() {
  case "$1" in
    go)                    printf "revive in .golangci.yaml: - name: file-length-limit, arguments: [{max: %s, skip-comments: true, skip-blank-lines: true}]" "$2" ;;
    typescript|javascript) printf "the eslint config: 'sonarjs/max-lines': ['error', { maximum: %s }]" "$2" ;;
    python)                printf "pyproject.toml: [tool.pylint.format] max-module-lines = %s (pylint counts every line, comments and blank lines too)" "$2" ;;
    *)                     printf "no linter rule is known for %s; set file_max_lines: %s in .ldd-lint.yaml to keep this limit" "$1" "$2" ;;
  esac
}
# ================== end linter table ==================

# ---------- output ----------
# A threshold line is for the reader of the report; with --tsv the rows are
# the output and the threshold lines go to stderr.
say() { if (( TSV )); then printf '%s\n' "$*" >&2; else printf '%s\n' "$*"; fi; }
finding() { # <path> <message>
  if (( TSV )); then printf '%s\t0\t%s\n' "$1" "$2"; else printf '%s: %s\n' "$1" "$2"; fi
}

# ---------- the repository override ----------
# override <key> — the key's value in .ldd-lint.yaml, "" when absent; a value
# that is not a positive integer ends the run, because the file is the
# repository's own statement of its limits.
override() {
  [[ -f "$OVERRIDE_FILE" ]] || return 0
  local v
  v=$(awk -v k="$1" -v q="'" '
    { line = $0; sub(/#.*/, "", line) }
    line ~ "^[[:space:]]*" k "[[:space:]]*:" {
      sub("^[[:space:]]*" k "[[:space:]]*:[[:space:]]*", "", line)
      gsub("[\"" q "[:space:]]", "", line)
      print line; exit
    }' "$OVERRIDE_FILE")
  [[ -z "$v" ]] && return 0
  [[ "$v" =~ ^[0-9]+$ ]] && (( v > 0 )) || die "$OVERRIDE_FILE: $1 must be a positive integer, got: $v"
  printf '%s' "$v"
}

# ---------- the scope ----------
# One "id TAB path" line per source file of a language this plugin reviews,
# sorted, so two runs over one tree print the same thing.
list_candidates() {
  if [[ -n "$FILES_LIST" ]]; then
    sed -e 's/ (not bundled:.*$//' -e 's|^\./||' "$FILES_LIST"
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -co --exclude-standard
  else
    find . -type f -not -path './.git/*' | sed 's|^\./||'
  fi
}

SCOPE=$(mktemp)
trap 'rm -f "$SCOPE"' EXIT
while IFS= read -r f; do
  [[ -n "$f" && -f "$f" ]] || continue
  id=$(lang_of_path "$f")
  [[ -n "$id" ]] || continue
  case " $LANG_NATIVE " in *" $id "*) ;; *) continue ;; esac
  printf '%s\t%s\n' "$id" "$f"
done < <(list_candidates) | LC_ALL=C sort -u > "$SCOPE"

# measured <path> — exit 0 when the file counts for this language: not under
# an excluded directory, not a test, not generated.
measured() {
  printf '%s\n' "$1" | grep -qE -- "$LANG_EXCLUDE_RE" && return 1
  lang_is_test "$1" && return 1
  head -20 "$1" 2>/dev/null | grep -qE -- "$LANG_GENERATED_RE" && return 1
  return 0
}

# ---------- file-length ----------
# COUNT_AWK prints a file's line count under the style's comment syntax:
# skipc drops comment-only lines (block comments included), skipb blank lines.
COUNT_AWK='
function comment_only(t,    rest, i) {
  if (inblock) {
    i = index(t, closer)
    if (i == 0) return 1
    inblock = 0
    rest = substr(t, i + length(closer)); sub(/^[[:space:]]+/, "", rest)
    return rest == "" || comment_only(rest)
  }
  if (style == "hash") return substr(t, 1, 1) == "#"
  if (substr(t, 1, 2) == "//") return 1
  if (substr(t, 1, 2) == "/*" || (style == "d" && substr(t, 1, 2) == "/+")) {
    closer = (substr(t, 2, 1) == "+") ? "+/" : "*/"
    inblock = 1
    return comment_only(substr(t, 3))
  }
  return 0
}
{
  t = $0; sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
  if (t == "") { if (inblock) { if (!skipc) n++ } else if (!skipb) n++; next }
  c = comment_only(t)
  if (c && skipc) next
  n++
}
END { print n + 0 }
'

run_file_length() { # <id> — every measured file of that language
  local id="$1" cfg status max sc sb label src unit f n o
  cfg=$(lint_file_length_config "$id")
  IFS=$'\t' read -r status max sc sb label <<< "$cfg"
  if [[ "$status" == "unreadable" ]]; then
    # an unreadable row carries the rule and file in its second field
    say "threshold: $id file length — $max is set, but its limit cannot be read here; the next source applies"
    status=none
  fi
  if [[ "$status" == "covered" ]]; then
    src="$label"
    say "threshold: $id file length — covered by $label (limit $max)"
  else
    sc=1; sb=1
    o=$(override file_max_lines) || exit 2
    if [[ -n "$o" ]]; then
      max="$o"; src="$OVERRIDE_FILE"
      say "threshold: $id file length — set by $OVERRIDE_FILE ($max code lines)"
    else
      max="$DEFAULT_FILE_MAX_LINES"; src="profile default"
      say "threshold: $id file length — profile default ($max code lines); the repository's linter does not hold it; add $(lint_file_length_snippet "$id" "$max")"
    fi
  fi
  unit="lines"
  (( sc && sb )) && unit="code lines"
  (( sc && ! sb )) && unit="lines without comments"
  (( ! sc && sb )) && unit="non-blank lines"
  while IFS=$'\t' read -r _ f; do
    measured "$f" || continue
    n=$(awk -v style="$(lint_comment_style "$id")" -v skipc="$sc" -v skipb="$sb" "$COUNT_AWK" "$f")
    (( n > max )) && finding "$f" "$n $unit (limit $max, $src)"
  done < <(awk -F'\t' -v id="$id" '$1 == id' "$SCOPE")
}

# ---------- package-size ----------
run_package_size() { # <id> — every directory that holds a measured file of that language
  local id="$1" warn lim src ow om skip d n f
  ow=$(override package_warn_files) || exit 2
  om=$(override package_max_files) || exit 2
  warn="${ow:-$DEFAULT_PACKAGE_WARN_FILES}"; lim="${om:-$DEFAULT_PACKAGE_MAX_FILES}"
  (( warn < lim )) || die "$OVERRIDE_FILE: package_warn_files ($warn) must be below package_max_files ($lim)"
  if [[ -n "$ow$om" ]]; then src="$OVERRIDE_FILE"; else src="profile default"; fi
  say "threshold: $id package size — $src (warning at $warn source files per directory, limit $lim); no linter counts files per directory"
  skip=$(lint_package_skip_re "$id")
  while IFS= read -r d; do
    n=0
    while IFS= read -r f; do
      f="${f#./}"
      [[ "$(lang_of_path "$f")" == "$id" ]] || continue
      [[ -n "$skip" ]] && printf '%s\n' "$f" | grep -qE -- "$skip" && continue
      measured "$f" || continue
      n=$((n + 1))
    done < <(find "$d" -maxdepth 1 -type f | LC_ALL=C sort)
    if (( n >= lim )); then
      finding "$d" "$n source files (limit $lim, $src)"
    elif (( n >= warn )); then
      finding "$d" "$n source files (warning at $warn, $src)"
    fi
  done < <(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$SCOPE" | while IFS= read -r f; do measured "$f" && dirname "$f"; done | LC_ALL=C sort -u)
}

# ---------- run ----------
ids=$(cut -f1 "$SCOPE" | LC_ALL=C sort -u)
if [[ -z "$ids" ]]; then
  say "$SCRIPT_NAME: no source file in scope"
  exit 0
fi
for id in $ids; do
  lang_configure "$id" || continue
  case "$SUBCOMMAND" in
    file-length)  run_file_length "$id" ;;
    package-size) run_package_size "$id" ;;
  esac
done
exit 0
