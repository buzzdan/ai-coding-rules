#!/usr/bin/env bash
# Slicing step of the refactoring skill for the python-linter-driven-development plugin.
#
# Reads one line per routed finding or lint escalation, groups the lines that
# share a file into slices, orders a slice's moves as the multi-rule procedures
# sequence them, assigns the slices to waves so that no two slices of one wave
# touch the same package, and prints one spawn block per slice. The parent
# spawns every slice of a wave in one message and reads the receipts before
# the next wave; it composes no slice by hand.
#
# Usage:  bash scripts/ldd-slices.sh [options] <slices.tsv>
#         <slices.tsv>      one line per move, four tab-separated fields:
#                           rule TAB move TAB files TAB anchor
#                           rule   R<n>
#                           move   the move as the rule's Fix pattern spells it
#                                  (a combined name is two lines)
#                           files  relative paths, separated by spaces or
#                                  commas; a path carries no whitespace
#                           anchor the finding's file:line, any text
#                           Blank lines and CR line ends are ignored; an exact
#                           duplicate line is dropped and counted.
#   --rules <dir>           the rule files (default: ../rules beside this script)
#   --waves 0               every slice in wave 1 (the parent runs them serially)
#   --order                 print the sequencing keys and exit
#
# Output: one summary line —
#   ldd-slices: <n> lines → <k> slices in <w> waves (<l> large, <d> duplicate lines dropped)
# then, per wave, a "-- wave <w>" line and one block per slice of the wave:
#   == slice <k> (wave <w>) <n> files, <m> moves[, large]
#   MOVE <i>: <move> — R<n> — <anchor>          one line per move, in order
#   FILES: <every file of the slice, sorted, one line>
#   PKGS: <the directories of those files, sorted>
#   RULE: <absolute path of the rule file>      one line per distinct rule
# A slice over five files is "large" and stays whole. An empty table prints
# "ldd-slices: nothing to slice".
#
# Order inside a slice: each move takes the rank of the first sequencing key
# (--order) that is a case-insensitive substring of its name; a move that
# matches no key but is a move bullet of its rule's file ranks after every
# keyed move and before the placement moves (demote, promote, move method);
# ties keep input order. A move name that is neither is refused with the keys
# printed: the parent's spelling has to be the rule's.
#
# Exit codes: 0 slices printed · 2 usage error, a line that does not parse,
#             a rule without a file, a move name that resolves to nothing, or
#             a lint configuration file in a slice (changing lint
#             configuration is suppression by another route)
#
# Uses only POSIX-portable tools: awk, sed, sort, tr.

set -u

SCRIPT_NAME="ldd-slices"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RULES_DIR="$SCRIPT_DIR/../rules"
WAVES=1
ORDER=0
TABLE=""
TAB=$'\t'

# The sequencing keys, in rank order; the last three are the placement moves.
# (one line; awk takes the list as a string, and the macOS awk rejects a newline in it)
ORDER_KEYS='extract function named|early return|extract function|split phase|extract leaf type|extract collection type|replace primitive|introduce parameter object|name enum|add validating constructor|introduce null object|extract clean island|push the global|replace import-time|replace duplicated switch|interface dispatch|strategy map|keep the single|demote|promote|move method'
PLACEMENT_KEYS=3

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

while (( $# > 0 )); do
  case "$1" in
    --rules)   RULES_DIR="${2:-}"; shift 2 ;;
    --waves)   WAVES="${2:-}"; shift 2 ;;
    --order)   ORDER=1; shift ;;
    -h|--help) usage ;;
    --*)       die "unknown option: $1" ;;
    *)         [[ -n "$TABLE" ]] && die "one table, got also: $1"; TABLE="$1"; shift ;;
  esac
done
(( ORDER )) && { printf '%s\n' "$ORDER_KEYS" | tr '|' '\n'; exit 0; }
[[ -n "$TABLE" ]] || usage
[[ -f "$TABLE" ]] || die "no such table: $TABLE"
[[ "$WAVES" =~ ^[01]$ ]] || die "--waves takes 0 or 1, got: $WAVES"
[[ -d "$RULES_DIR" ]] || die "no rules directory: $RULES_DIR"
RULES_DIR=$(cd "$RULES_DIR" && pwd)

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

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------- the table: CR and blank lines dropped, line numbers kept ----------
tr -d '\r' < "$TABLE" | awk -F'\t' -v OFS='\t' 'NF > 0 && $0 !~ /^[ \t]*$/ { print NR, $0 }' > "$WORK/lines.tsv"
if [[ ! -s "$WORK/lines.tsv" ]]; then
  echo "$SCRIPT_NAME: nothing to slice"
  exit 0
fi

