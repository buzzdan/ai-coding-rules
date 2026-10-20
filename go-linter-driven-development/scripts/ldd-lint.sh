#!/usr/bin/env bash
# Gap linter of the go-linter-driven-development plugin.
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
#                          know (Go block below)
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

# ======================= language block: go =======================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here; a build of the script
# for another language replaces this block and nothing else. Which file is
# which language is the language table above, shared by every plugin.
#
# Contract:
#   LANG_NATIVE         the language ids this plugin reviews itself; a group of
#                       any other id is routed to the plugin that owns it
#   lang_configure <id> sets the variables below for that id; "custom" is the
#                       --glob override, reviewed with this block's defaults;
#                       exit 2 for an id this block has no row for
#   LANG_EXCLUDE_RE     ERE over a relative path: directories never in scope
#   LANG_SUPPRESS_RE    ERE: a lint-suppression directive on a source line
#   LANG_COMMENT_RE     ERE: a source line that carries a comment
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_is_test <path> exit 0 iff the path is a test file (--test-re overrides)
LANG_NATIVE="go custom"

lang_configure() {
  case "$1" in go|custom) ;; *) return 2 ;; esac
  LANG_EXCLUDE_RE='(^|/)(vendor|\.git|testdata)/'
  LANG_SUPPRESS_RE='//nolint'
  LANG_COMMENT_RE='//'
  LANG_DIRECTIVE_RE='//(go:|nolint| Output:|line |export |extern )'
  LANG_GENERATED_RE='Code generated .* DO NOT EDIT|DO NOT EDIT|@generated'
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  [[ "$1" == *_test.go ]]
}
# ===================== end language block: go =====================

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
#   lint_setup_files                one line per recommended config under the
#                                   plugin's setup/: file TAB the tool that checks it
#   lint_setup_check <file> <setup dir> <work dir>  run that tool's own check of
#                                   the file; exit 0 when the tool accepts it
#   lint_file_length_proposal <id>  what would hold the limit in the
#                                   repository's linter: the rule, named after
#                                   the plugin's recommended config under setup/
#                                   that sets it, or the .ldd-lint.yaml entry when
#                                   the language's linter has no such rule

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

lint_setup_files() {
  printf 'golangci.yaml\tgolangci-lint\n'
  printf 'ruff.toml\truff\n'
  printf 'eslint.config.ldd.mjs\tnode\n'
}

lint_setup_check() { # <file> <setup dir> <work dir>
  case "$1" in
    golangci.yaml)         golangci-lint config verify -c "$2/$1" ;;
    ruff.toml)             printf 'x = 1\n' > "$3/ldd_setup_check.py" && (cd "$3" && ruff check --no-cache --config "$2/$1" ldd_setup_check.py) ;;
    eslint.config.ldd.mjs) node --check "$2/$1" ;;
    *)                     return 2 ;;
  esac
}

lint_file_length_proposal() {
  case "$1" in
    go)                    printf "a setting to propose, never to add on your own: revive file-length-limit, as the plugin's setup/golangci.yaml sets it" ;;
    typescript|javascript) printf "a setting to propose, never to add on your own: sonarjs/max-lines, as the plugin's setup/eslint.config.ldd.mjs sets it" ;;
    python)                printf "ruff has no file-length rule, so this script holds the limit; a .ldd-lint.yaml entry file_max_lines: <n> states another" ;;
    *)                     printf "no linter rule is known for %s; a .ldd-lint.yaml entry file_max_lines: <n> states another limit" "$1" ;;
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

# dir_of <path> — the directory part of a relative path, "." for a file at
# the root. A function, because bash 3.2 misreads a case pattern's ")" inside
# a process substitution.
dir_of() {
  case "$1" in
    */*) printf '%s\n' "${1%/*}" ;;
    *)   printf '.\n' ;;
  esac
}

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
    say "threshold: $id file length — profile default ($max code lines); the repository's linter does not hold it; $(lint_file_length_proposal "$id")"
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
    dir_of "$f"
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
             measured "$f" && dir_of "$f"
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
