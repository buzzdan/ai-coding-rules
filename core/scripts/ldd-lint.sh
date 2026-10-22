#!/usr/bin/env bash
# Gap linter of the {{.Plugin}} plugin.
#
# Measures the design triggers no linter holds, or that the repository's linter
# does not hold yet: lines per source file and source files per directory. It
# never edits a file. Where the repository's linter has a file-length rule, the
# linter owns file length and this script leaves it alone. Its doctor compares
# the repository's linter with the plugin's recommended config.
#
# Usage:  bash scripts/ldd-lint.sh <subcommand> [options]
#   file-length            source files over the file-length limit
#   package-size           directories at or over the warning size or the limit
#   doctor                 per language of the repository, each rule of the
#                          plugin's recommended config under setup/: whether
#                          the repository's linter runs it, and the setting on
#                          both sides (below)
#   --root <dir>           the repository, or one project in it, such as a
#                          front end with its own linter config: every
#                          lookup starts there (default: cwd)
#   --files <list>         measure the source files this list names, one
#                          relative path per line (a scope bundle's files.txt
#                          works: a "(not bundled: …)" suffix is ignored);
#                          default: every source file of the repository
#   --tsv                  findings as rows: path TAB line TAB message, line 0;
#                          the threshold lines then go to stderr. doctor rows:
#                          language TAB linter TAB rule TAB state TAB
#                          recommended TAB current TAB source
#   --glob <pattern>       source-file glob, for a language the table does not
#                          know ({{.Lang}} block below)
#   --test-re <ERE>        test-file pattern over relative paths
#
# Thresholds, per language — the "threshold:" line says which one a run used:
#   file-length: when a linter config at the repository root names a
#      file-length rule, the linter holds it: the line names the rule and the
#      script measures nothing more. Else the limit is file_max_lines in
#      .ldd-lint.yaml, else the plugin's default, {{.FileMaxLines}} code lines (blank and
#      comment-only lines are not counted); with the default, the line also
#      prints the linter setting that would hold the limit, as a proposal for
#      the repository's owners: the script and its caller never edit a config
#   package-size: no linter counts files per directory. package_warn_files and
#      package_max_files in .ldd-lint.yaml, else the plugin's defaults: a
#      warning at {{.PackageWarnFiles}} source files per directory and the limit at {{.PackageMaxFiles}}
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
# doctor: the rules are the ones the recommended config enables, as the
# installed linter resolves it, beyond the linter's default set, and the
# default rules the config names that the repository does not run. Each row
# has a state: agreed, runs, missing, limit looser or limit stricter (the
# repository's setting lets more code pass, or less, than the recommended
# one), options differ (the two settings differ in a way that is not one
# limit), named (the rule is named outside comments in the repository's
# config; the linter was not asked), or cannot verify, with the reason (the
# linter is not installed, or rejects a config). recommended and current are
# the setting as the linter reports it; where the linter cannot report it, they
# are "see <file>: <key>", the place a reader looks the value up; "-" is no
# setting. source is "linter" when the linter said whether the rule runs, and
# "presence check" when the rule was found by name. A linter output the doctor
# cannot read is "cannot verify", never an empty list. A "doctor:" line per
# language says which config was compared.
#
# The agreement record is the file .ldd-lint.yaml, which the lint-setup skill
# writes. Its key "agreed" lists one item per rule the team agreed to keep. An
# item is one double-quoted YAML scalar: "<linter> <rule> = <value> | <reason>".
# A backslash and a quote in it are escaped. The value is the setting as the
# doctor shows it in current, or "off", or "org" (the organization owns it). The
# keys "lint_config" and "lint_fingerprint" hold the config files the agreement
# was made against.
#
# The doctor gives a row the state agreed when its rule is agreed and the
# agreed value is org, or:
#   a linter that reports settings: current equals the agreed value, or the
#     rule is missing and agreed off
#   a linter that reports no setting (it says only which rules run): the rule
#     runs and is agreed at any value but off, or it is missing and agreed off
# A row with another value keeps its state, and its current gains
# "; agreed: <value>". A row that cannot verify is never agreed.
#
# Exit codes: 0 measured, with or without findings · 2 usage error, a --files
#             list that does not exist, a .ldd-lint.yaml value that is not a
#             positive integer, or a doctor run with no language the plugin
#             recommends a config for (inconclusive, never silently clean)
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

