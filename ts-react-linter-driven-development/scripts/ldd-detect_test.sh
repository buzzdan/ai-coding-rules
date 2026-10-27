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
run_detect_bundle() { # <bundle> [options...] — runs the script over $REPO with that bundle
  local b="$1"; shift
  OUT=$(cd "$REPO" && bash "$DETECT" "$@" --root . "$b" 2>"$BUNDLE/.stderr"); CODE=$?
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
count_of() { # <rule> <question> — the hits cell of counts.tsv (COUNTS_FILE, default the
           # case bundle's), "-" for judgment
  awk -F'\t' -v r="$1" -v q="$2" '$1 == r && $2 == q { print $4 }' "${COUNTS_FILE:-$BUNDLE/counts.tsv}"
}
expect_count() { # <rule> <question> <value|>=n>
  local got; got=$(count_of "$1" "$2")
  case "$3" in
    '>='*) [[ "$got" =~ ^[0-9]+$ ]] && (( got >= ${3#>=} )) || { bad "$1 Q$2: expected hits ${3}, got '$got'"; return 1; } ;;
    *)     [[ "$got" == "$3" ]] || { bad "$1 Q$2: expected hits $3, got '$got'"; return 1; } ;;
  esac
}

# run_stub_gate <gate body> [options...] — runs a copy of the script whose
# check-repo-brain.sh beside it is a stub with that body, over $REPO with $BUNDLE
run_stub_gate() {
  local body="$1" fake; shift
  fake=$(mktemp -d)
  cp "$DETECT" "$fake/ldd-detect.sh"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$fake/check-repo-brain.sh"
  OUT=$(cd "$REPO" && bash "$fake/ldd-detect.sh" --rules "$RULES" "$@" --root . "$BUNDLE" 2>"$BUNDLE/.stderr"); CODE=$?
  ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
  rm -rf "$fake"
}
# expect_gate_inconclusive <reason> — every gate question of the plan counts
# "inconclusive", and the "R9 gate:" line carries the reason
expect_gate_inconclusive() {
  local q n=0
  expect_has "R9 gate: inconclusive — $1" || return 1
  for q in $(bash "$DETECT" --plan --rules "$RULES" | awk -F'\t' '$3 == "gate" { sub(/^Q/, "", $2); print $2 }'); do
    expect_count R9 "$q" inconclusive || return 1
    n=$((n + 1))
  done
  (( n > 0 )) || { bad "the plan has no gate question"; return 1; }
  printf '%s\n' "$OUT" | grep -qE "^documentation .* $n inconclusive" \
    || { bad "the documentation family line does not count $n inconclusive"; return 1; }
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

# ---------- fixture rows: the TypeScript row this script's language block serves ----------
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
#
# The gap linter's matrix (ldd-lint_test.sh) reads these as well:
#   FX_EXT             the source suffix of the files the lint cases write
#   FX_LINE_COMMENT    a comment-only line
#   FX_BLOCK_OPEN      the line that opens a block comment, "" when the
#   FX_BLOCK_CLOSE     language has none, and the line that closes it
#   FX_SKIP_FILES      source file names a directory count leaves out
#   FX_ROUTED_FILE     the plugin's recommended config under setup/ for the
#                      language, which enables every rule id the refactoring
#                      routing table routes to a design rule; FX_RULE_ID_RE the
#                      shape of the language's rule ids in that table, and
#                      FX_ROUTED_SKIP the ids the config leaves out on purpose;
#                      all "" when the plugin's table names no linter rule
#   FX_ADOPTED_CONFIG  the name under which a repository keeps the plugin's
#                      recommended config as its own file and imports it; ""
#                      when the setup is copied into the linter's own config
#   FX_SETUP_FILE      the plugin's recommended config under setup/ that holds
#                      the file-length limit, and FX_LENGTH_RULE its rule; both
#                      "" when the language's linter has no file-length rule
#   fx_test_file <dir> <n>             a test file's path in <dir>
#   FX_LINTER_CONFIG   the path, under the repository root, of the file that
#                      fx_write_linter_config writes, and FX_LINTER_COMMENT the
#                      marker that turns one of its lines into a comment
#   fx_write_linter_config           the repository linter config that names
#                                    the language's file-length rule
#   fx_write_linter_config_other     a linter config that names a rule of a
#                                    similar name and no file-length rule
#   fx_write_linter_config_in_comment  a linter config that names the file-length
#                                    rule only inside comments
FX_ROWS="typescript"
FX_NATIVE="typescript"

# The row's glob is `*.ts`, not the block's `*.ts*`: the matrix derives file
# names for the files it creates from it, and `fresh.ts*` is no file name.
# Every file the row writes is a `.ts` file, so both globs select the same set.
use_row() {
  FX_LINTER_CONFIG='eslint.config.mjs'
  FX_SETUP_FILE='eslint.config.ldd.mjs'
  FX_ADOPTED_CONFIG='eslint.config.ldd.mjs'
  FX_ROUTED_FILE='eslint.config.ldd.mjs'
  FX_RULE_ID_RE='^(@[a-z-]+/)?[a-z-]+(/[a-z*-]+)?$'
  # no-restricted-syntax needs the repository's config module path;
  # package-size is the gap linter's
  FX_ROUTED_SKIP='no-restricted-syntax package-size'
  FX_LENGTH_RULE='sonarjs/max-lines'
  FX_LINTER_COMMENT='//'
  FX_EXT='.ts'
  FX_LINE_COMMENT='// note'
  FX_BLOCK_OPEN='/*'
  FX_BLOCK_CLOSE='*/'
  FX_SKIP_FILES='index.ts card.stories.ts'
  FX_GLOB='*.ts'
  FX_SRC_FILE="services/worker.ts"
  FX_SUPPRESS_LINE='// eslint-disable-next-line import/no-mutable-exports'
}

fx_write_marker() { # <dir> <module>
  printf '{"name": "%s", "private": true}\n' "$2" > "$1/package.json"
}

fx_write_code() {
  mkdir -p "$REPO/services"
  cat > "$REPO/services/worker.ts" <<'TS'
// Polling worker.

// eslint-disable-next-line import/no-mutable-exports
export let cache: Map<string, string> = new Map()

// Polls until the deadline.
export async function run(deadline: number): Promise<void> {
  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
  await new Promise((resolve) => setTimeout(resolve, 50))
}
TS
  cat > "$REPO/services/worker.test.ts" <<'TS'
import { it } from 'vitest'

it('runs', async () => {
  await new Promise((resolve) => setTimeout(resolve, 10))
})
TS
}

fx_test_file() { printf '%s/m%s.test.ts' "$1" "$2"; }

fx_write_linter_config() {
  printf "export default [{\n  rules: {\n    'sonarjs/max-lines': ['error', { maximum: 400 }],\n  },\n}]\n" > "$REPO/eslint.config.mjs"
}

fx_write_linter_config_in_comment() {
  printf "export default [{\n  rules: {\n    /* 'sonarjs/max-lines': ['error', { maximum: 400 }],\n       'max-lines': ['error', 400], */\n    'no-console': 'error', // 'max-lines': ['error', 400]\n  },\n}]\n" > "$REPO/eslint.config.mjs"
}

# max-lines-per-function limits a function, not a file.
fx_write_linter_config_other() {
  printf "export default [{\n  rules: {\n    'max-lines-per-function': ['error', 50],\n    'sonarjs/max-lines-per-function': ['error', { maximum: 50 }],\n  },\n}]\n" > "$REPO/eslint.config.mjs"
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

# --- the bundle ldd-scope.sh writes, read by detection ---
SO="" # the scope bundle of the case: $BUNDLE/scope-out

begin "a code-only scoped diff skips the R9 gate's doc checks"
mk_repo; git_commit_repo
printf '\n' >> "$REPO/$FX_SRC_FILE"   # a code-only change
(cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change)
run_scope --base HEAD~1; SO="$BUNDLE/scope-out"
run_detect_bundle "$SO"
expect_exit 0 && expect_has "R9 gate: scoped, no doc in scope; doc checks skipped" \
  && COUNTS_FILE="$SO/counts.tsv" expect_count R9 1 0 && ok
finish

begin "a scoped diff that touches a doc gets that doc checked by the R9 gate"
mk_repo; git_commit_repo
printf '\n' >> "$REPO/$FX_SRC_FILE"   # a code-only change
printf '\nMore text.\n' >> "$REPO/docs/orphan.md"
(cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change)
run_scope --base HEAD~1; SO="$BUNDLE/scope-out"
expect_exit 0 && { grep -qx 'docs/orphan.md' "$SO/docs.txt" || bad "docs.txt lacks the touched doc"; } \
  && grep -qx 'docs/orphan.md' "$SO/docs.txt" \
  && { run_detect_bundle "$SO"; expect_exit 0; } \
  && expect_has "R9 gate: scoped, 1 doc(s) to check" \
  && COUNTS_FILE="$SO/counts.tsv" expect_count R9 1 1 \
  && { grep -q "^R9	1	gate	docs/orphan.md	" "$SO/hits.tsv" || bad "no R9 Q1 hit row for docs/orphan.md"; } \
  && grep -q "^R9	1	gate	docs/orphan.md	" "$SO/hits.tsv" && ok
finish

begin "detection reads the source glob from the bundle ldd-scope.sh wrote"
mk_repo; mkdir -p "$REPO/lib"; printf 'thing\n' > "$REPO/lib/thing.zz"; git_commit_repo
run_scope --glob '*.zz' lib/thing.zz; SO="$BUNDLE/scope-out"
run_detect_bundle "$SO"
expect_exit 0 && expect_has "over 1 source + 0 test files" && ok
finish

begin "a --glob that differs from the bundle's is a usage error (exit 2)"
mk_repo; mkdir -p "$REPO/lib"; printf 'thing\n' > "$REPO/lib/thing.zz"; git_commit_repo
run_scope --glob '*.zz' lib/thing.zz; SO="$BUNDLE/scope-out"
run_detect_bundle "$SO" --glob '*.yy'
expect_exit 2 && expect_has "differs from the bundle's glob" && ok
finish

begin "a scope whose files match no source glob is an error, not an all-zero table (exit 2)"
mk_repo; printf 'notes\n' > "$REPO/notes.txt"; printf 'notes.txt\n' > "$BUNDLE/files.txt"
printf 'custom\t*.zz\n' > "$BUNDLE/language.txt"
run_detect
expect_exit 2 && expect_has "0 source + 0 test files" && ok
finish

begin "--gate-budget stops a slow gate and its children; the gate questions are inconclusive"
mk_repo; : > "$BUNDLE/dirs.txt"
FAKE=$(mktemp -d)
cp "$DETECT" "$FAKE/ldd-detect.sh"
printf '#!/usr/bin/env bash\nsleep 37\necho never\n' > "$FAKE/check-repo-brain.sh"
t0=$SECONDS
OUT=$(cd "$REPO" && bash "$FAKE/ldd-detect.sh" --rules "$RULES" --gate-budget 1 --root . "$BUNDLE" 2>"$BUNDLE/.stderr"); CODE=$?
ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
took=$((SECONDS - t0))
expect_exit 0 && { (( took < 15 )) || bad "the run took ${took}s with a 1s gate budget"; } && (( took < 15 )) \
  && expect_has "R9 gate: inconclusive" && expect_count R9 1 inconclusive && expect_has "inconclusive" \
  && { ! pgrep -f 'sleep 37' >/dev/null || bad "the gate's child process outlived the budget"; } \
  && ! pgrep -f 'sleep 37' >/dev/null && ok
pkill -f 'sleep 37' 2>/dev/null
rm -rf "$FAKE"
finish

begin "a --gate-budget the gate finishes within writes the same counts as no budget"
mk_repo; : > "$BUNDLE/dirs.txt"; run_detect
cp "$BUNDLE/counts.tsv" "$BUNDLE/first.tsv"
run_detect --gate-budget 60
expect_exit 0 && { cmp -s "$BUNDLE/first.tsv" "$BUNDLE/counts.tsv" || bad "counts.tsv differs under a budget the gate meets"; } \
  && cmp -s "$BUNDLE/first.tsv" "$BUNDLE/counts.tsv" && ok
finish

begin "a gate that fails (exit 2) makes its questions inconclusive; the rest of the pass runs"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'echo "check-repo-brain: internal scanner error — the declaration scan failed" >&2; exit 2'
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 2): check-repo-brain: internal scanner error — the declaration scan failed" \
  && expect_count R10 5 2 && expect_count R5 1 '>=1' && ok
finish

begin "the gate's own error line names the failure, not a tool's line before it"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'echo "awk: cannot open docs/x" >&2; echo "check-repo-brain: internal scanner error — the doc scan failed in docs" >&2; exit 2'
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 2): check-repo-brain: internal scanner error — the doc scan failed in docs" && ok
finish

begin "a real gate that fails (CHECK_REPO_BRAIN_FAULT) makes its questions inconclusive"
mk_repo; : > "$BUNDLE/dirs.txt"
export CHECK_REPO_BRAIN_FAULT="a test"
run_detect
unset CHECK_REPO_BRAIN_FAULT
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 2): check-repo-brain: internal scanner error — CHECK_REPO_BRAIN_FAULT is set (a test)" \
  && expect_count R10 5 2 && ok
finish

begin "a gate that fails under --gate-budget makes its questions inconclusive"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'echo "check-repo-brain: internal scanner error" >&2; exit 2' --gate-budget 30
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 2): check-repo-brain: internal scanner error" \
  && expect_count R10 5 2 && ok
