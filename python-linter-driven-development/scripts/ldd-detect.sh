#!/usr/bin/env bash
# Detection pass of the pre-commit review for the python-linter-driven-development plugin.
#
# Runs every falsifying question's detect line over the review's scope and
# writes three tables into the scope bundle: hits.tsv (one row per hit, capped
# per question with the overflow counted), hits-all.tsv (the same rows uncapped,
# for a capped question's reader) and counts.tsv (one row per question). The
# counts table and the per-family totals are printed; hunters read the hits
# table rows of their family. What each question asks stays in the rules — the
# detect line is the lead generator, never the judgment.
#
# Usage:  bash scripts/ldd-detect.sh [options] <bundle-dir>
#         <bundle-dir>      the bundle ldd-scope.sh wrote; its files.txt is the
#                           scope, hits.tsv and counts.tsv are written beside it
#   --files <list>          read the scope from this file instead of files.txt
#   --root <dir>            the reviewed repository (default: cwd); scope paths
#                           are relative to it
#   --rules <dir>           the rule files (default: ../rules beside this script)
#   --cap <n>               hits kept per question in hits.tsv (default 40)
#   --plan                  print the parsed detect lines and exit; nothing runs
#   --glob <pattern>        source-file glob, when the language block cannot
#                           tell it from the repository (Python block below)
#   --test-re <ERE>         test-file pattern over relative paths, same case
#
# Detect lines — one per numbered question under "## Falsifying questions":
#   Detect-grep: `<ERE>` [files=src|test|all] [exclude-path=<ERE>,<ERE>] [context=<n>]
#                grep -nHE over the scope files (default: the non-test ones);
#                exclude-path drops paths matching any listed ERE; context
#                appends the next n lines to each hit's excerpt
#   Detect-path: `<ERE>`   over the scope's relative paths (layer directories,
#                role-named packages); a hit's line is 0
#   Detect-gate: Q<n>      the R9 gate's [Q<n>] report lines, from one run of
#                check-repo-brain.sh beside this script over --root; on a
#                scoped bundle (no dirs.txt) only the lines whose file is in
#                the scope — the gate's repository-wide findings belong to
#                a whole-repository review
#   Detect: judgment       no mechanical lead; the hunter runs the prose
# A question with no detect line, two of them, or a malformed one is an error:
# the generator's lint-core keeps the rule files honest, and this script refuses
# to run a table it cannot fill.
#
# Tables (tab-separated, no header):
#   hits.tsv    rule  question  kind  file  line  excerpt
#               the overflow row of a capped question: file "-", line 0,
#               excerpt "+<n> more hit(s) not listed"
#   hits-all.tsv  the same columns, every hit, no cap and no overflow row
#   counts.tsv  rule  question  kind  hits      (judgment rows carry "-")
#               the last row is SUPPRESS  -  grep  <n>: suppression directives
#               on the diff's added lines when the bundle has a diff.patch,
#               else over every scope file
# Two runs over one tree write byte-identical counts.tsv.
#
# Exit codes: 0 tables written · 2 usage error, a detect line that does not
#             parse, a pattern grep rejects, or a gate run that failed
#             (inconclusive, never silently clean)
#
# Uses only POSIX-portable tools: grep, sed, awk, sort, wc, head. GNU grep's
# \b and \s are assumed, as the rules already assume them.

set -u

SCRIPT_NAME="ldd-detect"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RULES_DIR="$SCRIPT_DIR/../rules"
ROOT="$(pwd)"
FILES_LIST=""
CAP=40
PLAN=0
OPT_GLOB=""
OPT_TEST_RE=""
BUNDLE=""

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

while (( $# > 0 )); do
  case "$1" in
    --files)   FILES_LIST="${2:-}"; shift 2 ;;
    --root)    ROOT="${2:-}"; shift 2 ;;
    --rules)   RULES_DIR="${2:-}"; shift 2 ;;
    --cap)     CAP="${2:-}"; shift 2 ;;
    --plan)    PLAN=1; shift ;;
    --glob)    OPT_GLOB="${2:-}"; shift 2 ;;
    --test-re) OPT_TEST_RE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    --*)       die "unknown option: $1" ;;
    *)         [[ -n "$BUNDLE" ]] && die "one bundle directory, got also: $1"; BUNDLE="$1"; shift ;;
  esac