# ---------- the rule files and their move bullets ----------
# rules.tsv: R<n> TAB absolute path · bullets.tsv: R<n> TAB lower-cased bold text
: > "$WORK/rules.tsv"; : > "$WORK/bullets.tsv"
for f in "$RULES_DIR"/R[0-9]*.md; do
  [[ -f "$f" ]] || continue
  r=$(basename "$f"); r=${r%%-*}
  printf '%s\t%s\n' "$r" "$f" >> "$WORK/rules.tsv"
  sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' "$f" | tr '[:upper:]' '[:lower:]' | sed "s/^/$r$TAB/" >> "$WORK/bullets.tsv"
done

# ---------- validate every line; all messages, then exit 2 ----------
awk -F'\t' -v OFS='\t' -v keys="$ORDER_KEYS" -v nplace="$PLACEMENT_KEYS" -v lintre="$LANG_LINT_CONFIG_RE" -v name="$SCRIPT_NAME" \
    -v rulesf="$WORK/rules.tsv" -v bulletsf="$WORK/bullets.tsv" '
BEGIN {
  nk = split(keys, K, "|")
  while ((getline l < rulesf) > 0) { split(l, a, "\t"); rulepath[a[1]] = a[2] }
  while ((getline l < bulletsf) > 0) { split(l, a, "\t"); nb++; brule[nb] = a[1]; btext[nb] = a[2] }
}
function rank(rule, move,   i, lm, m) {
  lm = tolower(move)
  for (i = 1; i <= nk; i++) if (index(lm, K[i]) > 0) return i
  for (i = 1; i <= nb; i++) if (brule[i] == rule && index(btext[i], lm) > 0) return nk - nplace + 0.5  # after the keyed moves, before placement
  return 0
}
{
  n = $1
  if (NF != 5) { print name ": line " n ": expected four tab-separated fields (rule, move, files, anchor), got " NF - 1 > "/dev/stderr"; bad++; next }
  rule = $2; move = $3; files = $4; anchor = $5
  if (rule !~ /^R[0-9]+$/) { print name ": line " n ": rule is not R<n>: " rule > "/dev/stderr"; bad++; next }
  if (!(rule in rulepath)) { print name ": line " n ": no rule file for " rule " under the rules directory" > "/dev/stderr"; bad++; next }
  if (move ~ /^[ \t]*$/) { print name ": line " n ": empty move" > "/dev/stderr"; bad++; next }
  if (anchor ~ /^[ \t]*$/) { print name ": line " n ": empty anchor" > "/dev/stderr"; bad++; next }
  gsub(/,/, " ", files); nf = split(files, F, /[ \t]+/)
  cnt = 0
  for (i = 1; i <= nf; i++) {
    if (F[i] == "") continue
    if (F[i] ~ /["'"'"'\\]/) { print name ": line " n ": a path with a quote or a backslash — paths carry no whitespace and need no quoting: " F[i] > "/dev/stderr"; bad++; next }
    if (F[i] ~ lintre) { print name ": line " n ": a lint configuration file in the slice — changing lint configuration is suppression by another route: " F[i] > "/dev/stderr"; bad++; next }
    cnt++
  }
  if (cnt == 0) { print name ": line " n ": no files" > "/dev/stderr"; bad++; next }
  r = rank(rule, move)
  if (r == 0) { print name ": line " n ": move matches no sequencing key and no move bullet of " rule ": " move > "/dev/stderr"; unknown = 1; bad++; next }
}
END {
  if (unknown) { print name ": the sequencing keys are:" > "/dev/stderr"; for (i = 1; i <= nk; i++) print "  " K[i] > "/dev/stderr" }
  exit (bad > 0 ? 2 : 0)
}' "$WORK/lines.tsv" || exit 2

# ---------- dedupe (first occurrence wins), then slice ----------
total=$(wc -l < "$WORK/lines.tsv" | tr -d ' ')
awk -F'\t' -v OFS='\t' '{ key = $2 "\t" $3 "\t" $4 "\t" $5; if (key in seen) next; seen[key] = 1; print }' "$WORK/lines.tsv" > "$WORK/uniq.tsv"
kept=$(wc -l < "$WORK/uniq.tsv" | tr -d ' ')
dups=$(( total - kept ))

awk -F'\t' -v keys="$ORDER_KEYS" -v nplace="$PLACEMENT_KEYS" -v waves="$WAVES" -v name="$SCRIPT_NAME" \
    -v total="$total" -v dups="$dups" -v rulesf="$WORK/rules.tsv" -v bulletsf="$WORK/bullets.tsv" '