finish

begin "a gate that stops on an unbound variable (exit 1, no summary) makes its questions inconclusive"
mk_repo
run_stub_gate 'echo "check-repo-brain: scope — 1 doc(s) to check"; set -u; echo "$no_such_variable"; echo "check-repo-brain: clean"'
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 1): " \
  && expect_has "no_such_variable: unbound variable" && expect_not "R9 gate: scoped" && expect_count R10 5 2 && ok
finish

begin "a gate killed by a signal makes its questions inconclusive"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'kill -TERM $$'
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 143): no error message" && expect_count R10 5 2 && ok
finish

begin "a gate that exits 1 with no violation summary makes its questions inconclusive"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'echo "  [Q1] docs/orphan.md — half a report — see docs/conventions.md" >&2; exit 1'
expect_exit 0 && expect_gate_inconclusive "the gate failed (exit 1): no error message" && expect_count R10 5 2 && ok
finish

begin "a gate that exits 1 after its violation summary is a result, not a failure"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'echo "  [Q1] docs/orphan.md — orphan — see docs/conventions.md" >&2; echo "check-repo-brain: 1 violation(s) — rules: <docroot>/conventions.md" >&2; exit 1'
expect_exit 0 && expect_count R9 1 1 && expect_not "inconclusive" && ok
finish