done
[[ "$CAP" =~ ^[0-9]+$ ]] || die "--cap takes a number, got: $CAP"
[[ -d "$RULES_DIR" ]] || die "no rules directory: $RULES_DIR"
RULES_DIR=$(cd "$RULES_DIR" && pwd)
if (( ! PLAN )); then
  [[ -n "$BUNDLE" ]] || die "pass the bundle directory (see --help)"
  [[ -d "$BUNDLE" ]] || die "not a directory: $BUNDLE"
  BUNDLE=$(cd "$BUNDLE" && pwd)
  [[ -z "$FILES_LIST" ]] && FILES_LIST="$BUNDLE/files.txt"
  [[ -f "$FILES_LIST" ]] || die "no scope list: $FILES_LIST"
  FILES_LIST=$(cd "$(dirname "$FILES_LIST")" && pwd)/$(basename "$FILES_LIST")
  [[ -d "$ROOT" ]] || die "not a directory: $ROOT"
  cd "$ROOT" || exit 2
fi

# ===================== language block: python =====================
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
#   LANG_LINT_CONFIG_RE ERE over a relative path: a linter's configuration file,
#                       which no refactoring slice may touch (every language's
#                       forms, since a repository may carry several)
LANG_SRC_GLOB='*.py'
LANG_EXCLUDE_RE='(^|/)(\.venv|venv|\.git|node_modules|__pycache__|\.tox|build|dist)/'
LANG_SUPPRESS_RE='#\s*(noqa|type:\s*ignore|ty:\s*ignore)'
LANG_COMMENT_RE='(#|""")'
LANG_DIRECTIVE_RE='#\s*(noqa|type:|ty:|pragma|fmt:|pylint:|ruff:|isort:|!)|>>>'
LANG_GENERATED_RE='Generated by|DO NOT EDIT|@generated|automatically generated'

LANG_LINT_CONFIG_RE='(^|/)(\.golangci\.ya?ml|pyproject\.toml|setup\.cfg|ruff\.toml|\.flake8)$'

