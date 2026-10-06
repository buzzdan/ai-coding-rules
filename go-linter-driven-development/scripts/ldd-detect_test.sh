#!/usr/bin/env bash
# Fixture matrix for ldd-detect.sh — the detection pass's own conformance test.
# residue-exempt: the routing cases name the sibling plugins on purpose.
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
#         sibling ldd-scope.sh writes the bundles of the mixed-repository
#         cases, and has its own matrix in ldd-scope_test.sh)
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

pass=0 failed=0 skipped=0
CASE=""
OUT="" ERR="" CODE=0
ROW=""
REPO="" BUNDLE=""
NO_PLUGINS=$(mktemp)
printf '{ "version": 2, "plugins": {} }\n' > "$NO_PLUGINS"
SIBLINGS_FILE=$(mktemp)
export LDD_INSTALLED_PLUGINS="$NO_PLUGINS"
trap 'rm -f "$NO_PLUGINS" "$SIBLINGS_FILE"' EXIT

# ---------- harness ----------
begin() { CASE="$1"; [[ -n "$ROW" ]] && CASE="[$ROW] $1"; REPO=$(mktemp -d); BUNDLE=$(mktemp -d); export LDD_INSTALLED_PLUGINS="$NO_PLUGINS"; }
finish() { rm -rf "$REPO" "$BUNDLE"; }
with_siblings() { export LDD_INSTALLED_PLUGINS="$SIBLINGS_FILE"; }

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
skip() { skipped=$((skipped + 1)); echo "SKIP  $CASE — $1"; }

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

# ---------- fixture rows: the Go row this script's language block serves ----------
# The matrix runs its cases once per row. use_row sets the row's variables and
# the fx_* builders write that language's files; the cases read only these.
#
#   FX_ROWS            the row ids, space-separated
#   FX_NATIVE          of the mixed repository's languages (d, go, python,
#                      typescript), the ones this plugin's block reviews itself
#   FX_GLOB            find(1) -name pattern for the row's source files
#   FX_SRC_FILE        the production file under a layer directory: two sleep
#                      calls and one suppression directive
#   FX_SUPPRESS_LINE   the suppression directive's line, as the diff adds it
#   fx_write_marker <dir> <module>   write the project marker for a (sub-)project
#   fx_write_code                    write $FX_SRC_FILE and a test file with a sleep
FX_ROWS="go"
FX_NATIVE="go"

use_row() {
  FX_GLOB='*.go'
  FX_SRC_FILE="services/worker.go"
  FX_SUPPRESS_LINE='var cache = map[string]string{} //nolint:gochecknoglobals // TODO'
}

fx_write_marker() { # <dir> <module>
  printf 'module example.com/%s\n\ngo 1.22\n' "$2" > "$1/go.mod"
}

fx_write_code() {
  mkdir -p "$REPO/services"
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
}

# ---------- the mixed repository: D, Python, Go and TypeScript in one tree ----------
# residue-exempt: the fixture is the same four-language tree for every plugin.
# The same fixture for every plugin: a repository with setup.cfg and go.mod at
# its root, D under weka/, Python under qa/, Go under s3/mc/, TypeScript under
# web/, a Bazel build file and a doc. mk_mixed_repo commits it; mixed_change commits a change that
# touches one file of each language plus the build file, each with one added
# comment line, so --base HEAD~1 is the mixed diff; mixed_change_d commits a
# change to the D file alone.
#
# The cases that route a group to a sibling plugin need the siblings: the test
# looks for them beside this plugin's directory (the repository checkout) and
# writes an installed-plugins file naming the ones it finds. LDD_INSTALLED_PLUGINS
# points the scripts at that file — never at the user's own.
MIXED_D="weka/management/telemetry.d"
MIXED_D_TEST="weka/management/testing/telemetry_test.d"
MIXED_PY="qa/lib/s3_bucket.py"
MIXED_PY_TEST="qa/tests/test_telemetry.py"
MIXED_GO="s3/mc/main.go"
MIXED_GO_TEST="s3/mc/main_test.go"
MIXED_TS="web/src/App.tsx"
MIXED_TS_TEST="web/src/App.test.tsx"
MIXED_BAZEL="weka/management/BUILD.bazel"

