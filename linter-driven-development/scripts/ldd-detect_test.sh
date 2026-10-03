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
#         beside it, so the test always runs the rendered rule files; the
#         sibling ldd-scope.sh is tested on the scope rungs the review uses)
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the script under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
DETECT="${1:-$HERE/ldd-detect.sh}"
[[ -f "$DETECT" ]] || { echo "no such script: $DETECT" >&2; exit 2; }
DETECT=$(cd "$(dirname "$DETECT")" && pwd)/$(basename "$DETECT")
RULES=$(cd "$(dirname "$DETECT")/../rules" && pwd)
SCOPE_SH=$(dirname "$DETECT")/ldd-scope.sh

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
run_scope() { # [args...] — runs ldd-scope.sh over $REPO into $BUNDLE/scope-out
  rm -rf "$BUNDLE/scope-out"
  OUT=$(cd "$REPO" && bash "$SCOPE_SH" --out "$BUNDLE/scope-out" "$@" 2>"$BUNDLE/.stderr"); CODE=$?
  ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
}
git_commit_repo() { # commits everything under $REPO, quietly
  (cd "$REPO" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
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

# ---------- fixture rows: one per language the detected block supports ----------
# The matrix runs its cases once per row. use_row sets the row's variables and
# the fx_* builders write that language's files; the cases read only these.
#
#   FX_ROWS            the row ids, space-separated
#   FX_GLOB            find(1) -name pattern for the row's source files
#   FX_SRC_FILE        the production file under a layer directory: two sleep
#                      calls and one suppression directive
#   FX_SUPPRESS_LINE   the suppression directive's line, as the diff adds it
#   FX_LINT_CONFIG     the linter's configuration file, which no slice may touch
#   fx_write_marker <dir> <module>   write the project marker for a (sub-)project
#   fx_write_code                    write $FX_SRC_FILE and a test file with a sleep
FX_ROWS="go python"

use_row() {
  case "$1" in
    go)
      FX_GLOB='*.go'
      FX_SRC_FILE="services/worker.go"
      FX_SUPPRESS_LINE='var cache = map[string]string{} //nolint:gochecknoglobals // TODO'
      FX_LINT_CONFIG='.golangci.yaml'
      ;;
    python)
      FX_GLOB='*.py'
      FX_SRC_FILE="services/worker.py"
      FX_SUPPRESS_LINE='CACHE: dict[str, str] = {}  # noqa: PLW0603'
      FX_LINT_CONFIG='pyproject.toml'
      ;;
  esac
}

fx_write_marker() { # <dir> <module>
  case "$ROW" in
    go)     printf 'module example.com/%s\n\ngo 1.22\n' "$2" > "$1/go.mod" ;;
    python) printf '[project]\nname = "%s"\nversion = "0.1.0"\n' "$2" > "$1/pyproject.toml" ;;
  esac
}

fx_write_code() {
  mkdir -p "$REPO/services"
  case "$ROW" in
    go)
      cat > "$REPO/services/worker.go" <<'GO'
package services

import "time"

var cache = map[string]string{} //nolint:gochecknoglobals // TODO

// Run polls until the deadline.
func Run(deadline time.Time) {
	for time.Now().Before(deadline) {
		time.Sleep(time.Second)
	}
	time.Sleep(50 * time.Millisecond)
}
GO
      cat > "$REPO/services/worker_test.go" <<'GO'
package services_test

import (
	"testing"
	"time"
)

func TestRun(t *testing.T) {
	time.Sleep(10 * time.Millisecond)
}
GO
      ;;
    python)
      mkdir -p "$REPO/tests"
      cat > "$REPO/services/worker.py" <<'PY'
"""Polling worker."""

import time

CACHE: dict[str, str] = {}  # noqa: PLW0603


def run(deadline: float) -> None:
    """Poll until the deadline."""
    while time.monotonic() < deadline:
        time.sleep(1)
    time.sleep(0.05)
PY
      cat > "$REPO/tests/test_worker.py" <<'PY'
import time


def test_run() -> None:
    time.sleep(0.01)
PY
      ;;
  esac
}

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

begin "a planted gate hit fires on a whole-repository bundle (R9 Q1: an orphan doc)"
mk_repo; : > "$BUNDLE/dirs.txt"; run_detect
expect_exit 0 && expect_count R9 1 '>=1' && ok
finish

begin "a scoped bundle keeps only the gate lines about its own files"
mk_repo; run_detect
expect_exit 0 && expect_count R9 1 0 && ok
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

begin "hits-all.tsv carries every hit of a capped question"
mk_repo; run_detect --cap 1
expect_exit 0 && { (( $(grep -c '^R10	5	grep	' "$BUNDLE/hits-all.tsv") == 2 )) || bad "hits-all.tsv does not carry both R10 Q5 hits"; } \
  && (( $(grep -c '^R10	5	grep	' "$BUNDLE/hits-all.tsv") == 2 )) \
  && { ! grep -q 'more hit(s) not listed' "$BUNDLE/hits-all.tsv" || bad "hits-all.tsv has an overflow row"; } \
  && ! grep -q 'more hit(s) not listed' "$BUNDLE/hits-all.tsv" && ok
finish

begin "ldd-scope: a directory argument is expanded to the source files under it"
mk_repo; git_commit_repo; run_scope services
expect_exit 0 && expect_has "files bundled" \
  && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks $FX_SRC_FILE"; } \
  && grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" && ok
finish

begin "ldd-scope: a committed file named on a clean tree contributes every comment line"
mk_repo; git_commit_repo; run_scope "$FX_SRC_FILE"
expect_exit 0 && expect_has "diff 0 lines" \
  && { grep -q "^$FX_SRC_FILE:[0-9]*:" "$BUNDLE/scope-out/comments.txt" || bad "comments.txt has no line of $FX_SRC_FILE"; } \
  && grep -q "^$FX_SRC_FILE:[0-9]*:" "$BUNDLE/scope-out/comments.txt" && ok