lang_configure() {
  [[ -n "${OPT_GLOB:-}" ]] && LANG_SRC_GLOB="$OPT_GLOB"
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  case "$1" in
    *_test.py|test_*.py|*/test_*.py|conftest.py|*/conftest.py|tests/*|*/tests/*) return 0 ;;
  esac
  return 1
}
# =================== end language block: python ===================

# --plan parses the rules and never touches the tree, so the language block is
# configured only for a run.
(( PLAN )) || lang_configure || exit 2

# ---------- the plan: every detect line, parsed ----------
# One row per question: rule TAB question TAB kind TAB pattern TAB flags.
# A parse problem prints "ERR TAB <rule> TAB <question> TAB <message>".
PLAN_AWK='
function flush() {
  if (q == 0) return
  if (ndetect == 0) print "ERR\t" rule "\t" q "\tno detect line"
  else if (ndetect > 1) print "ERR\t" rule "\t" q "\t" ndetect " detect lines (exactly one)"
  else print row
}
FNR == 1 { rule = FILENAME; sub(/^.*\//, "", rule); sub(/-.*$/, "", rule); insec = 0; q = 0; ndetect = 0; row = "" }
/^## / { if (insec) { flush(); q = 0; ndetect = 0 }; insec = ($0 ~ /^## Falsifying questions/); next }
!insec { next }
/^[0-9]+\. \*\*/ { flush(); q = $0; sub(/\..*$/, "", q); q = q + 0; ndetect = 0; row = ""; next }
q > 0 && /^[ \t]*Detect(-[a-z]+)?:/ {
  ndetect++
  line = $0; sub(/^[ \t]*/, "", line)
  kind = line; sub(/:.*$/, "", kind); sub(/^Detect-?/, "", kind)
  rest = line; sub(/^[^:]*:[ \t]*/, "", rest); sub(/[ \t]+$/, "", rest)
  if (kind == "" && rest == "judgment") { row = rule "\t" q "\tjudgment\t\t"; next }
  if (kind == "gate") {
    if (rest ~ /^Q[0-9]+$/) row = rule "\t" q "\tgate\t" rest "\t"
    else print "ERR\t" rule "\t" q "\tDetect-gate takes Q<n>, got: " rest
    next
  }
  if (kind == "grep" || kind == "path") {
    if (rest !~ /^`.*`/) { print "ERR\t" rule "\t" q "\tDetect-" kind " needs a backticked pattern: " rest; next }
    pat = substr(rest, 2)
    n = 0; for (i = length(pat); i >= 1; i--) if (substr(pat, i, 1) == "`") { n = i; break }
    flags = substr(pat, n + 1); sub(/^[ \t]+/, "", flags)
    pat = substr(pat, 1, n - 1)
    if (pat == "") { print "ERR\t" rule "\t" q "\tempty pattern"; next }
    if (kind == "path" && flags != "") { print "ERR\t" rule "\t" q "\tDetect-path takes no flags: " flags; next }
    row = rule "\t" q "\t" kind "\t" pat "\t" flags
    next
  }
  print "ERR\t" rule "\t" q "\tunknown detect kind: " line
}
END { if (insec) flush() }
'

plan_file=$(mktemp)
trap 'rm -f "$plan_file" "${tmp_hits:-}" "${tmp_hits_all:-}" "${tmp_counts:-}" "${gate_out:-}"' EXIT
rule_files=$(find "$RULES_DIR" -maxdepth 1 -name 'R*.md' | awk -F/ '{ n = $NF; sub(/^R/, "", n); sub(/-.*$/, "", n); print n "\t" $0 }' | sort -n | cut -f2)
[[ -n "$rule_files" ]] || die "no rule files (R*.md) under $RULES_DIR"
while IFS= read -r f; do
  awk "$PLAN_AWK" "$f" >> "$plan_file"
done <<< "$rule_files"

if grep -q '^ERR	' "$plan_file"; then
  grep '^ERR	' "$plan_file" | awk -F'\t' '{ printf "  %s Q%s: %s\n", $2, $3, $4 }' >&2
  die "$(grep -c '^ERR	' "$plan_file") detect line(s) do not parse (rules under $RULES_DIR)"
fi
[[ -s "$plan_file" ]] || die "no falsifying questions found under $RULES_DIR"

if (( PLAN )); then
  awk -F'\t' '{ printf "%s\tQ%s\t%s\t%s", $1, $2, $3, $4; if ($5 != "") printf "\t%s", $5; printf "\n" }' "$plan_file"
  exit 0
fi

# ---------- the scope ----------
# files.txt lines are "path" or "path (not bundled: <reason>)"; a not-bundled
# file still exists for grep unless it was deleted. Only the language's source
# files count, excluded directories are dropped, order is fixed for identical
# tables across runs.
SRC_FILES=()
TEST_FILES=()
ALL_FILES=()
while IFS= read -r line; do
  f="${line%% (not bundled:*}"
  f="${f#./}"
  [[ -z "$f" ]] && continue
  [[ -f "$f" ]] || continue
  case "$(basename "$f")" in $LANG_SRC_GLOB) ;; *) continue ;; esac
  printf '%s\n' "$f" | grep -qE -- "$LANG_EXCLUDE_RE" && continue
  ALL_FILES+=("$f")
done < <(LC_ALL=C sort -u "$FILES_LIST")
for f in ${ALL_FILES[@]+"${ALL_FILES[@]}"}; do
  if lang_is_test "$f"; then TEST_FILES+=("$f"); else SRC_FILES+=("$f"); fi
done

tmp_hits=$(mktemp)
tmp_hits_all=$(mktemp)
tmp_counts=$(mktemp)
gate_out=""

# ROWS_AWK turns "file:line:text" grep output into "file TAB line TAB excerpt":
# the excerpt is one line, tabs to spaces, trimmed, cut at 200 characters.
ROWS_AWK='
{
  i = index($0, ":"); f = substr($0, 1, i - 1); rest = substr($0, i + 1)
  j = index(rest, ":"); l = substr(rest, 1, j - 1); t = substr(rest, j + 1)
  gsub(/\t/, " ", t); sub(/^[ ]+/, "", t); sub(/[ ]+$/, "", t)
  print f "\t" l "\t" substr(t, 1, 200)
}
'

