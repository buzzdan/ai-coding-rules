#!/usr/bin/env bash
# Gap linter of the linter-driven-development plugin.
#
# Measures the design triggers no linter holds, or that the repository's linter
# does not hold yet: lines per source file and source files per directory. It
# never edits a file. Where the repository's linter has a file-length rule, the
# linter owns file length and this script leaves it alone.
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
# Thresholds, per language — the "threshold:" line says which one a run used:
#   file-length: when a linter config at the repository root names a
#      file-length rule, the linter holds it: the line names the rule and the
#      script measures nothing more. Else the limit is file_max_lines in
#      .ldd-lint.yaml, else the plugin's default, 450 code lines (blank and
#      comment-only lines are not counted); with the default, the line also
#      prints the linter setting that would hold the limit, as a proposal for
#      the repository's owners: the script and its caller never edit a config
#   package-size: no linter counts files per directory. package_warn_files and
#      package_max_files in .ldd-lint.yaml, else the plugin's defaults: a
#      warning at 8 source files per directory and the limit at 13
#
# What is measured: the language's source files, minus test files, generated
# files and the directories the language block excludes. A directory count
# also leaves out the files the linter table names (an index module, a package
# marker, generated stubs, stories). Code lines are the lines that keep code
# once comments are removed; a comment marker inside a string literal is code.
# In a git repository an ignored file is never measured or counted, and a
# --files run counts each directory it names in full. A file is over the limit
# when its count is above it; a directory is in the warning zone at the
# warning size and over the limit at the limit.
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

# value <option> <remaining argument count> — a value-taking option needs one
value() { (( $2 >= 2 )) || die "$1 needs a value"; }

while (( $# > 0 )); do
  case "$1" in
    file-length|package-size) [[ -n "$SUBCOMMAND" ]] && die "one subcommand, got also: $1"; SUBCOMMAND="$1"; shift ;;
    --root)    value "$1" $#; ROOT="$2"; shift 2 ;;
    --files)   value "$1" $#; FILES_LIST="$2"; shift 2 ;;
    --tsv)     TSV=1; shift ;;
    --glob)    value "$1" $#; OPT_GLOB="$2"; shift 2 ;;
    --test-re) value "$1" $#; OPT_TEST_RE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)         die "unknown argument: $1 (see --help)" ;;
  esac
done
[[ -n "$SUBCOMMAND" ]] || die "name a subcommand: file-length or package-size (see --help)"
[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
if [[ -n "$FILES_LIST" ]]; then
  [[ -f "$FILES_LIST" ]] || die "no such file list: $FILES_LIST"
  [[ "$FILES_LIST" == /* ]] || FILES_LIST="$(pwd)/$FILES_LIST"
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
# which source files a directory count leaves out, and whether the
# repository's own linter holds the file-length limit. The same table is
# rendered into every plugin, so two plugins measure one file the same way.
# residue-exempt: the table names every language's linter and config file on
# purpose, the same in every rendering.
#
#   lint_comment_style <id>         c (// and /* */), d (also /+ +/) or hash (#)
#   lint_strip_comments <style> <file>  the file with every comment removed and
#                                   string literals kept, one output line per
#                                   input line: a comment-only line prints empty.
#                                   Styles: c, d, hash (# and triple-quoted
#                                   strings), ini (# and a leading ;)
#   lint_package_skip_re <id>       ERE over a relative path: source files a
#                                   directory count leaves out (an index module,
#                                   a package marker, generated stubs); "" for none
#   lint_file_length_rule <id>      "<rule> in <config file>" when a linter config
#                                   at the repository root names a file-length
#                                   rule outside a comment, else
#                                   nothing. A named rule belongs to the linter:
#                                   its limit, its counting and whether it is on
#                                   are the repository's decision.
#   lint_file_length_snippet <id> <max>  the linter setting that would hold the
#                                   limit, or the .ldd-lint.yaml entry when no
#                                   linter rule is known: text to propose

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
    typescript|javascript) printf '%s' '(^|/)index\.[cm]?[jt]sx?$|\.stories\.[cm]?[jt]sx?$' ;;
  esac
  return 0
}

# LINT_STRIP_AWK walks each line one character at a time. A quote opens a
# string that a comment marker cannot end; single and double quotes close at
# the end of the line, a backtick string (c and d) and a triple-quoted string
# (hash) run on. A block comment may open after code and run on. The awk uses
# substr and string compares only, so mawk, gawk and BSD awk read it alike.
LINT_STRIP_AWK='
BEGIN { bq = sprintf("%c", 96); sq = sprintf("%c", 39); dq = "\"" }
{
  line = $0; out = ""; n = length(line); i = 1
  if (q == dq || q == sq) q = ""
  while (i <= n) {
    if (inblock) {
      if (substr(line, i, length(closer)) == closer) { inblock = 0; i += length(closer); out = out " "; continue }
      i++; continue
    }
    ch = substr(line, i, 1)
    if (q != "") {
      if (ch == "\\" && (q == dq || q == sq)) { out = out substr(line, i, 2); i += 2; continue }
      if (substr(line, i, length(q)) == q) { out = out q; i += length(q); q = ""; continue }
      out = out ch; i++; continue
    }
    if (style == "hash" || style == "ini") {
      if (ch == "#") break
      if (style == "ini" && ch == ";" && out ~ /^[ \t]*$/) break
      three = substr(line, i, 3)
      if (style == "hash" && (three == dq dq dq || three == sq sq sq)) { q = three; out = out three; i += 3; continue }
    } else {
      two = substr(line, i, 2)
      if (two == "//") break
      if (two == "/*" || (style == "d" && two == "/+")) { inblock = 1; closer = (two == "/+") ? "+/" : "*/"; out = out " "; i += 2; continue }
      if (ch == bq) { q = bq; out = out ch; i++; continue }
    }
    if (ch == dq || ch == sq) { q = ch; out = out ch; i++; continue }
    out = out ch; i++
  }
  print out
}
'

lint_strip_comments() { # <style> <file>
  awk -v style="$1" "$LINT_STRIP_AWK" "$2"
}

# _lint_config_style <config file> — how that config format writes a comment
_lint_config_style() {
  case "$1" in
    *.yaml|*.yml|*.toml) printf 'hash' ;;
    *.cfg|*.ini|.pylintrc|pylintrc) printf 'ini' ;;
    *) printf 'c' ;;
  esac
}