begin "a question tag inside a path in a gate line is not a hit for that question"
mk_repo; : > "$BUNDLE/dirs.txt"
run_stub_gate 'echo "  advisory: docs/[Q2]release\nnotes.md — the path holds a newline; the gate does not check this file"
echo "  advisory: [Q3] AGENTS.md lacks the docs/index.md routing reference"
echo "  [Q1] docs/[Q7]old.md — orphan — see docs/conventions.md" >&2
echo "check-repo-brain: 1 violation(s) — rules: <docroot>/conventions.md" >&2; exit 1'
expect_exit 0 && expect_count R9 1 1 && expect_count R9 2 0 && expect_count R9 3 1 && expect_count R9 7 0 \
  && { grep -q "^R9	1	gate	docs/\[Q7\]old.md	" "$BUNDLE/hits.tsv" || bad "no R9 Q1 hit row for docs/[Q7]old.md"; } \
  && grep -q "^R9	1	gate	docs/\[Q7\]old.md	" "$BUNDLE/hits.tsv" && ok
finish

begin "a --gate-budget with no value is a usage error (exit 2)"
mk_repo
OUT=$(cd "$REPO" && bash "$DETECT" --root . "$BUNDLE" --gate-budget 2>&1); CODE=$?; ERR=""
expect_exit 2 && expect_has "--gate-budget needs a value" && ok
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

# run_bounded <args...> — runs the script with exactly these arguments and
# stops it after five seconds, so a regression that loops fails, never hangs
run_bounded() {
  local outf pid i; outf=$(mktemp)
  ( cd "$REPO" && exec bash "$DETECT" "$@" ) > "$outf" 2>&1 &
  pid=$!
  for (( i = 0; i < 50; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; CODE=124; else wait "$pid"; CODE=$?; fi
  OUT=$(cat "$outf"); ERR=""; rm -f "$outf"
}

ROW=""
for opt in --files --root --rules --cap --glob --test-re; do
  begin "$opt without its value is a usage error (exit 2)"
  run_bounded "$opt"
  expect_exit 2 && expect_has "$opt needs a value" && ok
  finish
done

# ========================= summary =========================
echo
echo "ldd-detect_test: $pass passed, $failed failed, $skipped skipped"
(( failed == 0 ))