# select_files <files=> <exclude-path=> — prints the scope subset, one per line
select_files() {
  local which="$1" excl="$2" f
  local -a list
  case "$which" in
    src|"") list=(${SRC_FILES[@]+"${SRC_FILES[@]}"}) ;;
    test)   list=(${TEST_FILES[@]+"${TEST_FILES[@]}"}) ;;
    all)    list=(${ALL_FILES[@]+"${ALL_FILES[@]}"}) ;;
    *)      return 1 ;;
  esac
  for f in ${list[@]+"${list[@]}"}; do
    if [[ -n "$excl" ]]; then
      printf '%s\n' "$f" | grep -qE -- "$(printf '%s' "$excl" | tr ',' '|')" && continue
    fi
    printf '%s\n' "$f"
  done
}

# parse_flags <flags> — sets FL_FILES FL_EXCLUDE FL_CONTEXT; exit 1 on a bad flag
parse_flags() {
  FL_FILES="src"; FL_EXCLUDE=""; FL_CONTEXT=0
  local fl
  for fl in $1; do
    case "$fl" in
      files=src|files=test|files=all) FL_FILES="${fl#files=}" ;;
      exclude-path=?*) FL_EXCLUDE="${fl#exclude-path=}" ;;
      context=*) FL_CONTEXT="${fl#context=}"; [[ "$FL_CONTEXT" =~ ^[0-9]+$ ]] || return 1 ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# with_context <file> <line> <excerpt> <n> — the excerpt plus the next n lines
with_context() {
  local f="$1" l="$2" ex="$3" n="$4"
  printf '%s' "$ex"
  (( n == 0 )) && return 0
  awk -v s="$l" -v n="$n" 'NR > s && NR <= s + n { gsub(/\t/, " "); sub(/^[ ]+/, ""); sub(/[ ]+$/, ""); if ($0 != "") printf " ⏎ %s", substr($0, 1, 200) }' "$f"
}

