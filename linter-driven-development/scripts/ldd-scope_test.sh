#!/usr/bin/env bash
# Fixture matrix for ldd-scope.sh — the scope bundle's own conformance test.
# residue-exempt: the routing cases name the sibling plugins on purpose.
#
# Each case builds a throwaway repository under a temp dir, runs the script
# against it and asserts the exit code, the bundle written and the summary
# lines. The single-language cases run once per fixture row of this plugin's
# language block; the mixed-repository cases (D, Python and Go in one tree)
# run once, and say which plugin each language group must go to: this one, a
# sibling plugin installed for the language, or none. The scripts read the
# installed plugins from the file LDD_INSTALLED_PLUGINS names, so every case
# sets it — to an empty list, or to the siblings found beside this plugin in
# the repository checkout — and the user's own installed plugins never decide a
# case.
#
# Usage:  bash scripts/ldd-scope_test.sh [path/to/ldd-scope.sh]
#         (default: the sibling ldd-scope.sh)
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the script under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SCOPE_SH="${1:-$HERE/ldd-scope.sh}"
[[ -f "$SCOPE_SH" ]] || { echo "no such script: $SCOPE_SH" >&2; exit 2; }
SCOPE_SH=$(cd "$(dirname "$SCOPE_SH")" && pwd)/$(basename "$SCOPE_SH")
PLUGIN_DIR=$(cd "$(dirname "$SCOPE_SH")/.." && pwd)

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

run_scope() { # [args...] — runs ldd-scope.sh over $REPO into $BUNDLE/scope-out
  rm -rf "$BUNDLE/scope-out"
  OUT=$(cd "$REPO" && bash "$SCOPE_SH" --out "$BUNDLE/scope-out" "$@" 2>"$BUNDLE/.stderr"); CODE=$?
  ERR=$(cat "$BUNDLE/.stderr"); rm -f "$BUNDLE/.stderr"
}
git_commit_repo() { # commits everything under $REPO, quietly
  (cd "$REPO" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
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
expect_file_has() { # <file> <needle>
  grep -qF -- "$2" "$1" 2>/dev/null || { bad "$(basename "$1") lacks: $2"; return 1; }
}
expect_file_not() { # <file> <needle>
  grep -qF -- "$2" "$1" 2>/dev/null && { bad "$(basename "$1") has: $2"; return 1; }
  return 0
}
expect_flat() { # the bundle is one flat bundle of language <1>
  [[ ! -f "$BUNDLE/scope-out/groups.txt" ]] || { bad "groups.txt written for a single group reviewed here"; return 1; }
  [[ -f "$BUNDLE/scope-out/files.txt" ]] || { bad "no flat files.txt"; return 1; }
  [[ "$(head -1 "$BUNDLE/scope-out/language.txt" 2>/dev/null | cut -f1)" == "$1" ]] || { bad "language.txt is '$(cat "$BUNDLE/scope-out/language.txt" 2>/dev/null)', expected $1"; return 1; }
}
group_row() { # <id> — the group's row of groups.txt
  awk -F'\t' -v id="$1" '$1 == id' "$BUNDLE/scope-out/groups.txt" 2>/dev/null
}
expect_group() { # <id> <plugin|-> — the row names that reviewer and, when one, a bundle with files.txt
  local row; row=$(group_row "$1")
  [[ -n "$row" ]] || { bad "groups.txt has no $1 row: $(cat "$BUNDLE/scope-out/groups.txt" 2>/dev/null)"; return 1; }
  [[ "$(printf '%s' "$row" | cut -f2)" == "$2" ]] || { bad "$1 group reviewed by '$(printf '%s' "$row" | cut -f2)', expected $2: $row"; return 1; }
  if [[ "$2" != "-" ]]; then
    [[ -f "$BUNDLE/scope-out/$1/files.txt" ]] || { bad "$1 group has no bundle"; return 1; }
    [[ "$(printf '%s' "$row" | cut -f4)" == "$BUNDLE/scope-out/$1" ]] || { bad "$1 row names bundle '$(printf '%s' "$row" | cut -f4)'"; return 1; }
  fi
}

# ---------- fixture builders ----------
mk_docs() {
  mkdir -p "$REPO/docs"
  printf -- '---\nokf_version: "0.2"\n---\n# Map\n' > "$REPO/docs/index.md"
  printf '# Fixture\n\n@docs/index.md\n' > "$REPO/CLAUDE.md"
}
mk_repo() { fx_write_marker "$REPO" fixture; fx_write_code; mk_docs; }

# ---------- fixture rows: one per language the detected block supports ----------
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
FX_ROWS="go python"
FX_NATIVE="go python d typescript"

use_row() {
  case "$1" in
    go)
      FX_GLOB='*.go'
      FX_SRC_FILE="services/worker.go"
      FX_SUPPRESS_LINE='var cache = map[string]string{} //nolint:gochecknoglobals // TODO'
      ;;
    python)
      FX_GLOB='*.py'
      FX_SRC_FILE="services/worker.py"
      FX_SUPPRESS_LINE='CACHE: dict[str, str] = {}  # noqa: PLW0603'
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

# fx_comment_line — a one-line comment in the row's language, for added lines
fx_comment_line() { case "$FX_GLOB" in *.py) printf '# added by the test\n' ;; *) printf '// added by the test\n' ;; esac; }
# fx_ext — the row's source suffix, for files the cases create
fx_ext() { printf '%s' "${FX_GLOB#\*}"; }