finish

begin "ldd-scope: a comment line carries the code line below it"
mk_repo; git_commit_repo; run_scope "$FX_SRC_FILE"
expect_exit 0 && { grep -q " ⏎ " "$BUNDLE/scope-out/comments.txt" || bad "no code line after a comment in comments.txt"; } \
  && grep -q " ⏎ " "$BUNDLE/scope-out/comments.txt" && ok
finish

begin "ldd-scope: an empty explicit scope prints nothing to review"
mk_repo; git_commit_repo; mkdir -p "$REPO/empty"; run_scope empty
expect_exit 0 && expect_has "nothing to review" && ok
finish

# fx_comment_line — a one-line comment in the row's language, for added lines
fx_comment_line() { case "$FX_GLOB" in *.py) printf '# added by the test\n' ;; *) printf '// added by the test\n' ;; esac; }
# fx_ext — the row's source suffix, for files the cases create
fx_ext() { printf '%s' "${FX_GLOB#\*}"; }

begin "ldd-scope: --base diffs the branch against its base and keeps only the added comment lines"
mk_repo; git_commit_repo
fx_comment_line >> "$REPO/$FX_SRC_FILE"
(cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change)
run_scope --base HEAD~1
expect_exit 0 && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the changed file"; } \
  && { [[ -s "$BUNDLE/scope-out/diff.patch" ]] || bad "diff.patch is empty on --base"; } \
  && { (( $(wc -l < "$BUNDLE/scope-out/comments.txt") == 1 )) || bad "comments.txt should carry the one added comment line, has $(wc -l < "$BUNDLE/scope-out/comments.txt")"; } \
  && grep -q "added by the test" "$BUNDLE/scope-out/comments.txt" && ok
finish

begin "ldd-scope: the worktree rung takes changed and untracked files, every comment line of the untracked one"
mk_repo; git_commit_repo
fx_comment_line >> "$REPO/$FX_SRC_FILE"
{ fx_comment_line; fx_comment_line; } > "$REPO/services/fresh$(fx_ext)"
run_scope
expect_exit 0 && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the changed file"; } \
  && { grep -qx "services/fresh$(fx_ext)" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the untracked file"; } \
  && { (( $(grep -c "^services/fresh" "$BUNDLE/scope-out/comments.txt") == 2 )) || bad "the untracked file's two comment lines are not both in comments.txt"; } \
  && (( $(grep -c "^$FX_SRC_FILE:" "$BUNDLE/scope-out/comments.txt") == 1 )) && ok
finish

begin "ldd-scope: --all writes dirs.txt with a file and line count per directory"
mk_repo; git_commit_repo; run_scope --all
expect_exit 0 && { [[ -f "$BUNDLE/scope-out/dirs.txt" ]] || bad "no dirs.txt on --all"; } \
  && { grep -qE "^services	[0-9]+	[0-9]+$" "$BUNDLE/scope-out/dirs.txt" || bad "dirs.txt has no 'services TAB files TAB lines' row: $(cat "$BUNDLE/scope-out/dirs.txt")"; } \
  && { (( $(awk -F'\t' '{ n += $2 } END { print n + 0 }' "$BUNDLE/scope-out/dirs.txt") == 2 )) || bad "dirs.txt file counts do not sum to the 2 bundled files"; } \
  && { [[ ! -f "$BUNDLE/scope-out/diff.patch" ]] || bad "--all wrote a diff.patch"; } && ok
finish

begin "ldd-scope: a deleted, a binary, an over-long and a generated file are listed, not bundled"
mk_repo; git_commit_repo
printf '\000\001\002binary\n' > "$REPO/services/blob$(fx_ext)"
{ fx_comment_line; seq 1 5 | sed 's/^/x = /'; } > "$REPO/services/long$(fx_ext)"
{ printf '%s\n' "$(fx_comment_line | sed 's/added by the test/@generated by a tool/')"; fx_comment_line; } > "$REPO/services/gen$(fx_ext)"
rm "$REPO/$FX_SRC_FILE"
run_scope --max-lines 3 "$FX_SRC_FILE" "services/blob$(fx_ext)" "services/long$(fx_ext)" "services/gen$(fx_ext)"
expect_exit 0 && expect_has "4 listed not bundled" \
  && { grep -q "^$FX_SRC_FILE (not bundled: deleted)$" "$BUNDLE/scope-out/files.txt" || bad "deleted file not listed as deleted"; } \
  && { grep -q "^services/blob$(fx_ext) (not bundled: binary)$" "$BUNDLE/scope-out/files.txt" || bad "binary file not listed as binary"; } \
  && { grep -q "^services/long$(fx_ext) (not bundled: 6 lines)$" "$BUNDLE/scope-out/files.txt" || bad "long file not listed with its line count"; } \
  && { grep -q "^services/gen$(fx_ext) (not bundled: generated)$" "$BUNDLE/scope-out/files.txt" || bad "generated file not listed as generated"; } \
  && { [[ ! -d "$BUNDLE/scope-out/scope/services" ]] || bad "a not-bundled file was written under scope/"; } && ok
finish

begin "ldd-scope: --out refuses a directory that is not empty (exit 2)"
mk_repo; git_commit_repo
mkdir -p "$BUNDLE/scope-out"; : > "$BUNDLE/scope-out/stale"
OUT=$(cd "$REPO" && bash "$SCOPE_SH" --out "$BUNDLE/scope-out" "$FX_SRC_FILE" 2>&1); CODE=$?; ERR=""
expect_exit 2 && expect_has "empty" && ok
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