# record <rule> <q> <kind> <raw-hits-file> <context>
# raw rows: file TAB line TAB excerpt. Writes the capped hits and the count.
record() {
  local rule="$1" q="$2" kind="$3" raw="$4" after="$5" total kept f l ex
  total=$(wc -l < "$raw" | tr -d ' ')
  kept=0
  while IFS=$'\t' read -r f l ex; do
    ex=$(with_context "$f" "$l" "$ex" "$after")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rule" "$q" "$kind" "$f" "$l" "$ex" >> "$tmp_hits_all"
    (( kept >= CAP )) && continue
    kept=$((kept + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rule" "$q" "$kind" "$f" "$l" "$ex" >> "$tmp_hits"
  done < "$raw"
  if (( total > kept )); then
    printf '%s\t%s\t%s\t-\t0\t+%s more hit(s) not listed\n' "$rule" "$q" "$kind" "$((total - kept))" >> "$tmp_hits"
  fi
  printf '%s\t%s\t%s\t%s\n' "$rule" "$q" "$kind" "$total" >> "$tmp_counts"
}

run_grep() { # <rule> <q> <pattern> <flags>
  local rule="$1" q="$2" pat="$3" flags="$4" raw err code
  parse_flags "$flags" || die "$rule Q$q: bad detect flags: $flags"
  raw=$(mktemp); err=$(mktemp)
  local -a files=()
  while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(select_files "$FL_FILES" "$FL_EXCLUDE")
  if (( ${#files[@]} > 0 )); then
    LC_ALL=C grep -nHE -e "$pat" -- "${files[@]}" 2>"$err" | awk "$ROWS_AWK" > "$raw"
    code=${PIPESTATUS[0]}
    if (( code == 2 )); then
      cat "$err" | head -3 >&2
      rm -f "$raw" "$err"
      die "$rule Q$q: grep rejected the pattern: $pat"
    fi
  fi
  record "$rule" "$q" grep "$raw" "$FL_CONTEXT"
  rm -f "$raw" "$err"
}

run_path() { # <rule> <q> <pattern>
  local rule="$1" q="$2" pat="$3" raw err code
  raw=$(mktemp); err=$(mktemp)
  if (( ${#ALL_FILES[@]} > 0 )); then
    printf '%s\n' "${ALL_FILES[@]}" | LC_ALL=C grep -E -- "$pat" 2>"$err" \
      | awk '{ print $0 "\t0\t" $0 }' > "$raw"
    code=${PIPESTATUS[1]}
    if (( code == 2 )); then
      cat "$err" | head -3 >&2
      rm -f "$raw" "$err"
      die "$rule Q$q: grep rejected the path pattern: $pat"
    fi
  fi
  record "$rule" "$q" path "$raw" 0
  rm -f "$raw" "$err"
}

# The R9 gate runs once, lazily; its [Q<n>] lines are split by question.
run_gate_once() {
  [[ -n "$gate_out" ]] && return 0
  gate_out=$(mktemp)
  local gate="$SCRIPT_DIR/check-repo-brain.sh" code
  [[ -f "$gate" ]] || die "Detect-gate needs $gate beside this script"
  bash "$gate" "$ROOT" > "$gate_out" 2>&1
  code=$?
  if (( code == 2 )); then
    head -5 "$gate_out" >&2
    die "the R9 gate failed to run (exit 2); its questions are inconclusive"
  fi
  return 0
}

run_gate() { # <rule> <q> <Qn>
  local rule="$1" q="$2" qn="$3" raw tab
  run_gate_once
  raw=$(mktemp)
  tab=$(printf '\t')
  # "[Qn] <file>[:line] — <message> — see <conventions>" becomes
  # "<file> TAB line TAB <message>"; the em dashes are split by sed, which
  # matches bytes, so awk never counts multibyte characters.
  grep -E "\[$qn\]" "$gate_out" \
    | sed -e 's/^[[:space:]]*//' -e "s/^\(advisory: \)\{0,1\}\[$qn\] /\1/" \
          -e 's/ — see [^—]*$//' -e "s/ — /$tab/" -e 's/^advisory: \([^\t]*\)\t/\1\tadvisory: /' \
    | awk -F'\t' '
      {
        loc = $1; rest = (NF > 1) ? $2 : ""
        if (NF == 1) { print "-\t0\t" loc; next }
        sub(/^\.\//, "", loc)
        file = loc; line = 0
        if (match(loc, /:[0-9]+$/)) { file = substr(loc, 1, RSTART - 1); line = substr(loc, RSTART + 1) + 0 }
        print file "\t" line "\t" rest
      }' > "$raw"
  # A scoped review owns only the gate lines about its own files: an orphan
  # doc, an unwired root or another file's broken edge is the repository's
  # state, not the diff's, and is not a lead for this review's hunter.
  if [[ ! -f "$BUNDLE/dirs.txt" ]] && [[ -s "$raw" ]]; then
    scoped=$(mktemp); scope_list=$(mktemp)
    printf '%s\n' ${ALL_FILES[@]+"${ALL_FILES[@]}"} > "$scope_list"
    awk -F'\t' 'NR == FNR { in_scope[$0] = 1; next } ($1 in in_scope)' "$scope_list" "$raw" > "$scoped"
    mv "$scoped" "$raw"; rm -f "$scope_list"
  fi
  record "$rule" "$q" gate "$raw" 0
  rm -f "$raw"
}

run_judgment() { # <rule> <q>
  printf '%s\t%s\tjudgment\t-\n' "$1" "$2" >> "$tmp_counts"
}

# ---------- run the plan ----------
while IFS=$'\t' read -r rule q kind pat flags; do
  case "$kind" in
    grep)     run_grep "$rule" "$q" "$pat" "$flags" ;;
    path)     run_path "$rule" "$q" "$pat" ;;
    gate)     run_gate "$rule" "$q" "$pat" ;;
    judgment) run_judgment "$rule" "$q" ;;
  esac
done < "$plan_file"

# ---------- the suppression scan ----------
suppress_hits=$(mktemp)
if [[ -s "$BUNDLE/diff.patch" ]]; then
  # every added line as "file TAB line TAB text", then the directive pattern
  # anchored past the two leading fields
  awk '
    /^\+\+\+ / { f = $2; sub(/^b\//, "", f); next }
    /^--- / { next }
    /^@@ / { s = $3; sub(/^\+/, "", s); sub(/,.*$/, "", s); n = s - 1; next }
    /^\+/ { n++; t = substr($0, 2); gsub(/\t/, " ", t); sub(/^[ ]+/, "", t); print f "\t" n "\t" substr(t, 1, 200); next }
    /^-/ { next }
    { n++ }
  ' "$BUNDLE/diff.patch" | LC_ALL=C grep -E -- "^[^"$'\t'"]*"$'\t'"[0-9]+"$'\t'".*($LANG_SUPPRESS_RE)" > "$suppress_hits"
elif (( ${#ALL_FILES[@]} > 0 )); then
  LC_ALL=C grep -nHE -e "$LANG_SUPPRESS_RE" -- "${ALL_FILES[@]}" 2>/dev/null | awk "$ROWS_AWK" > "$suppress_hits"
fi
record SUPPRESS - grep "$suppress_hits" 0
rm -f "$suppress_hits"

# ---------- write the tables ----------
cp "$tmp_hits" "$BUNDLE/hits.tsv"
cp "$tmp_hits_all" "$BUNDLE/hits-all.tsv"
cp "$tmp_counts" "$BUNDLE/counts.tsv"

# ---------- print the counts table and the family totals ----------
n_grep=$(awk -F'\t' '$3 == "grep" && $1 != "SUPPRESS"' "$plan_file" | wc -l | tr -d ' ')
n_path=$(awk -F'\t' '$3 == "path"' "$plan_file" | wc -l | tr -d ' ')
n_gate=$(awk -F'\t' '$3 == "gate"' "$plan_file" | wc -l | tr -d ' ')
n_judg=$(awk -F'\t' '$3 == "judgment"' "$plan_file" | wc -l | tr -d ' ')
n_q=$(wc -l < "$plan_file" | tr -d ' ')
echo "$SCRIPT_NAME: $n_q questions ($n_grep grep, $n_path path, $n_gate gate, $n_judg judgment) over ${#SRC_FILES[@]} source + ${#TEST_FILES[@]} test files → $BUNDLE/hits.tsv, counts.tsv"
echo
awk -F'\t' 'BEGIN { printf "%-9s %-4s %-9s %s\n", "rule", "q", "kind", "hits" }
  { q = ($2 == "-") ? "-" : "Q" $2; printf "%-9s %-4s %-9s %s\n", $1, q, $3, $4 }' "$BUNDLE/counts.tsv"
echo
awk -F'\t' '
  BEGIN {
    fam["R1"] = "types"; fam["R2"] = "types"; fam["R11"] = "types"; fam["R12"] = "types"
    fam["R3"] = "structure"; fam["R4"] = "structure"; fam["R5"] = "structure"
    fam["R6"] = "tests-and-deps"; fam["R7"] = "tests-and-deps"; fam["R8"] = "tests-and-deps"; fam["R10"] = "tests-and-deps"
    fam["R9"] = "documentation"
    order[1] = "types"; order[2] = "structure"; order[3] = "tests-and-deps"; order[4] = "documentation"
    rules["types"] = "R1 R2 R11 R12"; rules["structure"] = "R3 R4 R5"
    rules["tests-and-deps"] = "R6 R7 R8 R10"; rules["documentation"] = "R9"
  }
  $1 == "SUPPRESS" { supp = $4; next }
  {
    f = fam[$1]; if (f == "") f = "other"
    nq[f]++
    if ($3 == "judgment") { nj[f]++; next }
    if ($4 + 0 > 0) { hits[f] += $4; nh[f]++; rh[f, $1] += $4 }
  }
  END {
    for (i = 1; i <= 4; i++) {
      f = order[i]
      printf "%-15s %5d hit(s) in %d of %d questions, %d judgment", f, hits[f] + 0, nh[f] + 0, nq[f] + 0, nj[f] + 0
      per = ""; n = split(rules[f], rs, " ")
      for (j = 1; j <= n; j++) if (rh[f, rs[j]] + 0 > 0) per = per (per == "" ? "" : " · ") rs[j] " " rh[f, rs[j]]
      if (per != "") printf " — %s", per
      printf "\n"
    }
    printf "%-15s %5d hit(s)\n", "suppressions", supp + 0
  }' "$BUNDLE/counts.tsv"
exit 0