# ========================= single-language cases =========================
run_row_cases() {

begin "a directory argument is expanded to the source files under it"
mk_repo; git_commit_repo; run_scope services
expect_exit 0 && expect_has "files bundled" && expect_flat "$ROW" \
  && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks $FX_SRC_FILE"; } \
  && grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" && ok
finish

begin "a committed file named on a clean tree contributes every comment line"
mk_repo; git_commit_repo; run_scope "$FX_SRC_FILE"
expect_exit 0 && expect_has "diff 0 lines" \
  && { grep -q "^$FX_SRC_FILE:[0-9]*:" "$BUNDLE/scope-out/comments.txt" || bad "comments.txt has no line of $FX_SRC_FILE"; } \
  && grep -q "^$FX_SRC_FILE:[0-9]*:" "$BUNDLE/scope-out/comments.txt" && ok
finish

begin "a comment line carries the code line below it"
mk_repo; git_commit_repo; run_scope "$FX_SRC_FILE"
expect_exit 0 && { grep -q " ⏎ " "$BUNDLE/scope-out/comments.txt" || bad "no code line after a comment in comments.txt"; } \
  && grep -q " ⏎ " "$BUNDLE/scope-out/comments.txt" && ok
finish

begin "an empty explicit scope prints nothing to review"
mk_repo; git_commit_repo; mkdir -p "$REPO/empty"; run_scope empty
expect_exit 0 && expect_has "nothing to review" && ok
finish

begin "a rung of files with no source extension prints nothing to review and names the extensions"
mk_repo; git_commit_repo
printf 'x: 1\n' > "$REPO/services/config.yaml"
run_scope services/config.yaml
expect_exit 0 && expect_has "nothing to review" && expect_has ".yaml" && expect_has "--glob" && ok
finish

begin "--base diffs the branch against its base and keeps only the added comment lines"
mk_repo; git_commit_repo
fx_comment_line >> "$REPO/$FX_SRC_FILE"
(cd "$REPO" && git -c user.name=t -c user.email=t@t commit -qam change)
run_scope --base HEAD~1
expect_exit 0 && expect_flat "$ROW" && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the changed file"; } \
  && { [[ -s "$BUNDLE/scope-out/diff.patch" ]] || bad "diff.patch is empty on --base"; } \
  && { (( $(wc -l < "$BUNDLE/scope-out/comments.txt") == 1 )) || bad "comments.txt should carry the one added comment line, has $(wc -l < "$BUNDLE/scope-out/comments.txt")"; } \
  && grep -q "added by the test" "$BUNDLE/scope-out/comments.txt" && ok
finish

begin "the worktree rung takes changed and untracked files, every comment line of the untracked one"
mk_repo; git_commit_repo
fx_comment_line >> "$REPO/$FX_SRC_FILE"
{ fx_comment_line; fx_comment_line; } > "$REPO/services/fresh$(fx_ext)"
run_scope
expect_exit 0 && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the changed file"; } \
  && { grep -qx "services/fresh$(fx_ext)" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the untracked file"; } \
  && { (( $(grep -c "^services/fresh" "$BUNDLE/scope-out/comments.txt") == 2 )) || bad "the untracked file's two comment lines are not both in comments.txt"; } \
  && (( $(grep -c "^$FX_SRC_FILE:" "$BUNDLE/scope-out/comments.txt") == 1 )) && ok
