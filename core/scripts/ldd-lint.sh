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
#   agree                  prints agreement-record lines for .ldd-lint.yaml,
#                          ready to copy unchanged (below)
#   --brief                doctor: the status nudge, one line per project, or
#                          nothing (below)
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
#   --linter <name>        agree: the linter of the rule. With --config (doctor
#                          and agree): the linter that file is for, needed when
#                          the run reports two or more linters
#   --rule <name>          agree: the rule, as the doctor names it
#   --decision <d>         agree: current (keep the repository's setting), off
#                          or org (the organization owns the value)
#   --reason <text>        agree: why the team agreed
#   --fingerprint          agree: one line per config file the doctor compared,
#                          for each linter that reports no setting
#   --config <file>        doctor and agree: compare this config file in place of
#                          the repository's own, for one linter: the one that
#                          --linter names, else the one linter of the run (the
#                          path is relative to --root); it overrides the
#                          lint_config item of that linter
#   --lint-config <linter> <path>  agree: the line that names a config file
#                          for that linter
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
#      the repository's owners: a run of this script never edits a config
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
# language says which config was compared, and which linter binary ran. The
# doctor runs a linter from PATH only, except a linter that a project installs
# in its node_modules: that check runs the project's own copy, which loads the
# project's config file.
#
# The agreement record is the file .ldd-lint.yaml, which the lint-setup skill
# writes. Its key "agreed" lists one item per rule the team agreed to keep. An
# item is one double-quoted YAML scalar: "<linter> <rule> = <value> | <reason>".
# A backslash and a quote in it are escaped. The value is the setting as the
# doctor shows it in current, or "off", or "org" (the organization owns it). The
# keys "lint_config" and "lint_fingerprint" hold the config files the agreement
# was made against:
#   lint_config       "<linter> <path>": the doctor compares that file for that
#                     linter, in place of the repository's own config, and the
#                     linter's own config check reads it too. --config overrides
#                     it. The doctor ignores an item of a linter the run does not
#                     report. An item whose path is not a file gives that linter
#                     one row, "cannot verify: the agreed config <path> does not
#                     exist".
#   lint_fingerprint  "<linter> <path> <hash>", for a linter that reports no
#                     setting: when the hash of the file is not the one in the
#                     item, or the file is gone, the doctor prints
#                     "doctor: <path> changed since the setup was agreed" on
#                     stderr, once per file. It ignores an item of a linter the
#                     run does not report, and an item of a linter that reports
#                     its settings: the rows of that linter show a changed value.
# A path in a record line is relative to the project root, also for a file
# above it ("../"), so the line reads the same in every clone.
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
# The doctor warns on stderr about an item of "agreed" whose linter the run
# reports with rows and whose rule has no row; it ignores that item. It does not
# warn about an item of a linter the run does not report, or of a linter that
# cannot verify. The warning does not change the exit code.
#
# agree prints, on stdout, one record line for the skill to copy into
# .ldd-lint.yaml unchanged. Each line is one escaped item:
#   agree --linter <l> --rule <r> --decision <d> --reason <text>
#       "<l> <r> = <value> | <reason>", where the value is the doctor's current
#       setting of that rule (current), off or org; every " | " in the reason
#       becomes " / ". It reads the doctor's rows, so the rule must have one.
#       A rule in the state missing has no setting: only off is accepted.
#   agree --fingerprint
#       "<linter> <path> <hash>" for each config file the doctor compared, of
#       each linter that reports no setting; a linter that reports its settings
#       gets no line. The hash is git hash-object of the file, else the first
#       field of cksum. When another file was chosen (--config or lint_config),
#       the repository's own config of that linter gets a line too, after the
#       chosen file's. A linter that reports no setting and has no config file
#       compared gets a note on stderr and no line
#   agree --lint-config <linter> <path>
#       "<linter> <path>"; the path must be a file
# A linter that cannot verify gives no row and no config: agree with the rule
# options exits 2 when that linter cannot verify, and agree --fingerprint exits 2
# when any linter in scope cannot verify. Each names the cause.
#
# doctor --brief prints the status nudge. It finds the projects itself: the
# root and each directory with a tracked .ldd-lint.yaml (a find outside git).
# A project gets no line and no linter run when its .ldd-lint.yaml has no
# "agreed" key, or when no item of the record names a linter. For the other
# projects, it runs "doctor --tsv" there and counts the rows of each linter
# that an item of agreed, lint_fingerprint or lint_config names. The other
# linters belong to a plugin whose setup did not run. It prints one line per
# project when the doctor finds a difference:
#   ⚙️ Lint setup (<dir>): 1 rule differs from what the team agreed — run /{{.CmdPrefix}}-setup
#   ⚙️ Lint setup (<dir>): <n> rules differ from what the team agreed — run /{{.CmdPrefix}}-setup
#   ⚙️ Lint setup (<dir>): the linter cannot check this project — run /{{.CmdPrefix}}-setup
# <dir> is "." for the root and "<path>/" for a project below it. Each of these
# is one difference:
#   a row in the state missing or limit looser that is not agreed
#   a row of any state whose agreed value changed: its current ends in
#     "; agreed: <value>"
#   a config file that changed since the setup was agreed
# A row that cannot verify gives the last line in place of a count. The states
# runs, agreed, limit stricter, options differ and named are no difference. A
# project whose doctor exits 2 or 3, or fails, gets no line. Only the lines
# print. --brief takes no --config and no --files, and always exits 0.
#
# The generic plugin's doctor leaves a language to the plugin written for it
# when that plugin is installed: it prints
#   doctor: <language> — <plugin> is installed and checks this language; run /<prefix>-setup
# and gives that language no row, no config and no agree line. The other plugins
# check their own language and never skip one this way.
#
# Exit codes:
#   0  measured, with or without findings; doctor --brief always
#   2  a usage error; a --files list that does not exist; a --config that is
#      not a file, or that meets a run with two or more linters and no
#      --linter; a --linter that names no linter of the run; a .ldd-lint.yaml
#      value that is not a positive integer; a doctor run with no language the
#      plugin recommends a config for (inconclusive, never silently clean); an
#      agree line the script cannot write: no doctor row for the rule, a
#      linter that cannot verify, a path that is not a file
#   3  a doctor run where the generic plugin left every language in scope to an
#      installed plugin written for it (nothing to research)
#
# Uses only POSIX-portable tools plus git when the root is a repository:
# grep, sed, awk, sort, find, head.