mk_mixed_repo() {
  mkdir -p "$REPO/weka/management/testing" "$REPO/qa/lib" "$REPO/qa/tests" "$REPO/s3/mc" "$REPO/web/src"
  printf '{"name": "web", "private": true}\n' > "$REPO/web/package.json"
  printf '[metadata]\nname = fixture\n' > "$REPO/setup.cfg"
  printf 'module example.com/fixture\n\ngo 1.22\n' > "$REPO/go.mod"
  cat > "$REPO/$MIXED_D" <<'D'
module weka.management.telemetry;

/// Sends one telemetry record.
void send(string record) {
    // @suppress(dscanner.suspicious.unused_parameter)
    import core.thread : Thread;
    Thread.sleep(1.seconds);
}
D
  cat > "$REPO/$MIXED_D_TEST" <<'D'
module weka.management.testing.telemetry_test;

unittest {
    import core.thread : Thread;
    Thread.sleep(10.msecs);
}
D
  cat > "$REPO/$MIXED_PY" <<'PY'
"""S3 bucket helpers."""

import time

CACHE: dict[str, str] = {}  # noqa: PLW0603


def wait(deadline: float) -> None:
    """Poll until the deadline."""
    while time.monotonic() < deadline:
        time.sleep(1)
PY
  cat > "$REPO/$MIXED_PY_TEST" <<'PY'
import time


def test_wait() -> None:
    time.sleep(0.01)
PY
  cat > "$REPO/$MIXED_GO" <<'GO'
package main

import "time"

var cache = map[string]string{} //nolint:gochecknoglobals // TODO

// Run polls until the deadline.
func Run(deadline time.Time) {
	for time.Now().Before(deadline) {
		time.Sleep(time.Second)
	}
}

func main() {}
GO
  cat > "$REPO/$MIXED_GO_TEST" <<'GO'
package main

import (
	"testing"
	"time"
)

func TestRun(t *testing.T) {
	time.Sleep(10 * time.Millisecond)
}
GO
  cat > "$REPO/$MIXED_TS" <<'TS'
// The application shell.

// eslint-disable-next-line import/no-mutable-exports
export let cache: Map<string, string> = new Map()

export async function run(deadline: number): Promise<void> {
  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
}
TS
  cat > "$REPO/$MIXED_TS_TEST" <<'TS'
import { it } from 'vitest'

it('runs', async () => {
  await new Promise((resolve) => setTimeout(resolve, 10))
})
TS
  printf 'd_library(\n    name = "management",\n    srcs = glob(["*.d"]),\n)\n' > "$REPO/$MIXED_BAZEL"
  printf '# Fixture\n' > "$REPO/README.md"
  (cd "$REPO" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
}

mixed_change() {
  printf '// added d comment\n' >> "$REPO/$MIXED_D"
  printf '# added py comment\n' >> "$REPO/$MIXED_PY"
  printf '// added go comment\n' >> "$REPO/$MIXED_GO"
  printf '// added ts comment\n' >> "$REPO/$MIXED_TS"
  printf '# added bazel line\n' >> "$REPO/$MIXED_BAZEL"
  (cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change)
}

mixed_change_d() {
  printf '// added d comment\n' >> "$REPO/$MIXED_D"
  (cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change-d)
}

# The sibling plugins beside this one in the repository checkout, as an
# installed-plugins file. SIBLINGS lists the names found; SIBLING_DIR_<name>
# is not needed: the file is what the scripts read.
SIBLINGS=""
write_installed_plugins() { # <file> [<plugin name>...] — names found beside this plugin
  local f="$1" name dir first=1; shift
  SIBLINGS=""
  printf '{\n  "version": 2,\n  "plugins": {\n' > "$f"
  for name in "$@"; do
    dir=$(cd "$HERE/../../$name" 2>/dev/null && pwd) || continue
    [[ -f "$dir/scripts/ldd-scope.sh" || -d "$dir/skills" ]] || continue
    (( first )) || printf ',\n' >> "$f"
    first=0
    printf '    "%s@ai-coding-rules": [\n      {\n        "scope": "user",\n        "installPath": "%s",\n        "version": "test"\n      }\n    ]' "$name" "$dir" >> "$f"
    SIBLINGS="$SIBLINGS $name"
  done
  printf '\n  }\n}\n' >> "$f"
  SIBLINGS="${SIBLINGS# }"
}
have_sibling() { case " $SIBLINGS " in *" $1 "*) return 0 ;; esac; return 1; }

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