finish

begin "--all writes dirs.txt with a file and line count per directory"
mk_repo; git_commit_repo; run_scope --all
expect_exit 0 && { [[ -f "$BUNDLE/scope-out/dirs.txt" ]] || bad "no dirs.txt on --all"; } \
  && { grep -qE "^services	[0-9]+	[0-9]+$" "$BUNDLE/scope-out/dirs.txt" || bad "dirs.txt has no 'services TAB files TAB lines' row: $(cat "$BUNDLE/scope-out/dirs.txt")"; } \
  && { (( $(awk -F'\t' '{ n += $2 } END { print n + 0 }' "$BUNDLE/scope-out/dirs.txt") == 2 )) || bad "dirs.txt file counts do not sum to the 2 bundled files"; } \
  && { [[ ! -f "$BUNDLE/scope-out/diff.patch" ]] || bad "--all wrote a diff.patch"; } && ok
finish

begin "a deleted, a binary, an over-long and a generated file are listed, not bundled"
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

begin "--out refuses a directory that is not empty (exit 2)"
mk_repo; git_commit_repo
mkdir -p "$BUNDLE/scope-out"; : > "$BUNDLE/scope-out/stale"
OUT=$(cd "$REPO" && bash "$SCOPE_SH" --out "$BUNDLE/scope-out" "$FX_SRC_FILE" 2>&1); CODE=$?; ERR=""
expect_exit 2 && expect_has "empty" && ok
finish

begin "--glob reviews the matching files as one group of an unknown language"
mk_repo; git_commit_repo
printf '// a zig comment\nconst x = 1;\n' > "$REPO/services/main.zig"
run_scope --glob '*.zig' services
expect_exit 0 && expect_flat "custom" && expect_has "1 files bundled" \
  && { grep -qx "services/main.zig" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the .zig file"; } \
  && { ! grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/files.txt" || bad "files.txt has the row's file beside the --glob files"; } \
  && expect_file_has "$BUNDLE/scope-out/language.txt" "*.zig" && ok
finish

begin "a single-language repository writes one flat bundle, every sibling plugin installed or not"
mk_repo; git_commit_repo
if [[ -z "$SIBLINGS" ]]; then skip "no sibling plugin beside $PLUGIN_DIR"; finish; return; fi
with_siblings; run_scope --all
if [[ "linter-driven-development" == "$ROW-linter-driven-development" ]] || ! have_sibling "$ROW-linter-driven-development"; then
  expect_exit 0 && expect_flat "$ROW" && expect_has "files bundled" && ok
else
  expect_exit 0 && expect_group "$ROW" "$ROW-linter-driven-development" && expect_has "1 language groups" \
    && { grep -qx "$FX_SRC_FILE" "$BUNDLE/scope-out/$ROW/files.txt" || bad "the routed bundle lacks $FX_SRC_FILE"; } && ok
fi
finish

} # run_row_cases

write_installed_plugins "$SIBLINGS_FILE" go-linter-driven-development python-linter-driven-development linter-driven-development ts-react-linter-driven-development