# _lint_names <ERE> <file>... — print the first file whose text outside its
# comments matches the pattern
_lint_names() {
  local re="$1" f; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    lint_strip_comments "$(_lint_config_style "$f")" "./$f" 2>/dev/null | grep -qE -- "$re" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

lint_file_length_rule() {
  local f
  case "$1" in
    go)
      f=$(_lint_names 'file-length-limit' .golangci.yaml .golangci.yml .golangci.toml .golangci.json) \
        && printf 'revive file-length-limit in %s' "$f" ;;
    typescript|javascript)
      local configs=(eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts
                     .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml)
      if f=$(_lint_names 'sonarjs/max-lines([^-a-zA-Z]|$)' "${configs[@]}"); then
        printf 'sonarjs/max-lines in %s' "$f"
      elif f=$(_lint_names '(^|[^-/a-zA-Z])max-lines([^-a-zA-Z]|$)' "${configs[@]}"); then
        printf 'max-lines in %s' "$f"
      fi ;;
    python)
      f=$(_lint_names '^[[:space:]]*max-module-lines[[:space:]]*=' pyproject.toml .pylintrc pylintrc setup.cfg tox.ini) \
        && printf 'pylint max-module-lines in %s' "$f" ;;
  esac
  return 0
}

lint_file_length_snippet() {
  case "$1" in
    go)                    printf "revive in .golangci.yaml: - name: file-length-limit, arguments: [{max: %s, skip-comments: true, skip-blank-lines: true}]" "$2" ;;
    typescript|javascript) printf "the eslint config: 'sonarjs/max-lines': ['error', { maximum: %s }]" "$2" ;;
    python)                printf "pyproject.toml: [tool.pylint.format] max-module-lines = %s (pylint counts every line, comments and blank lines too)" "$2" ;;
    *)                     printf "no linter rule is known for %s; a .ldd-lint.yaml entry file_max_lines: %s would state this limit" "$1" "$2" ;;
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
# SCOPE: one "id TAB path" line per source file the run measures. INVENTORY:
# the same for every source file of the repository, which a directory count
# reads, so a scoped run still counts a directory's files outside its list.
# Both come from git when the root is a repository, so an ignored file is in
# neither. Sorted, so two runs over one tree print the same thing.
list_repo() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -co --exclude-standard
  else
    find . -type f -not -path './.git/*' | sed 's|^\./||'
  fi
}

list_candidates() {
  if [[ -n "$FILES_LIST" ]]; then
    sed -e 's/ (not bundled:.*$//' -e 's|^\./||' "$FILES_LIST"
  else
    list_repo
  fi
}