# value <option> <remaining argument count> — a value-taking option needs one
value() { (( $2 >= 2 )) || die "$1 needs a value"; }

while (( $# > 0 )); do
  case "$1" in
    file-length|package-size|doctor) [[ -n "$SUBCOMMAND" ]] && die "one subcommand, got also: $1"; SUBCOMMAND="$1"; shift ;;
    --root)    value "$1" $#; ROOT="$2"; shift 2 ;;
    --files)   value "$1" $#; FILES_LIST="$2"; shift 2 ;;
    --tsv)     TSV=1; shift ;;
    --glob)    value "$1" $#; OPT_GLOB="$2"; shift 2 ;;
    --test-re) value "$1" $#; OPT_TEST_RE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)         die "unknown argument: $1 (see --help)" ;;
  esac
done
[[ -n "$SUBCOMMAND" ]] || die "name a subcommand: file-length, package-size or doctor (see --help)"
[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
if [[ -n "$FILES_LIST" ]]; then
  [[ -f "$FILES_LIST" ]] || die "no such file list: $FILES_LIST"
  [[ "$FILES_LIST" == /* ]] || FILES_LIST="$(pwd)/$FILES_LIST"
fi
SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/setup"
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

# ---------- the agreement record ----------
# The record is the flat lists of .ldd-lint.yaml; this script reads no other
# structure from it. An item is one double-quoted scalar on a line "  - ".

# record_has <key> — exit 0 when the record has the key, with items or as "[]"
record_has() {
  [[ -f "$OVERRIDE_FILE" ]] && grep -qE -- "^$1[[:space:]]*:" "$OVERRIDE_FILE"
}

# record_items <key> — each item of the key's list, unquoted and unescaped,
# one per line; nothing when the key or the file is absent. The list ends at
# the first line that is not an item. A "#" inside the quotes is data.
record_items() {
  [[ -f "$OVERRIDE_FILE" ]] || return 0
  awk -v k="$1" '
    function item(line,   out, i, c, n) {
      sub(/^[ \t]+-[ \t]+"/, "", line)
      n = length(line); out = ""
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (c == "\\" && i < n) { out = out substr(line, ++i, 1); continue }
        if (c == "\"") break
        out = out c
      }
      return out
    }
    on && $0 ~ /^[ \t]+-[ \t]+"/ { print item($0); next }
    on { exit }
    $0 ~ "^" k "[ \t]*:" { on = 1 }
  ' "$OVERRIDE_FILE"
}

# record_agreed <linter> <rule> — the agreed value of that rule, "" when the
# rule is not agreed. An item is "<linter> <rule> = <value> | <reason>": the
# rule runs to the first " = " and may hold a space; a reason may hold " | ",
# so the value ends at the first one.
record_agreed() {
  record_items agreed | LINTER="$1" RULE="$2" awk '
    {
      p = index($0, " = ")
      if (p == 0 || substr($0, 1, p - 1) != ENVIRON["LINTER"] " " ENVIRON["RULE"]) next
      v = substr($0, p + 3)
      q = index(v, " | ")
      print q ? substr(v, 1, q - 1) : v
      exit
    }'
}

# agreed_state <state> — exit 0 when a row in that state can turn agreed
agreed_state() {
  case "$1" in
    runs|missing|"limit looser"|"limit stricter"|"options differ"|named) return 0 ;;
  esac
  return 1
}

# agreed_by_value <state> <current> <value> — exit 0 when a row of a linter
# that reports settings is agreed: the value is org or equals current, or the
# rule is missing and agreed off
agreed_by_value() {
  [[ "$3" == org || "$2" == "$3" ]] && return 0
  [[ "$1" == missing && "$3" == off ]]
}

# agreed_by_name <state> <value> — exit 0 when a row of a linter that reports
# no setting is agreed: the value is org, or the rule is missing and agreed off,
# or the rule runs and is agreed at any value but off
agreed_by_name() {
  [[ "$2" == org ]] && return 0
  if [[ "$1" == missing ]]; then [[ "$2" == off ]]; else [[ "$2" != off ]]; fi
}

# agreed_row <linter> <rule> <state> <recommended> <current> — prints the
# row's state and current, as the record changes them, joined by a tab
agreed_row() {
  local v=""
  [[ -f "$OVERRIDE_FILE" ]] && v=$(record_agreed "$1" "$2")
  if [[ -z "$v" ]] || ! agreed_state "$3"; then printf '%s\t%s\n' "$3" "$5"; return 0; fi
  if lint_reports_settings "$1"; then
    agreed_by_value "$3" "$5" "$v" && { printf 'agreed\t%s\n' "$5"; return 0; }
  else
    agreed_by_name "$3" "$v" && { printf 'agreed\t%s\n' "$5"; return 0; }
  fi
  printf '%s\t%s; agreed: %s\n' "$3" "$5" "$v"
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
LINT_TMP=$(mktemp -d)
trap 'rm -rf "$SCOPE" "$INVENTORY" "$LINT_TMP"' EXIT
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

# ---------- doctor ----------
DOCTOR_DONE=""
row() { # <id> <linter> <rule> <state> <recommended> <current> <source>
  if (( TSV )); then printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"
  else printf '%s %s %s: %s; recommended: %s; current: %s; source: %s\n' "$@"; fi
}

# sample_file <id> — the source file a linter resolves its config for, the
# first that fits best: a measured file in a subdirectory that is not a
# tool's own config (*.config.*), outside hidden directories (a linter may
# skip those); else a measured file outside hidden directories; else a
# measured file; else any file of the language
sample_file() {
  local f first="" measured_one="" plain=""
  while IFS= read -r f; do
    [[ -z "$first" ]] && first="$f"
    measured "$f" || continue
    [[ -z "$measured_one" ]] && measured_one="$f"
    [[ "/$f" == */.* ]] && continue
    [[ -z "$plain" ]] && plain="$f"
    [[ "$f" == */* && "${f##*/}" != *.config.* ]] && { printf '%s' "$f"; return 0; }
  done < <(awk -F'\t' -v id="$1" '$1 == id { print $2 }' "$SCOPE")
  printf '%s' "${plain:-${measured_one:-$first}}"
}

run_doctor() { # <id> — exit 0 when the language has a recommended config
  local id="$1" linter kind a b c d e f
  linter=$(lint_doctor_linter "$id")
  if [[ -z "$linter" ]]; then
    say "doctor: $id — the plugin recommends no linter config for this language"
    return 1
  fi
  case " $DOCTOR_DONE " in *" $linter "*) return 0 ;; esac
  # one linter serves both: a TypeScript repository is reported as typescript
  [[ "$id" == javascript ]] && printf '%s\n' "$ids" | grep -qx typescript && return 0
  DOCTOR_DONE="$DOCTOR_DONE $linter"
  while IFS=$'\t' read -r kind a b c d e f; do
    case "$kind" in
      note) say "doctor: $id — $a" ;;
      row)  IFS=$'\t' read -r c e < <(agreed_row "$a" "$b" "$c" "$d" "$e")
            row "$id" "$a" "$b" "$c" "$d" "$e" "$f" ;;
    esac
  done < <(lint_doctor "$id" "$SETUP_DIR" "$(sample_file "$id")")
}

# ---------- run ----------
ids=$(cut -f1 "$SCOPE" | LC_ALL=C sort -u)
if [[ -z "$ids" ]]; then
  say "$SCRIPT_NAME: no source file in scope"
  [[ "$SUBCOMMAND" == doctor ]] && exit 2
  exit 0
fi
[[ "$SUBCOMMAND" != doctor || -d "$SETUP_DIR" ]] || die "no recommended configs at $SETUP_DIR"
checked=0
for id in $ids; do
  lang_configure "$id" || continue
  case "$SUBCOMMAND" in
    file-length)  run_file_length "$id" ;;
    package-size) run_package_size "$id" ;;
    doctor)       run_doctor "$id" && checked=1 ;;
  esac
done
if [[ "$SUBCOMMAND" == doctor ]] && (( ! checked )); then
  say "doctor: no language in scope has a recommended linter config"
  exit 2
fi
exit 0