for ROW in $FX_ROWS; do
  use_row "$ROW"
  run_row_cases
done
ROW=""

# ========================= the mixed repository =========================
# expect_reviewer <id> — which plugin the scripts must send the group to, from
# this plugin's own rows (FX_NATIVE) and the installed siblings: a plugin
# written for the language when installed, else this plugin when it has the
# row, else the plugin for any language when installed, else nobody ("-").
is_native() { case " $FX_NATIVE " in *" $1 "*) return 0 ;; esac; return 1; }
expect_reviewer() {
  local ded=""
  case "$1" in go|python) ded="$1-linter-driven-development" ;; typescript) ded="ts-react-linter-driven-development" ;; esac
  if [[ -n "$ded" && "$ded" != "linter-driven-development" ]] && [[ "$LDD_INSTALLED_PLUGINS" == "$SIBLINGS_FILE" ]] && have_sibling "$ded"; then printf '%s' "$ded"; return; fi
  if is_native "$1"; then printf '%s' "linter-driven-development"; return; fi
  if [[ "linter-driven-development" != linter-driven-development ]] && [[ "$LDD_INSTALLED_PLUGINS" == "$SIBLINGS_FILE" ]] && have_sibling linter-driven-development; then printf 'linter-driven-development'; return; fi
  printf -- '-'
}
# check_mixed_groups — the three groups of the mixed diff, each with its own
# files, diff and comment lines, or excluded with every file named
check_mixed_groups() {
  local id who n_bundled=0
  (( $(grep -c . "$BUNDLE/scope-out/groups.txt") == 4 )) || { bad "groups.txt should have 4 rows: $(cat "$BUNDLE/scope-out/groups.txt")"; return 1; }
  [[ "$(cut -f1 "$BUNDLE/scope-out/groups.txt" | tr '\n' ' ')" == "d go python typescript " ]] || { bad "groups are not d, go, python, typescript in order"; return 1; }
  for id in d go python typescript; do
    who=$(expect_reviewer "$id")
    expect_group "$id" "$who" || return 1
    case "$id" in d) f="$MIXED_D"; c="added d comment" ;; go) f="$MIXED_GO"; c="added go comment" ;; python) f="$MIXED_PY"; c="added py comment" ;; typescript) f="$MIXED_TS"; c="added ts comment" ;; esac
    if [[ "$who" == "-" ]]; then
      expect_has "$f: no language block matched (.${f##*.})" || return 1
      continue
    fi
    n_bundled=$((n_bundled + 1))
    local b="$BUNDLE/scope-out/$id"
    [[ "$(cat "$b/files.txt")" == "$f" ]] || { bad "$id files.txt should hold only $f: $(cat "$b/files.txt")"; return 1; }
    [[ "$(head -1 "$b/language.txt")" == "$id" ]] || { bad "$id language.txt is $(cat "$b/language.txt")"; return 1; }
    expect_file_has "$b/diff.patch" "+++ b/$f" || return 1
    { grep -c '^+++ ' "$b/diff.patch" | grep -qx 1; } || { bad "$id diff.patch touches more than its own file"; return 1; }
    expect_file_has "$b/comments.txt" "$c" || return 1
    [[ "$(grep -c . "$b/comments.txt")" == 1 ]] || { bad "$id comments.txt should carry one added comment: $(cat "$b/comments.txt")"; return 1; }
  done
  expect_not "BUILD.bazel" || return 1
  expect_has "4 language groups (d, go, python, typescript)" || return 1
  if (( n_bundled > 0 )); then expect_exit 0; else expect_exit 1; fi
}

begin "mixed repository: the diff is split by language, one bundle per group, no sibling installed"
mk_mixed_repo; mixed_change; run_scope --base HEAD~1
check_mixed_groups && ok
finish

begin "mixed repository: each group goes to the plugin installed for its language"
mk_mixed_repo; mixed_change
if [[ -z "$SIBLINGS" ]]; then skip "no sibling plugin beside $PLUGIN_DIR"; finish
else
  with_siblings; run_scope --base HEAD~1
  check_mixed_groups && ok
  finish