BEGIN {
  nk = split(keys, K, "|")
  while ((getline l < rulesf) > 0) { split(l, a, "\t"); rulepath[a[1]] = a[2] }
  while ((getline l < bulletsf) > 0) { split(l, a, "\t"); nb++; brule[nb] = a[1]; btext[nb] = a[2] }
}
function rank(rule, move,   i, lm) {
  lm = tolower(move)
  for (i = 1; i <= nk; i++) if (index(lm, K[i]) > 0) return i
  for (i = 1; i <= nb; i++) if (brule[i] == rule && index(btext[i], lm) > 0) return nk - nplace + 0.5
  return 0
}
function find(x) { while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x] } return x }
function union(a, b,   ra, rb) { ra = find(a); rb = find(b); if (ra != rb) parent[rb] = ra }
function dirof(p,   q, i) { q = p; i = 0; while (match(q, /\//)) { i += RSTART; q = substr(q, RSTART + 1) } return i ? substr(p, 1, i - 1) : "." }
function plural(n, w) { return n " " w (n == 1 ? "" : "s") }
{
  nm++; rule[nm] = $2; move[nm] = $3; anchor[nm] = $5; rk[nm] = rank($2, $3)
  f = $4; gsub(/,/, " ", f); n = split(f, F, /[ \t]+/)
  nfile[nm] = 0
  for (i = 1; i <= n; i++) {
    if (F[i] == "") continue
    nfile[nm]++; mfile[nm, nfile[nm]] = F[i]
    if (!(F[i] in parent)) parent[F[i]] = F[i]
    if (nfile[nm] > 1) union(mfile[nm, 1], F[i])
  }
}
END {
  # slices numbered by first appearance of their root
  for (m = 1; m <= nm; m++) {
    root = find(mfile[m, 1])
    if (!(root in sliceof)) { ns++; sliceof[root] = ns }
    s = sliceof[root]; smoves[s]++; sm[s, smoves[s]] = m
    for (i = 1; i <= nfile[m]; i++) { p = mfile[m, i]; if (!((s, p) in hasfile)) { hasfile[s, p] = 1; sfiles[s]++; sf[s, sfiles[s]] = p } }
  }
  # order moves (insertion sort by rank, ties keep input order) and files (by name)
  for (s = 1; s <= ns; s++) {
    for (i = 2; i <= smoves[s]; i++) { v = sm[s, i]; j = i - 1; while (j >= 1 && rk[sm[s, j]] > rk[v]) { sm[s, j + 1] = sm[s, j]; j-- } sm[s, j + 1] = v }
    for (i = 2; i <= sfiles[s]; i++) { v = sf[s, i]; j = i - 1; while (j >= 1 && sf[s, j] > v) { sf[s, j + 1] = sf[s, j]; j-- } sf[s, j + 1] = v }
    # packages: the sorted distinct directories
    spkgs[s] = 0
    for (i = 1; i <= sfiles[s]; i++) {
      p = sf[s, i]; d = dirof(p)
      if (!((s, d) in haspkg)) { haspkg[s, d] = 1; spkgs[s]++; sp[s, spkgs[s]] = d }
    }
    for (i = 2; i <= spkgs[s]; i++) { v = sp[s, i]; j = i - 1; while (j >= 1 && sp[s, j] > v) { sp[s, j + 1] = sp[s, j]; j-- } sp[s, j + 1] = v }
    if (sfiles[s] > 5) nlarge++
  }
  # waves: greedy in slice order — the first wave with no package of this slice
  nw = 0
  for (s = 1; s <= ns; s++) {
    if (waves == 0) { wave[s] = 1; nw = 1; continue }
    for (w = 1; w <= nw + 1; w++) {
      clash = 0
      for (i = 1; i <= spkgs[s]; i++) if ((w, sp[s, i]) in wpkg) { clash = 1; break }
      if (!clash) break
    }
    wave[s] = w; if (w > nw) nw = w
    for (i = 1; i <= spkgs[s]; i++) wpkg[w, sp[s, i]] = 1
  }
  printf "%s: %s → %s in %s (%d large, %s dropped)\n", name, plural(total, "line"), plural(ns, "slice"), plural(nw, "wave"), nlarge + 0, plural(dups, "duplicate line")
  for (w = 1; w <= nw; w++) {
    print "-- wave " w
    for (s = 1; s <= ns; s++) {
      if (wave[s] != w) continue
      printf "== slice %d (wave %d) %s, %s%s\n", s, w, plural(sfiles[s], "file"), plural(smoves[s], "move"), (sfiles[s] > 5 ? ", large" : "")
      for (i = 1; i <= smoves[s]; i++) { m = sm[s, i]; printf "MOVE %d: %s — %s — %s\n", i, move[m], rule[m], anchor[m] }
      line = "FILES:"; for (i = 1; i <= sfiles[s]; i++) line = line " " sf[s, i]; print line
      line = "PKGS:"; for (i = 1; i <= spkgs[s]; i++) line = line " " sp[s, i]; print line
      for (i = 1; i <= smoves[s]; i++) { r = rule[sm[s, i]]; if (!((s, r) in seenrule)) { seenrule[s, r] = 1; print "RULE: " rulepath[r] } }
    }
  }
}' "$WORK/uniq.tsv"