set -u

SCRIPT_NAME="ldd-lint"
PLUGIN_NAME="{{.Plugin}}"
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
AGREE_LINTER=""
AGREE_RULE=""
AGREE_DECISION=""
AGREE_REASON=""
AGREE_FINGERPRINT=0
AGREE_CONFIG_LINTER=""
AGREE_CONFIG_PATH=""
AGREE_SET=""
LINTER_SET=0
OPT_CONFIG=""
CONFIG_LINTER=""
BRIEF=0

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

# value <option> <remaining argument count> — a value-taking option needs one
value() { (( $2 >= 2 )) || die "$1 needs a value"; }

while (( $# > 0 )); do
  case "$1" in
    file-length|package-size|doctor|agree) [[ -n "$SUBCOMMAND" ]] && die "one subcommand, got also: $1"; SUBCOMMAND="$1"; shift ;;
    --root)    value "$1" $#; ROOT="$2"; shift 2 ;;
    --files)   value "$1" $#; FILES_LIST="$2"; shift 2 ;;
    --tsv)     TSV=1; shift ;;
    --linter)   value "$1" $#; AGREE_LINTER="$2"; LINTER_SET=1; shift 2 ;;
    --rule)     value "$1" $#; AGREE_RULE="$2"; AGREE_SET="$AGREE_SET $1"; shift 2 ;;
    --decision) value "$1" $#; AGREE_DECISION="$2"; AGREE_SET="$AGREE_SET $1"; shift 2 ;;
    --reason)   value "$1" $#; AGREE_REASON="$2"; AGREE_SET="$AGREE_SET $1"; shift 2 ;;
    --fingerprint) AGREE_FINGERPRINT=1; AGREE_SET="$AGREE_SET $1"; shift ;;
    --lint-config) (( $# >= 3 )) || die "$1 needs a linter and a path"
                   AGREE_CONFIG_LINTER="$2"; AGREE_CONFIG_PATH="$3"; AGREE_SET="$AGREE_SET $1"; shift 3 ;;
    --config)  value "$1" $#; OPT_CONFIG="$2"; shift 2 ;;
    --brief)   BRIEF=1; shift ;;
    --glob)    value "$1" $#; OPT_GLOB="$2"; shift 2 ;;
    --test-re) value "$1" $#; OPT_TEST_RE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)         die "unknown argument: $1 (see --help)" ;;
  esac