# by_language — reads paths, prints "id TAB path" for this plugin's languages
by_language() {
  local f id
  while IFS= read -r f; do
    [[ -n "$f" && -f "$f" ]] || continue
    id=$(lang_of_path "$f")
    [[ -n "$id" ]] || continue
    case " $LANG_NATIVE " in *" $id "*) ;; *) continue ;; esac
    printf '%s\t%s\n' "$id" "$f"
  done | LC_ALL=C sort -u
}

SCOPE=$(mktemp)
INVENTORY=$(mktemp)
trap 'rm -f "$SCOPE" "$INVENTORY"' EXIT
list_candidates | by_language > "$SCOPE"
if [[ -n "$FILES_LIST" ]]; then list_repo | by_language > "$INVENTORY"; else cp "$SCOPE" "$INVENTORY"; fi

# measured <path> — exit 0 when the file counts for this language: not under
# an excluded directory, not a test, not generated. Every path the script
# hands to find, head or awk starts with "./", and a directory is cut from a
# path by parameter expansion, so a name that starts with "-" is never read as
# an option.
measured() {
  printf '%s\n' "$1" | grep -qE -- "$LANG_EXCLUDE_RE" && return 1
  lang_is_test "$1" && return 1
  head -20 "./$1" 2>/dev/null | grep -qE -- "$LANG_GENERATED_RE" && return 1
  return 0
}

# ---------- file-length ----------
# code_lines <id> <path> — the lines that keep code after comments are removed
code_lines() {
  lint_strip_comments "$(lint_comment_style "$1")" "./$2" | awk 'NF { n++ } END { print n + 0 }'
}

run_file_length() { # <id> — every measured file of that language
  local id="$1" rule max src f n o
  rule=$(lint_file_length_rule "$id")
  if [[ -n "$rule" ]]; then
    say "threshold: $id file length — held by $rule; the repository's linter reports long files, so this script measures none"
    return 0
  fi
  o=$(override file_max_lines) || exit 2
  if [[ -n "$o" ]]; then
    max="$o"; src="$OVERRIDE_FILE"
    say "threshold: $id file length — set by $OVERRIDE_FILE ($max code lines)"
  else
    max="$DEFAULT_FILE_MAX_LINES"; src="profile default"
    say "threshold: $id file length — profile default ($max code lines); the repository's linter does not hold it; a setting to propose, never to add on your own: $(lint_file_length_snippet "$id" "$max")"
  fi
  while IFS=$'\t' read -r _ f; do
    measured "$f" || continue
    n=$(code_lines "$id" "$f")
    (( n > max )) && finding "$f" "$n code lines (limit $max, $src)"
  done < <(awk -F'\t' -v id="$id" '$1 == id' "$SCOPE")
}

# ---------- package-size ----------
run_package_size() { # <id> — every directory that holds a measured file of that language
  local id="$1" warn lim src ow om skip d n
  ow=$(override package_warn_files) || exit 2
  om=$(override package_max_files) || exit 2
  warn="${ow:-$DEFAULT_PACKAGE_WARN_FILES}"; lim="${om:-$DEFAULT_PACKAGE_MAX_FILES}"
  (( warn < lim )) || die "$OVERRIDE_FILE: package_warn_files ($warn) must be below package_max_files ($lim)"
  if [[ -n "$ow$om" ]]; then src="$OVERRIDE_FILE"; else src="profile default"; fi
  say "threshold: $id package size — $src (warning at $warn source files per directory, limit $lim); no linter counts files per directory"
  skip=$(lint_package_skip_re "$id")
  local counts; counts=$(mktemp)
  # one "dir TAB count" line per directory of the inventory
  awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$INVENTORY" | while IFS= read -r f; do
    [[ -n "$skip" ]] && printf '%s\n' "$f" | grep -qE -- "$skip" && continue
    measured "$f" || continue
    case "$f" in */*) printf '%s\n' "${f%/*}" ;; *) printf '.\n' ;; esac
  done | LC_ALL=C sort | uniq -c | awk '{ n = $1; sub(/^[ \t]*[0-9]+[ \t]/, ""); print $0 "\t" n }' > "$counts"
  while IFS= read -r d; do
    n=$(awk -F'\t' -v d="$d" '$1 == d { print $2; exit }' "$counts")
    n="${n:-0}"
    if (( n >= lim )); then
      finding "$d" "$n source files (limit $lim, $src)"
    elif (( n >= warn )); then
      finding "$d" "$n source files (warning at $warn, $src)"
    fi
  done < <(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$SCOPE" | while IFS= read -r f; do
             measured "$f" || continue
             case "$f" in */*) printf '%s\n' "${f%/*}" ;; *) printf '.\n' ;; esac
           done | LC_ALL=C sort -u)
  rm -f "$counts"
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
