#!/usr/bin/env bash
# Fixture matrix for ldd-detect.sh — the detection pass's own conformance test.
#
# Each case builds a throwaway repository under a temp dir, runs the script
# against it with the plugin's own rule files, and asserts the exit code, the
# tables written and the presence or absence of report lines. The cases are the
# same for every language; the language-specific files they need — the project
# marker, a production file with two sleeps and a suppression directive under a
# layer directory, a test file with a sleep — come from the fixture rows spliced
# in below. A script whose language block serves several languages runs the
# whole matrix once per row.
#
# Usage:  bash scripts/ldd-detect_test.sh [path/to/ldd-detect.sh]
#         (default: the sibling ldd-detect.sh; the rules come from ../rules
#         beside it, so the test always runs the rendered rule files)
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the script under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
DETECT="${1:-$HERE/ldd-detect.sh}"
[[ -f "$DETECT" ]] || { echo "no such script: $DETECT" >&2; exit 2; }
DETECT=$(cd "$(dirname "$DETECT")" && pwd)/$(basename "$DETECT")
RULES=$(cd "$(dirname "$DETECT")/../rules" && pwd)

pass=0 failed=0
CASE=""
OUT="" ERR="" CODE=0
ROW=""
REPO="" BUNDLE=""

# ---------- harness ----------
begin() { CASE="$1"; [[ -n "$ROW" ]] && CASE="[$ROW] $1"; REPO=$(mktemp -d); BUNDLE=$(mktemp -d); }
finish() { rm -rf "$REPO" "$BUNDLE"; }

run_detect() { # [options...] — runs the script over $REPO with $BUNDLE
  OUT=$(cd "$REPO" && bash "$DETECT" "$@" --root . "$BUNDLE" 2>"$BUNDLE/.stderr"); CODE=$?
  ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
}
run_plan() { # [options...] — the parse-only mode
  OUT=$(bash "$DETECT" --plan "$@" 2>"$BUNDLE/.stderr"); CODE=$?
  ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
}

ok()   { pass=$((pass + 1)); echo "PASS  $CASE"; }
bad()  { failed=$((failed + 1)); echo "FAIL  $CASE — $1"; echo "      exit=$CODE"; printf '%s\n' "$OUT" "$ERR" | sed 's/^/      | /'; }