done
[[ -n "$SUBCOMMAND" ]] || die "name a subcommand: file-length, package-size, doctor or agree (see --help)"
[[ -z "$AGREE_SET" || "$SUBCOMMAND" == agree ]] || die "only agree takes:$AGREE_SET"
[[ -z "$OPT_CONFIG" || "$SUBCOMMAND" == doctor || "$SUBCOMMAND" == agree ]] || die "only doctor and agree take --config"
(( ! LINTER_SET )) || [[ "$SUBCOMMAND" == agree || ( "$SUBCOMMAND" == doctor && -n "$OPT_CONFIG" ) ]] \
  || die "only agree, and doctor with --config, take --linter"
(( ! BRIEF )) || [[ "$SUBCOMMAND" == doctor ]] || die "only doctor takes --brief"
(( ! BRIEF )) || [[ -z "$OPT_CONFIG$FILES_LIST" ]] || die "--brief takes no --config or --files"
[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
if [[ -n "$FILES_LIST" ]]; then
  [[ -f "$FILES_LIST" ]] || die "no such file list: $FILES_LIST"
  [[ "$FILES_LIST" == /* ]] || FILES_LIST="$(pwd)/$FILES_LIST"
fi
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/setup"
cd "$ROOT" || exit 2
[[ -z "$OPT_CONFIG" || -f "$OPT_CONFIG" ]] || die "--config: not a file: $OPT_CONFIG"

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
# structure from it. An item is one double-quoted scalar on a line "- ".

# record_has <key> — exit 0 when the record has the key, with items or as "[]"
record_has() {
  [[ -f "$OVERRIDE_FILE" ]] && grep -qE -- "^$1[[:space:]]*:" "$OVERRIDE_FILE"
}

# record_items <key> — each item of the key's list, unquoted and unescaped,
# one per line; nothing when the key or the file is absent. An item line is
# "- " with or without an indent. The list ends at the first line that is not
# an item. A "#" inside the quotes is data.
record_items() {
  [[ -f "$OVERRIDE_FILE" ]] || return 0
  awk -v k="$1" '
    function item(line,   out, i, c, n) {
      sub(/^[ \t]*-[ \t]+"/, "", line)
      n = length(line); out = ""
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (c == "\\" && i < n) { out = out substr(line, ++i, 1); continue }
        if (c == "\"") break
        out = out c
      }
      return out
    }
    on && $0 ~ /^[ \t]*-[ \t]+"/ { print item($0); next }
    on { exit }
    $0 ~ "^" k "[ \t]*:" { on = 1 }
  ' "$OVERRIDE_FILE"
}

# record_linters — the linters the items of agreed, lint_fingerprint and
# lint_config name, one per line
record_linters() {
  { record_items agreed; record_items lint_fingerprint; record_items lint_config; } \
    | awk 'NF { print $1 }' | LC_ALL=C sort -u
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

# record_line <text> — prints the text as one record item: a double-quoted
# scalar on a line "  - ", with a backslash and a quote escaped
record_line() {
  local t="$1"
  t=${t//\\/\\\\}; t=${t//\"/\\\"}
  printf '  - "%s"\n' "$t"
}

# ---------- doctor --brief ----------
# brief_projects — the projects of the run, one directory per line: the root,
# then each directory with a tracked record file
brief_projects() {
  printf '.\n'
  { if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -c core.quotepath=off ls-files -- "*/$OVERRIDE_FILE"
    else
      find . -mindepth 2 -type f -name "$OVERRIDE_FILE" -not -path './.git/*' -not -path '*/node_modules/*' 2>/dev/null | sed 's|^\./||'
    fi
  } | sed 's|/[^/]*$||' | LC_ALL=C sort -u
}

# brief_line <dir> — the nudge line of one project; nothing when the project
# has no record, when no item of the record names a linter, when its doctor
# does not exit 0, or when nothing differs. Only the rows of a linter that an
# item names count: the other linters belong to a plugin whose setup did not
# run. The changed-config count reads the doctor's own stderr line, so the text
# of that line and the pattern below stay equal.
brief_line() {
  local d="$1" out code differ cannot changed label what named err="$LINT_TMP/brief-err"
  (cd "$d" 2>/dev/null && record_has agreed) || return 0
  named=$(cd "$d" && record_linters | tr '\n' ' ')
  [[ -n "$named" ]] || return 0
  out=$("$BASH" "$SELF" doctor --tsv --root "./$d" 2>"$err"); code=$?
  (( code == 0 )) || return 0
  read -r differ cannot < <(printf '%s\n' "$out" | NAMED="$named" awk -F'\t' '
    BEGIN { n = split(ENVIRON["NAMED"], a, " "); for (i = 1; i <= n; i++) named[a[i]] = 1; n = 0 }
    !($2 in named) { next }
    $4 == "missing" || $4 == "limit looser" || $6 ~ /; agreed: / { n++ }
    $4 ~ /^cannot verify/ { c++ }
    END { print n + 0, c + 0 }')
  changed=$(grep -c '^doctor: .* changed since the setup was agreed$' "$err")
  differ=$(( differ + changed ))
  label="$d"; [[ "$d" == . ]] || label="$d/"
  if (( cannot > 0 )); then
    what="the linter cannot check this project"
  elif (( differ == 1 )); then
    what="1 rule differs from what the team agreed"
  elif (( differ > 1 )); then
    what="$differ rules differ from what the team agreed"
  else
    return 0
  fi
  printf '⚙️ Lint setup (%s): %s — run /{{.CmdPrefix}}-setup\n' "$label" "$what"
}

run_brief() {
  local d
  while IFS= read -r d; do brief_line "$d"; done < <(brief_projects)
  exit 0
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
(( ! BRIEF )) || run_brief
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
# root_relative <path> — the path from the working directory, which is the
# project root: an absolute path gets "../" steps when it is above the root; a
# relative path stays as it is, without a leading "./". A record that holds the
# path then reads the same in every clone.
root_relative() {
  local p="$1" dir base root up=""
  [[ "$p" == /* ]] || { printf '%s' "${p#./}"; return 0; }
  base=${p##*/}
  dir=$(cd -P "${p%/*}/" 2>/dev/null && pwd -P) || { printf '%s' "$p"; return 0; }
  root=$(pwd -P)
  while [[ "$dir" != "$root" && "$dir" != "$root"/* && "$root" != / ]]; do
    root=$(dirname "$root"); up="../$up"
  done
  if [[ "$dir" == "$root" ]]; then printf '%s%s' "$up" "$base"
  elif [[ "$root" == / ]]; then printf '%s%s/%s' "$up" "${dir#/}" "$base"
  else printf '%s%s/%s' "$up" "${dir#"$root"/}" "$base"; fi
}

DOCTOR_DONE=""
# The run keeps what agree and the unmatched-line warning read: one line per
# row, "linter TAB rule TAB state TAB current" with the current setting as the
# linter reports it, before the record changes it; and one line per config
# file the doctor compared, "linter TAB path".
DOCTOR_ROWS="$LINT_TMP/rows"
DOCTOR_CONFIGS="$LINT_TMP/configs"
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

# config_for <linter> — the config file the doctor compares for that linter:
# --config when it applies to that linter, else the linter's item of
# lint_config; nothing when there is none
config_for() {
  if [[ -n "$OPT_CONFIG" && ( -z "$CONFIG_LINTER" || "$1" == "$CONFIG_LINTER" ) ]]; then
    printf '%s' "$OPT_CONFIG"; return 0
  fi
  record_items lint_config | L="$1" awk '
    { p = index($0, " ")
      if (p == 0 || substr($0, 1, p - 1) != ENVIRON["L"]) next
      print substr($0, p + 1); exit }'
}

# left_to_plugin <id> — exit 0 when this is the generic plugin and the plugin
# written for the language is installed: that plugin checks the language
left_to_plugin() {
  [[ "$PLUGIN_NAME" == "$GENERIC_PLUGIN" ]] || return 1
  local d; d=$(dedicated_plugin_for "$1")
  [[ -n "$d" && -n "$(installed_plugin_dir "$d")" ]]
}

# run_doctor <id> — exit 0 when the language has a recommended config, 1 when
# it has none, 3 when an installed plugin checks the language instead
run_doctor() {
  local id="$1" linter kind a b c d e f other
  if left_to_plugin "$id"; then
    other=$(dedicated_plugin_for "$id")
    say "doctor: $id — $other is installed and checks this language; run /$(plugin_cmd_prefix "$other")-setup"
    return 3
  fi
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
      row)  printf '%s\t%s\t%s\t%s\n' "$a" "$b" "$c" "$e" >> "$DOCTOR_ROWS"
            IFS=$'\t' read -r c e < <(agreed_row "$a" "$b" "$c" "$d" "$e")
            row "$id" "$a" "$b" "$c" "$d" "$e" "$f" ;;
      config) printf '%s\t%s\n' "$a" "$(root_relative "$b")" >> "$DOCTOR_CONFIGS" ;;
    esac
  done < <(lint_doctor "$id" "$SETUP_DIR" "$(sample_file "$id")" "$(config_for "$linter")")
}

# warn_unmatched — a line on stderr for each item of "agreed" that names a
# linter this run reported and a rule it has no row for. An item of another
# linter belongs to another plugin's run, and a linter that cannot verify has
# no rows to match, so neither is named.
warn_unmatched() {
  [[ -s "$DOCTOR_ROWS" ]] || return 0
  local item head l r
  while IFS= read -r item; do
    [[ "$item" == *" = "* ]] || continue
    head=${item%% = *}
    [[ "$head" == *" "* ]] || continue
    l=${head%% *}; r=${head#* }
    [[ -n "$(L="$l" R="$r" awk -F'\t' '
      $1 == ENVIRON["L"] { seen = 1 }
      $1 == ENVIRON["L"] && $3 ~ /^cannot verify/ { cannot = 1 }
      $1 == ENVIRON["L"] && $2 == ENVIRON["R"] { matched = 1 }
      END { if (seen && !cannot && !matched) print "warn" }' "$DOCTOR_ROWS")" ]] \
      && echo "doctor: $OVERRIDE_FILE: no row for $l $r; the line is ignored" >&2
  done < <(record_items agreed)
  return 0
}

# report_changed — a line on stderr for each config file whose hash is not the
# one of its item of "lint_fingerprint", or that is gone. An item is
# "<linter> <path> <hash>": the path may hold a space, the hash is the last
# word. An item of a linter this run did not report belongs to another plugin's
# run, so it is not checked. An item of a linter that reports its settings is
# not checked either: its rows show a changed value, and a change elsewhere in
# the file (a dependency in a package manifest) is no drift.
report_changed() {
  [[ -s "$DOCTOR_ROWS" ]] || return 0
  local item rest linter path want
  while IFS= read -r item; do
    [[ "$item" == *" "*" "* ]] || continue
    linter=${item%% *}; rest=${item#* }
    want=${rest##* }; path=${rest% *}
    L="$linter" awk -F'\t' '$1 == ENVIRON["L"] { f = 1 } END { exit !f }' "$DOCTOR_ROWS" || continue
    lint_reports_settings "$linter" && continue
    if [[ ! -f "$path" || "$(file_hash "$path")" != "$want" ]]; then
      echo "doctor: $path changed since the setup was agreed" >&2
    fi
  done < <(record_items lint_fingerprint)
  return 0
}

# ---------- agree ----------
# file_hash <path> — git hash-object of the file, else the first field of cksum
file_hash() {
  git hash-object -- "$1" 2>/dev/null || cksum < "$1" | cut -d' ' -f1
}

# fingerprint_line <linter> <path> — the record line for one config file
fingerprint_line() {
  record_line "$1 $2 $(file_hash "$2")"
}

# agree_cannot [<linter>] — dies with the cause when the doctor could not
# verify that linter, or any linter
agree_cannot() {
  local why
  why=$(L="${1:-}" awk -F'\t' '$3 ~ /^cannot verify/ && (ENVIRON["L"] == "" || $1 == ENVIRON["L"]) { print $1 " " $3; exit }' "$DOCTOR_ROWS")
  [[ -z "$why" ]] || die "agree: $why"
}

run_agree_rule() {
  local reason="$AGREE_REASON" value state sel
  [[ -n "$AGREE_LINTER" ]] || die "agree needs --linter"
  [[ -n "$AGREE_RULE" ]] || die "agree needs --rule"
  [[ -n "$AGREE_REASON" ]] || die "agree needs --reason, and it is empty"
  case "$AGREE_DECISION" in
    current|off|org) ;;
    *) die "agree needs --decision current, off or org, got: ${AGREE_DECISION:-nothing}" ;;
  esac
  agree_cannot "$AGREE_LINTER"
  sel=$(L="$AGREE_LINTER" R="$AGREE_RULE" awk -F'\t' '
    $1 == ENVIRON["L"] && $2 == ENVIRON["R"] { print $3 "\t" $4; found = 1; exit }
    END { exit !found }' "$DOCTOR_ROWS") || die "agree: no doctor row for $AGREE_LINTER $AGREE_RULE"
  state=${sel%%$'\t'*}; value=${sel#*$'\t'}
  [[ "$AGREE_DECISION" == current && "$state" == missing ]] \
    && die "agree: $AGREE_LINTER $AGREE_RULE does not run, so it has no setting to keep; use --decision off"
  [[ "$AGREE_DECISION" == current ]] || value="$AGREE_DECISION"
  reason=${reason//$'\n'/ }; reason=${reason//$'\r'/ }; reason=${reason//$'\t'/ }
  while [[ "$reason" == *" | "* ]]; do reason=${reason/ | / / }; done
  record_line "$AGREE_LINTER $AGREE_RULE = $value | $reason"
}

# run_agree_fingerprint — the lines of the linters that report no setting; a
# linter that reports its settings shows a changed value in its rows
run_agree_fingerprint() {
  local linter path
  agree_cannot
  [[ ! -s "$DOCTOR_CONFIGS" ]] || while IFS=$'\t' read -r linter path; do
    lint_reports_settings "$linter" || fingerprint_line "$linter" "$path"
  done < "$DOCTOR_CONFIGS"
  # a linter the run reports, with no config file compared: no line, and a note
  while IFS= read -r linter; do
    lint_reports_settings "$linter" && continue
    L="$linter" awk -F'\t' '$1 == ENVIRON["L"] { f = 1 } END { exit !f }' "$DOCTOR_CONFIGS" 2>/dev/null \
      || echo "agree: no config file of $linter was compared, so there is no fingerprint line for it" >&2
  done < <(cut -f1 "$DOCTOR_ROWS" | LC_ALL=C sort -u)
  return 0
}

# ---------- run ----------
if [[ "$SUBCOMMAND" == agree ]]; then
  # with --config, --linter names the linter of that file, so alone it is no
  # rule option
  modes=$AGREE_FINGERPRINT
  [[ -n "$AGREE_CONFIG_LINTER" ]] && modes=$(( modes + 1 ))
  rule_opts=0
  (( LINTER_SET )) && [[ -z "$OPT_CONFIG" ]] && rule_opts=1
  for o in --rule --decision --reason; do
    case " $AGREE_SET " in *" $o "*) rule_opts=1 ;; esac
  done
  modes=$(( modes + rule_opts ))
  (( modes <= 1 )) || die "agree takes one of --fingerprint, --lint-config or the rule options"
  [[ -z "$AGREE_CONFIG_LINTER" ]] || (( ! LINTER_SET )) || die "agree --lint-config takes no --linter"
  if [[ -n "$AGREE_CONFIG_LINTER" ]]; then
    [[ -f "$AGREE_CONFIG_PATH" ]] || die "agree --lint-config: not a file: $AGREE_CONFIG_PATH"
    record_line "$AGREE_CONFIG_LINTER $(root_relative "$AGREE_CONFIG_PATH")"
    exit 0
  fi
fi
ids=$(cut -f1 "$SCOPE" | LC_ALL=C sort -u)
if [[ -z "$ids" ]]; then
  say "$SCRIPT_NAME: no source file in scope"
  [[ "$SUBCOMMAND" == doctor || "$SUBCOMMAND" == agree ]] && exit 2
  exit 0
fi
[[ "$SUBCOMMAND" != doctor && "$SUBCOMMAND" != agree || -d "$SETUP_DIR" ]] || die "no recommended configs at $SETUP_DIR"
# linter_names — the distinct linters this run reports, one per line; a
# language left to another installed plugin has none
linter_names() {
  local id
  for id in $ids; do
    left_to_plugin "$id" && continue
    lint_doctor_linter "$id"; printf '\n'
  done | awk 'NF && !seen[$0]++'
}
# CONFIG_LINTER — the linter --config applies to: the one of --linter, else the
# one linter of the run
if [[ -n "$OPT_CONFIG" ]]; then
  names=$(linter_names | tr '\n' ' '); names=${names% }
  if (( LINTER_SET )); then
    case " $names " in
      *" $AGREE_LINTER "*) CONFIG_LINTER=$AGREE_LINTER ;;
      *) die "--linter $AGREE_LINTER: this run reports no such linter; it reports: ${names:-no linter}" ;;
    esac
  elif [[ "$names" == *" "* ]]; then
    die "--config needs --linter <name> in a run with two or more linters; this run reports: $names"
  else
    CONFIG_LINTER=$names
  fi
fi
checked=0 left=0 no_config=0
# tally_doctor <status of run_doctor> — counts the language by what the doctor did
tally_doctor() {
  case "$1" in
    0) checked=1 ;;
    3) left=1 ;;
    *) no_config=1 ;;
  esac
}
for id in $ids; do
  lang_configure "$id" || continue
  case "$SUBCOMMAND" in
    file-length)  run_file_length "$id" ;;
    package-size) run_package_size "$id" ;;
    doctor)       run_doctor "$id"; tally_doctor $? ;;
    agree)        run_doctor "$id" > /dev/null 2>&1; tally_doctor $? ;;
  esac
done
if [[ "$SUBCOMMAND" == doctor ]] && (( ! checked )); then
  (( left && ! no_config )) && exit 3
  say "doctor: no language in scope has a recommended linter config"
  exit 2
fi
if [[ "$SUBCOMMAND" == agree ]]; then
  if (( ! checked )); then
    (( left && ! no_config )) && die "agree: every language in scope belongs to an installed plugin; run its setup command"
    die "agree: no language in scope has a recommended linter config"
  fi
  if (( AGREE_FINGERPRINT )); then run_agree_fingerprint; else run_agree_rule; fi
  exit 0
fi
if [[ "$SUBCOMMAND" == doctor ]]; then warn_unmatched; report_changed; fi
exit 0