write_installed_plugins "$SIBLINGS_FILE" go-linter-driven-development python-linter-driven-development linter-driven-development ts-react-linter-driven-development

for ROW in $FX_ROWS; do
  use_row "$ROW"
  run_row_cases
done
ROW=""


# --- the mixed repository: one detection pass per language group ---
is_native() { case " $FX_NATIVE " in *" $1 "*) return 0 ;; esac; return 1; }
run_detect_on() { # <bundle root> — the detection pass over what ldd-scope.sh wrote
  OUT=$(cd "$REPO" && bash "$DETECT" --root . "$1" 2>"$BUNDLE/.stderr"); CODE=$?
  ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
}
check_mixed_detect() { # one counts table per bundled group, one line per excluded one
  local id
  for id in d go python typescript; do
    if [[ "$(awk -F'\t' -v id="$id" '$1 == id { print $4 }' "$BUNDLE/scope-out/groups.txt")" == "-" ]]; then
      expect_has "== $id — not reviewed:" || return 1
      continue
    fi
    expect_has "== $id — " || return 1
    [[ -f "$BUNDLE/scope-out/$id/counts.tsv" ]] || { bad "$id group has no counts.tsv"; return 1; }
    (( $(grep -vc '^SUPPRESS	' "$BUNDLE/scope-out/$id/counts.tsv") > 0 )) || { bad "$id counts.tsv is empty"; return 1; }
  done
  expect_exit 0
}

begin "a scope split by language runs one detection pass per group, no sibling installed"
mk_mixed_repo; mixed_change
run_scope --base HEAD~1
if (( CODE != 0 )) && ! is_native d && ! is_native go && ! is_native python && ! is_native typescript; then skip "no group of the mixed diff is this plugin's"; finish
else
  run_detect_on "$BUNDLE/scope-out"
  check_mixed_detect && ok
  finish
fi

begin "a scope split by language runs each group with the plugin that reviews it"
mk_mixed_repo; mixed_change
if [[ -z "$SIBLINGS" ]]; then skip "no sibling plugin beside $(dirname "$DETECT")/.."; finish
else
  with_siblings; run_scope --base HEAD~1
  with_siblings; run_detect_on "$BUNDLE/scope-out"
  check_mixed_detect \
    && { for n in $SIBLINGS; do case "$n" in go-linter-driven-development) is_native go || expect_has "== go — $n" || break ;; python-linter-driven-development) is_native python || expect_has "== python — $n" || break ;; ts-react-linter-driven-development) is_native typescript || expect_has "== typescript — $n" || break ;; esac; done; (( failed == 0 )); } \
    && ok
  finish
fi

begin "a hand-written scope list that spans two languages is refused (exit 2)"
mk_mixed_repo
printf '%s\n%s\n' "$MIXED_GO" "$MIXED_PY" > "$BUNDLE/files.txt"
run_detect
expect_exit 2 && expect_has "spans several languages" && ok
finish

begin "a bundle's language.txt names a language this plugin has no row for (exit 2)"
mk_mixed_repo
printf '%s\n' "$MIXED_D" > "$BUNDLE/files.txt"
printf 'd\n' > "$BUNDLE/language.txt"
run_detect
if is_native d; then expect_exit 0 && ok; else expect_exit 2 && expect_has "no language block for d" && ok; fi
finish

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
echo "ldd-detect_test: $pass passed, $failed failed, $skipped skipped"
(( failed == 0 ))