expect_exit() { (( CODE == $1 )) || { bad "expected exit $1"; return 1; }; }
expect_has() { # <needle> — in stdout or stderr
  printf '%s\n%s\n' "$OUT" "$ERR" | grep -qF -- "$1" || { bad "missing: $1"; return 1; }
}
expect_not() {
  printf '%s\n%s\n' "$OUT" "$ERR" | grep -qF -- "$1" && { bad "unexpected: $1"; return 1; }
  return 0
}
expect_quiet() { [[ -z "$ERR" ]] || { bad "stderr not empty"; return 1; }; }
count_of() { # <rule> <question> — the hits cell of counts.tsv, "-" for judgment
  awk -F'\t' -v r="$1" -v q="$2" '$1 == r && $2 == q { print $4 }' "$BUNDLE/counts.tsv"
}
expect_count() { # <rule> <question> <value|>=n>
  local got; got=$(count_of "$1" "$2")
  case "$3" in
    '>='*) [[ "$got" =~ ^[0-9]+$ ]] && (( got >= ${3#>=} )) || { bad "$1 Q$2: expected hits ${3}, got '$got'"; return 1; } ;;
    *)     [[ "$got" == "$3" ]] || { bad "$1 Q$2: expected hits $3, got '$got'"; return 1; } ;;
  esac
}

# ---------- fixture builders ----------
# The scope list: every source file of the row's language under $REPO.
write_scope() {
  (cd "$REPO" && find . -type f -name "$FX_GLOB" | sed 's|^\./||' | LC_ALL=C sort) > "$BUNDLE/files.txt"
}

# A doc root with a root index that lists nothing and one content doc no index
# reaches: the R9 gate's Q1 (orphan) fires, and nothing else in the doc root is
# malformed.
mk_docs() {
  mkdir -p "$REPO/docs"
  printf -- '---\nokf_version: "0.2"\n---\n# Map\n' > "$REPO/docs/index.md"
  printf -- '---\ntype: feature\ndescription: a doc nothing links to\n---\n# Orphan\n\nNothing links here.\n' > "$REPO/docs/orphan.md"
  printf '# Fixture\n\n@docs/index.md\n' > "$REPO/CLAUDE.md"
}

# mk_repo: the row's marker, its planted code and the doc root.
mk_repo() {
  fx_write_marker "$REPO" fixture
  fx_write_code
  mk_docs
  write_scope
}

# questions_in_rules: how many numbered questions the rendered rule files carry
# under "## Falsifying questions" — the number the plan must match.
questions_in_rules() {
  awk '
    FNR == 1 { insec = 0 }
    /^## / { insec = ($0 ~ /^## Falsifying questions/); next }
    insec && /^[0-9]+\. \*\*/ { n++ }
    END { print n + 0 }
  ' "$RULES"/R*.md
}

{{include "scripts/ldd-fixture.sh"}}

# ========================= cases =========================
run_row_cases() { # runs every case against the current row

begin "every detect line parses and the plan carries one row per question"
run_plan
want=$(questions_in_rules)
got=$(printf '%s\n' "$OUT" | grep -c .)
expect_exit 0 && expect_quiet && { (( got == want )) || bad "plan has $got rows, the rules carry $want questions"; } && (( got == want )) && ok
finish

begin "every pattern runs without stderr on the fixture and the tables are written"
mk_repo; run_detect
want=$(questions_in_rules)
rows=$(grep -vc '^SUPPRESS	' "$BUNDLE/counts.tsv")
expect_exit 0 && expect_quiet && expect_has "questions (" \
  && { (( rows == want )) || bad "counts.tsv has $rows question rows, the rules carry $want"; } && (( rows == want )) \
  && { [[ -f "$BUNDLE/hits.tsv" ]] || bad "hits.tsv not written"; } && [[ -f "$BUNDLE/hits.tsv" ]] && ok
finish

begin "a planted grep hit fires in production files only (R10 Q5: sleep)"
mk_repo; run_detect
expect_exit 0 && expect_count R10 5 2 && expect_count R7 6 '>=1' && ok
finish

begin "a planted path hit fires (R5 Q1: a layer directory)"
mk_repo; run_detect
expect_exit 0 && expect_count R5 1 '>=1' && ok
finish

begin "a planted gate hit fires (R9 Q1: an orphan doc)"
mk_repo; run_detect
expect_exit 0 && expect_count R9 1 '>=1' && ok
finish

begin "a judgment question renders as a judgment row"
mk_repo; run_detect
expect_exit 0 && expect_count R1 2 - && expect_has "R1        Q2   judgment  -" && ok
finish

begin "a suppression directive in the scope is counted"
mk_repo; run_detect
expect_exit 0 && expect_count SUPPRESS - '>=1' && ok
finish

begin "hits are capped per question with an overflow row"
mk_repo; run_detect --cap 1
expect_exit 0 && expect_count R10 5 2 \
  && { grep -q '^R10	5	grep	-	0	+1 more hit(s) not listed$' "$BUNDLE/hits.tsv" || bad "no overflow row for R10 Q5"; } \
  && grep -q '^R10	5	grep	-	0	+1 more hit(s) not listed$' "$BUNDLE/hits.tsv" && ok
finish

begin "a file listed as not bundled is still detection scope"
mk_repo
sed -i.bak "s|^$FX_SRC_FILE\$|$FX_SRC_FILE (not bundled: 3000 lines)|" "$BUNDLE/files.txt"; rm -f "$BUNDLE/files.txt.bak"
run_detect
expect_exit 0 && expect_count R10 5 2 && ok
finish

begin "two runs over one tree write identical counts"
mk_repo; run_detect
cp "$BUNDLE/counts.tsv" "$BUNDLE/first.tsv"
run_detect
expect_exit 0 && { cmp -s "$BUNDLE/first.tsv" "$BUNDLE/counts.tsv" || bad "counts.tsv differs between runs"; } \
  && cmp -s "$BUNDLE/first.tsv" "$BUNDLE/counts.tsv" && ok
finish

begin "a diff.patch limits the suppression scan to added lines"
mk_repo
{
  printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1,2 +1,3 @@\n' "$FX_SRC_FILE" "$FX_SRC_FILE" "$FX_SRC_FILE" "$FX_SRC_FILE"
  printf ' first line kept\n+%s\n-%s\n context\n' "$FX_SUPPRESS_LINE" "$FX_SUPPRESS_LINE"
} > "$BUNDLE/diff.patch"
run_detect
expect_exit 0 && expect_count SUPPRESS - 1 \
  && { grep -q "^SUPPRESS	-	grep	$FX_SRC_FILE	2	" "$BUNDLE/hits.tsv" || bad "suppression row does not carry the added line's file and number"; } \
  && grep -q "^SUPPRESS	-	grep	$FX_SRC_FILE	2	" "$BUNDLE/hits.tsv" && ok
finish

} # run_row_cases

for ROW in $FX_ROWS; do
  use_row "$ROW"
  run_row_cases
done
ROW=""

# --- row-independent ---
begin "a malformed detect line fails the run"
mkdir -p "$REPO/rules"; cp "$RULES"/R*.md "$REPO/rules/"
first=$(grep -l 'Detect-grep:' "$REPO/rules"/R*.md | head -1)
awk '!done && /Detect-grep:/ { sub(/Detect-grep:/, "Detect-wat:"); done = 1 } { print }' "$first" > "$first.tmp" && mv "$first.tmp" "$first"
run_plan --rules "$REPO/rules"
expect_exit 2 && expect_has "unknown detect kind" && expect_has "do not parse" && ok
finish

begin "a question without a detect line fails the run"
mkdir -p "$REPO/rules"; cp "$RULES"/R*.md "$REPO/rules/"
first=$(grep -l 'Detect: judgment' "$REPO/rules"/R*.md | head -1)
grep -v 'Detect: judgment' "$first" > "$first.tmp" && mv "$first.tmp" "$first"
run_plan --rules "$REPO/rules"
expect_exit 2 && expect_has "no detect line" && ok
finish

begin "a missing bundle directory is a usage error (exit 2)"
OUT=$(bash "$DETECT" "$REPO/does-not-exist" 2>&1); CODE=$?; ERR=""
expect_exit 2 && expect_has "not a directory" && ok
finish

# ========================= summary =========================
echo
echo "ldd-detect_test: $pass passed, $failed failed"
(( failed == 0 ))
