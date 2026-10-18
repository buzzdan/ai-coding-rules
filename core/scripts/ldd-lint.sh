#!/usr/bin/env bash
# Gap linter of the {{.Plugin}} plugin.
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
#                          know ({{.Lang}} block below)
#   --test-re <ERE>        test-file pattern over relative paths
#
# Thresholds, per language, first that applies — the "threshold:" line says
# which one a run used:
#   1. the repository's linter config holds the rule: its limit, counted the
#      way that linter counts (file-length only; no linter counts files per
#      directory); a config the table cannot read is named, then skipped
#   2. .ldd-lint.yaml at the repository root: file_max_lines,
#      package_warn_files, package_max_files, each a positive integer
#   3. the plugin's defaults: {{.FileMaxLines}} code lines per file (blank and
#      comment-only lines not counted); a warning at {{.PackageWarnFiles}} source files per
#      directory and the limit at {{.PackageMaxFiles}}; for file-length, the line also
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
DEFAULT_FILE_MAX_LINES={{.FileMaxLines}}
DEFAULT_PACKAGE_WARN_FILES={{.PackageWarnFiles}}
DEFAULT_PACKAGE_MAX_FILES={{.PackageMaxFiles}}
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

{{include "scripts/ldd-langs.sh"}}

{{include "scripts/ldd-lang.sh"}}

{{include "scripts/ldd-lint-langs.sh"}}

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