fi

begin "mixed repository: a D-only diff is never nothing to review"
mk_mixed_repo; mixed_change_d; run_scope --base HEAD~1
if is_native d; then
  expect_exit 0 && expect_not "nothing to review" && expect_flat d && expect_has "1 files bundled" \
    && expect_file_has "$BUNDLE/scope-out/comments.txt" "added d comment" && ok
else
  expect_exit 1 && expect_not "nothing to review" && expect_has "$MIXED_D: no language block matched (.d)" \
    && expect_has "1 files excluded" && { [[ ! -d "$BUNDLE/scope-out/d" ]] || bad "an excluded group left a bundle"; } && ok
fi
finish

begin "mixed repository: a D-only diff goes to the plugin for any language when this one has no D row"
mk_mixed_repo; mixed_change_d
if is_native d; then skip "this plugin has its own D row"; finish
elif ! have_sibling linter-driven-development; then skip "no linter-driven-development beside $PLUGIN_DIR"; finish
else
  with_siblings; run_scope --base HEAD~1
  expect_exit 0 && expect_group d linter-driven-development && expect_has "1 language groups (d)" \
    && expect_file_has "$BUNDLE/scope-out/d/comments.txt" "added d comment" && ok
  finish
fi

begin "mixed repository: a directory argument takes every language under it"
mk_mixed_repo; run_scope weka
if is_native d; then
  expect_exit 0 && expect_flat d && expect_has "2 files bundled" \
    && { grep -qx "$MIXED_D_TEST" "$BUNDLE/scope-out/files.txt" || bad "files.txt lacks the D test file"; } && ok
else
  expect_exit 1 && expect_has "$MIXED_D_TEST: no language block matched (.d)" && ok
fi
finish

begin "mixed repository: --all splits the repository into its four languages"
mk_mixed_repo; run_scope --all
check_all() {
  local id who
  (( $(grep -c . "$BUNDLE/scope-out/groups.txt") == 4 )) || { bad "groups.txt should have 4 rows"; return 1; }
  for id in d go python typescript; do
    who=$(expect_reviewer "$id")
    expect_group "$id" "$who" || return 1
    [[ "$who" == "-" ]] && continue
    [[ -f "$BUNDLE/scope-out/$id/dirs.txt" ]] || { bad "$id bundle has no dirs.txt on --all"; return 1; }
    (( $(grep -c . "$BUNDLE/scope-out/$id/files.txt") == 2 )) || { bad "$id bundle should hold 2 files: $(cat "$BUNDLE/scope-out/$id/files.txt")"; return 1; }
  done
}
check_all && ok
finish

begin "--lang keeps one group of the split, reviewed here"
mk_mixed_repo; mixed_change
first=$(printf '%s\n' $FX_NATIVE | head -1)
run_scope --lang "$first" --base HEAD~1
expect_exit 0 && expect_flat "$first" && expect_has "1 files bundled" && ok
finish

begin "--lang refuses a language this plugin has no row for (exit 2)"
mk_mixed_repo; mixed_change
other=""; for id in d go python typescript; do is_native "$id" || { other="$id"; break; }; done
if [[ -z "$other" ]]; then skip "this plugin has a row for every language of the mixed repository"; finish
else
  run_scope --lang "$other" --base HEAD~1
  expect_exit 2 && expect_has "no language block for $other" && ok
  finish
fi

begin "--glob overrides the split: the matching files are the one group"
mk_mixed_repo; mixed_change; run_scope --glob '*.d' --base HEAD~1
expect_exit 0 && expect_flat custom && expect_has "1 files bundled" \
  && [[ "$(cat "$BUNDLE/scope-out/files.txt")" == "$MIXED_D" ]] && ok
finish

# ========================= summary =========================
echo
echo "ldd-scope_test: $pass passed, $failed failed, $skipped skipped"
(( failed == 0 ))
