#!/usr/bin/env bash
# Fixture matrix for ldd-lint.sh — the gap linter's own conformance test.
#
# Each case builds a throwaway tree under a temp dir, runs the script against
# it and asserts the exit code and the lines it prints. The cases are the same
# for every language; the language-specific parts — the source suffix, how a
# comment and a test file are written, the file a directory count leaves out,
# and the repository linter config that holds a file-length limit — come from
# the fixture rows spliced in below. A script whose language block serves
# several languages runs the whole matrix once per row.
#
# Usage:  bash scripts/ldd-lint_test.sh [path/to/ldd-lint.sh]
#         (default: the sibling ldd-lint.sh)
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the script under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
LINT="${1:-$HERE/ldd-lint.sh}"
[[ -f "$LINT" ]] || { echo "no such script: $LINT" >&2; exit 2; }
LINT=$(cd "$(dirname "$LINT")" && pwd)/$(basename "$LINT")
MAX_LINES=450
WARN_FILES=8
MAX_FILES=13

pass=0 failed=0 skipped=0
CASE=""
OUT="" ERR="" CODE=0
ROW=""
REPO=""
TAB=$(printf '\t')

# ---------- harness ----------
begin() { CASE="$1"; [[ -n "$ROW" ]] && CASE="[$ROW] $1"; REPO=$(mktemp -d); }
finish() { rm -rf "$REPO"; }

run_lint() { # <subcommand> [options...] — runs the script over $REPO
  local errf; errf=$(mktemp)
  OUT=$(cd "$REPO" && bash "$LINT" "$@" --root . 2>"$errf"); CODE=$?
  ERR=$(cat "$errf"); rm -f "$errf"
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
expect_no_finding() { # no line names a file or directory of the tree
  printf '%s\n' "$OUT" | grep -qE '^[^ ]+: [0-9]+ ' && { bad "unexpected finding"; return 1; }
  return 0
}

# ---------- fixture builders ----------
# write_src <path> <code> [<comments> [<blanks> [<block lines>]]] — a source
# file with that many code lines, comment-only lines, blank lines and lines of
# one block comment, in that order.
write_src() {
  local path="$REPO/$1" code="$2" com="${3:-0}" blank="${4:-0}" block="${5:-0}" i
  mkdir -p "$(dirname "$path")"
  {
    for (( i = 1; i <= code; i++ )); do printf 'v%d = %d\n' "$i" "$i"; done
    for (( i = 1; i <= com; i++ )); do printf '%s\n' "$FX_LINE_COMMENT"; done
    for (( i = 1; i <= blank; i++ )); do printf '\n'; done
    if (( block > 0 )); then
      printf '%s\n' "$FX_BLOCK_OPEN"
      for (( i = 3; i <= block; i++ )); do printf '   inside the block\n'; done
      printf '%s\n' "$FX_BLOCK_CLOSE"
    fi
  } > "$path"
}

# fill_dir <dir> <sources> [<tests>] — that many one-line source and test files
fill_dir() {
  local i
  for (( i = 1; i <= $2; i++ )); do write_src "$1/m$i$FX_EXT" 1; done
  for (( i = 1; i <= ${3:-0}; i++ )); do write_src "$(fx_test_file "$1" "$i")" 1; done
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
FX_ROWS="go"
FX_NATIVE="go"

use_row() {
  FX_LINTER_CONFIG='.golangci.yaml'
  FX_SETUP_FILE='golangci.yaml'
  FX_ROUTED_FILE='golangci.yaml'
  FX_RULE_ID_RE='^[a-z][a-z0-9-]*$'
  # cyclop is the alternative to gocyclo; package-size is the gap linter's
  FX_ROUTED_SKIP='cyclop package-size'
  FX_LENGTH_RULE='file-length-limit'
  FX_LINTER_COMMENT='#'
  FX_EXT='.go'
  FX_LINE_COMMENT='// note'
  FX_BLOCK_OPEN='/*'
  FX_BLOCK_CLOSE='*/'
  FX_SKIP_FILES='api.pb.go store_gen.go'
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

fx_test_file() { printf '%s/m%s_test.go' "$1" "$2"; }

fx_write_linter_config() {
  printf 'version: "2"\nlinters:\n  settings:\n    revive:\n      rules:\n        - name: file-length-limit\n          arguments: [{max: 400}]\n' > "$REPO/.golangci.yaml"
}

fx_write_linter_config_in_comment() {
  printf 'version: "2" # consider file-length-limit\nlinters:\n  default: standard # "#" in a string: file-length-limit\n' > "$REPO/.golangci.yaml"
}

fx_write_linter_config_other() {
  printf 'version: "2"\nlinters:\n  settings:\n    revive:\n      rules:\n        - name: argument-limit\n          arguments: [4]\n' > "$REPO/.golangci.yaml"
}

# ==================== linter table ====================
# What the gap linter needs to know per language id: how a comment is written,
# which source files a directory count leaves out, and whether the
# repository's own linter holds the file-length limit. The same table is
# rendered into every plugin, so two plugins measure one file the same way.
# residue-exempt: the table names every language's linter and config file on
# purpose, the same in every rendering.
#
#   lint_comment_style <id>         c (// and /* */), d (also /+ +/) or hash (#)
#   lint_strip_comments <style> <file>  the file with every comment removed and
#                                   string literals kept, one output line per
#                                   input line: a comment-only line prints empty.
#                                   Styles: c, d, hash (# and triple-quoted
#                                   strings), ini (# and a leading ;)
#   lint_package_skip_re <id>       ERE over a relative path: source files a
#                                   directory count leaves out (an index module,
#                                   a package marker, generated stubs); "" for none
#   lint_file_length_rule <id>      "<rule> in <config file>" when a linter config
#                                   at the repository root names a file-length
#                                   rule outside a comment, else
#                                   nothing. A named rule belongs to the linter:
#                                   its limit, its counting and whether it is on
#                                   are the repository's decision.
#   lint_setup_files                one line per recommended config under the
#                                   plugin's setup/: file TAB the tool that checks it
#   lint_setup_check <file> <setup dir> <work dir>  run that tool's own check of
#                                   the file; exit 0 when the tool accepts it
#   lint_file_length_proposal <id>  what would hold the limit in the
#                                   repository's linter: the rule, named after
#                                   the plugin's recommended config under setup/
#                                   that sets it, or the .ldd-lint.yaml entry when
#                                   the language's linter has no such rule

lint_comment_style() {
  case "$1" in
    python|ruby|shell) printf 'hash' ;;
    d)                 printf 'd' ;;
    *)                 printf 'c' ;;
  esac
}

lint_package_skip_re() {
  case "$1" in
    go)                    printf '%s' '(_gen|\.pb)\.go$' ;;
    python)                printf '%s' '(^|/)(__init__|conftest)\.py$|_pb2(_grpc)?\.py$' ;;
    typescript|javascript) printf '%s' '(^|/)index\.[cm]?[jt]sx?$|\.stories\.[cm]?[jt]sx?$' ;;
  esac
  return 0
}

# LINT_STRIP_AWK walks each line one character at a time. A quote opens a
# string that a comment marker cannot end; single and double quotes close at
# the end of the line, a backtick string (c and d) and a triple-quoted string
# (hash) run on. A block comment may open after code and run on. The awk uses
# substr and string compares only, so mawk, gawk and BSD awk read it alike.
LINT_STRIP_AWK='
BEGIN { bq = sprintf("%c", 96); sq = sprintf("%c", 39); dq = "\"" }
{
  line = $0; out = ""; n = length(line); i = 1
  if (q == dq || q == sq) q = ""
  while (i <= n) {
    if (inblock) {
      if (substr(line, i, length(closer)) == closer) { inblock = 0; i += length(closer); out = out " "; continue }
      i++; continue
    }
    ch = substr(line, i, 1)
    if (q != "") {
      if (ch == "\\" && (q == dq || q == sq)) { out = out substr(line, i, 2); i += 2; continue }
      if (substr(line, i, length(q)) == q) { out = out q; i += length(q); q = ""; continue }
      out = out ch; i++; continue
    }
    if (style == "hash" || style == "ini") {
      if (ch == "#") break
      if (style == "ini" && ch == ";" && out ~ /^[ \t]*$/) break
      three = substr(line, i, 3)
      if (style == "hash" && (three == dq dq dq || three == sq sq sq)) { q = three; out = out three; i += 3; continue }
    } else {
      two = substr(line, i, 2)
      if (two == "//") break
      if (two == "/*" || (style == "d" && two == "/+")) { inblock = 1; closer = (two == "/+") ? "+/" : "*/"; out = out " "; i += 2; continue }
      if (ch == bq) { q = bq; out = out ch; i++; continue }
    }
    if (ch == dq || ch == sq) { q = ch; out = out ch; i++; continue }
    out = out ch; i++
  }
  print out
}
'

lint_strip_comments() { # <style> <file>
  awk -v style="$1" "$LINT_STRIP_AWK" "$2"
}

# _lint_config_style <config file> — how that config format writes a comment
_lint_config_style() {
  case "$1" in
    *.yaml|*.yml|*.toml) printf 'hash' ;;
    *.cfg|*.ini|.pylintrc|pylintrc) printf 'ini' ;;
    *) printf 'c' ;;
  esac
}

# _lint_names <ERE> <file>... — print the first file whose text outside its
# comments matches the pattern
_lint_names() {
  local re="$1" f; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    lint_strip_comments "$(_lint_config_style "$f")" "./$f" 2>/dev/null | grep -qE -- "$re" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

lint_file_length_rule() {
  local f
  case "$1" in
    go)
      f=$(_lint_names 'file-length-limit' .golangci.yaml .golangci.yml .golangci.toml .golangci.json) \
        && printf 'revive file-length-limit in %s' "$f" ;;
    typescript|javascript)
      local configs=(eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts
                     .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml)
      if f=$(_lint_names 'sonarjs/max-lines([^-a-zA-Z]|$)' "${configs[@]}"); then
        printf 'sonarjs/max-lines in %s' "$f"
      elif f=$(_lint_names '(^|[^-/a-zA-Z])max-lines([^-a-zA-Z]|$)' "${configs[@]}"); then
        printf 'max-lines in %s' "$f"
      fi ;;
    python)
      f=$(_lint_names '^[[:space:]]*max-module-lines[[:space:]]*=' pyproject.toml .pylintrc pylintrc setup.cfg tox.ini) \
        && printf 'pylint max-module-lines in %s' "$f" ;;
  esac
  return 0
}

lint_setup_files() {
  printf 'golangci.yaml\tgolangci-lint\n'
  printf 'ruff.toml\truff\n'
  printf 'eslint.config.ldd.mjs\tnode\n'
}

lint_setup_check() { # <file> <setup dir> <work dir>
  case "$1" in
    golangci.yaml)         golangci-lint config verify -c "$2/$1" ;;
    ruff.toml)             printf 'x = 1\n' > "$3/ldd_setup_check.py" && (cd "$3" && ruff check --no-cache --config "$2/$1" ldd_setup_check.py) ;;
    eslint.config.ldd.mjs) node --check "$2/$1" ;;
    *)                     return 2 ;;
  esac
}

lint_file_length_proposal() {
  case "$1" in
    go)                    printf "a setting to propose, never to add on your own: revive file-length-limit, as the plugin's setup/golangci.yaml sets it" ;;
    typescript|javascript) printf "a setting to propose, never to add on your own: sonarjs/max-lines, as the plugin's setup/eslint.config.ldd.mjs sets it" ;;
    python)                printf "ruff has no file-length rule, so this script holds the limit; a .ldd-lint.yaml entry file_max_lines: <n> states another" ;;
    *)                     printf "no linter rule is known for %s; a .ldd-lint.yaml entry file_max_lines: <n> states another limit" "$1" ;;
  esac
}
# ================== end linter table ==================

# ========================= cases =========================
run_row_cases() { # runs every case against the current row

begin "a file at the limit passes and one line over is a finding"
write_src "src/at$FX_EXT" "$MAX_LINES"; write_src "src/over$FX_EXT" $((MAX_LINES + 1))
run_lint file-length
expect_exit 0 && expect_has "src/over$FX_EXT: $((MAX_LINES + 1)) code lines (limit $MAX_LINES, profile default)" \
  && expect_not "src/at$FX_EXT:" && ok
finish

begin "comment-only and blank lines are not counted by the plugin's default"
write_src "src/long$FX_EXT" $((MAX_LINES - 10)) 20 20
run_lint file-length
expect_exit 0 && expect_no_finding && ok
finish

begin "the lines of a block comment are comment-only"
if [[ -z "$FX_BLOCK_OPEN" ]]; then skip "the language has no block comment"; finish
else
  write_src "src/long$FX_EXT" $((MAX_LINES - 10)) 0 0 30
  run_lint file-length
  expect_exit 0 && expect_no_finding && ok
  finish
fi

begin "a block comment opened after code ends the code on that line"
if [[ -z "$FX_BLOCK_OPEN" ]]; then skip "the language has no block comment"; finish
else
  mkdir -p "$REPO/src"
  { printf 'v0 = 1 %s note\n' "$FX_BLOCK_OPEN"; for (( i = 1; i <= 40; i++ )); do printf '   inside the block\n'; done
    printf '%s\n' "$FX_BLOCK_CLOSE"; for (( i = 1; i <= MAX_LINES - 1; i++ )); do printf 'v%d = %d\n' "$i" "$i"; done; } > "$REPO/src/a$FX_EXT"
  run_lint file-length
  expect_exit 0 && expect_no_finding && ok
  finish
fi

begin "a comment marker inside a string literal is code"
mkdir -p "$REPO/src"
for (( i = 1; i <= MAX_LINES + 1; i++ )); do printf 's%d = "a//b#c/*d"\n' "$i"; done > "$REPO/src/a$FX_EXT"
run_lint file-length
expect_exit 0 && expect_has "src/a$FX_EXT: $((MAX_LINES + 1)) code lines" && ok
finish

begin "a test file over the limit is not measured"
write_src "$(fx_test_file src 1)" $((MAX_LINES + 50))
run_lint file-length
expect_exit 0 && expect_no_finding && ok
finish

begin "a generated file over the limit is not measured"
write_src "src/gen$FX_EXT" $((MAX_LINES + 50))
{ printf '%s DO NOT EDIT\n' "$FX_LINE_COMMENT"; cat "$REPO/src/gen$FX_EXT"; } > "$REPO/src/gen.tmp" && mv "$REPO/src/gen.tmp" "$REPO/src/gen$FX_EXT"
run_lint file-length
expect_exit 0 && expect_no_finding && ok
finish

begin "the plugin's default names a linter setting to propose, never to add"
write_src "src/a$FX_EXT" 1
run_lint file-length
SETUP_DIR="$(dirname "$LINT")/../setup"
if [[ -n "$FX_SETUP_FILE" ]]; then
  expect_exit 0 && expect_has "profile default ($MAX_LINES code lines)" \
    && expect_has "a setting to propose, never to add on your own: " \
    && expect_has "$FX_LENGTH_RULE, as the plugin's setup/$FX_SETUP_FILE sets it" \
    && { grep -q -- "$FX_LENGTH_RULE" "$SETUP_DIR/$FX_SETUP_FILE" && grep -q -- "$MAX_LINES" "$SETUP_DIR/$FX_SETUP_FILE" || bad "setup/$FX_SETUP_FILE does not set $FX_LENGTH_RULE at $MAX_LINES"; } \
    && grep -q -- "$FX_LENGTH_RULE" "$SETUP_DIR/$FX_SETUP_FILE" && ok
else
  expect_exit 0 && expect_has "profile default ($MAX_LINES code lines)" && expect_has "a .ldd-lint.yaml entry file_max_lines" && ok
fi
finish

begin "a file-length rule in the linter config hands file length to the linter"
fx_write_linter_config
write_src "src/over$FX_EXT" $((MAX_LINES + 50))
run_lint file-length
expect_exit 0 && expect_has "held by " && expect_no_finding && ok
finish

begin "a similar rule of another name leaves file length to the gap linter"
fx_write_linter_config_other
write_src "src/over$FX_EXT" $((MAX_LINES + 1))
run_lint file-length
expect_exit 0 && expect_not "held by " && expect_has "src/over$FX_EXT: $((MAX_LINES + 1)) code lines" && ok
finish

begin "a file-length rule that is commented out leaves file length to the gap linter"
fx_write_linter_config
sed "s|^|$FX_LINTER_COMMENT |" "$REPO/$FX_LINTER_CONFIG" > "$REPO/cfg.tmp" && mv "$REPO/cfg.tmp" "$REPO/$FX_LINTER_CONFIG"
write_src "src/over$FX_EXT" $((MAX_LINES + 1))
run_lint file-length
expect_exit 0 && expect_not "held by " && expect_has "src/over$FX_EXT: $((MAX_LINES + 1)) code lines" && ok
finish

begin "a file-length rule named only inside comments leaves file length to the gap linter"
fx_write_linter_config_in_comment
write_src "src/over$FX_EXT" $((MAX_LINES + 1))
run_lint file-length
expect_exit 0 && expect_not "held by " && expect_has "src/over$FX_EXT: $((MAX_LINES + 1)) code lines" && ok
finish

begin "the recommended config enables every rule the routing table routes to a design rule"
if [[ -z "$FX_ROUTED_FILE" ]]; then skip "this plugin's routing table names no linter rule"; finish
else
  table=$(grep -l '^| Linter failure | Route |' "$(dirname "$LINT")"/../skills/refactoring/*.md | head -1)
  missing=""; checked=0
  while IFS= read -r id; do
    case " $FX_ROUTED_SKIP " in *" $id "*) continue ;; esac
    checked=$((checked + 1))
    case "$id" in
      *'*') re="(^|[^A-Za-z0-9/@-])${id%\*}" ;;
      *)    re="(^|[^A-Za-z0-9/@-])${id}([^A-Za-z0-9/-]|\$)" ;;
    esac
    grep -qE -- "$re" "$(dirname "$LINT")/../setup/$FX_ROUTED_FILE" || missing="$missing $id"
  done < <(awk -F'|' '
      /^\| Linter failure \| Route \|/ { t = 1; next }
      t && /^\|---/ { next }
      t && /^\|/ { if ($3 ~ /rules\/R/) { c = $2; while (match(c, /`[^`]+`/)) { print substr(c, RSTART + 1, RLENGTH - 2); c = substr(c, RSTART + RLENGTH) } } next }
      t { t = 0 }' "$table" | grep -E -- "$FX_RULE_ID_RE" | LC_ALL=C sort -u)
  { [[ -n "$table" ]] && (( checked > 0 )) || bad "no routed rule id found in the routing table"; } \
    && { [[ -z "$missing" ]] || bad "setup/$FX_ROUTED_FILE lacks:$missing"; } && [[ -z "$missing" ]] && ok
  finish
fi

begin ".ldd-lint.yaml sets the limit when the linter holds none"
printf 'file_max_lines: 100  # this repository\n' > "$REPO/.ldd-lint.yaml"
write_src "src/a$FX_EXT" 101
run_lint file-length
expect_exit 0 && expect_has "set by .ldd-lint.yaml" && expect_has "src/a$FX_EXT: 101 code lines (limit 100, .ldd-lint.yaml)" && ok
finish

begin "a .ldd-lint.yaml value that is not a positive integer is inconclusive (exit 2)"
printf 'file_max_lines: lots\n' > "$REPO/.ldd-lint.yaml"
write_src "src/a$FX_EXT" 1
run_lint file-length
expect_exit 2 && expect_has "file_max_lines must be a positive integer" && ok
finish

begin "a directory below the warning size is not a finding"
fill_dir pkg $((WARN_FILES - 1)) 3
for f in $FX_SKIP_FILES; do write_src "pkg/$f" 1; done
run_lint package-size
expect_exit 0 && expect_no_finding && ok
finish

begin "a directory at the warning size is a warning"
fill_dir pkg "$WARN_FILES"
run_lint package-size
expect_exit 0 && expect_has "pkg: $WARN_FILES source files (warning at $WARN_FILES, profile default)" && ok
finish

begin "a directory at the limit is over the limit"
fill_dir pkg "$MAX_FILES"
run_lint package-size
expect_exit 0 && expect_has "pkg: $MAX_FILES source files (limit $MAX_FILES, profile default)" && ok
finish

begin ".ldd-lint.yaml sets the directory sizes"
printf 'package_warn_files: 2\npackage_max_files: 3\n' > "$REPO/.ldd-lint.yaml"
fill_dir small 2; fill_dir big 3
run_lint package-size
expect_exit 0 && expect_has "small: 2 source files (warning at 2, .ldd-lint.yaml)" \
  && expect_has "big: 3 source files (limit 3, .ldd-lint.yaml)" && ok
finish

begin "--tsv writes path, line 0 and message as rows, and the threshold to stderr"
write_src "src/over$FX_EXT" $((MAX_LINES + 1))
run_lint file-length --tsv
expect_exit 0 \
  && { [[ "$OUT" == "src/over$FX_EXT${TAB}0${TAB}$((MAX_LINES + 1)) code lines (limit $MAX_LINES, profile default)" ]] || bad "stdout is not the one row"; } \
  && [[ "$OUT" == "src/over$FX_EXT${TAB}0${TAB}"* ]] \
  && { [[ "$ERR" == "threshold: "* ]] || bad "threshold line not on stderr"; } && [[ "$ERR" == "threshold: "* ]] && ok
finish

begin "--files measures only the files it names"
write_src "src/named$FX_EXT" $((MAX_LINES + 1)); write_src "src/other$FX_EXT" $((MAX_LINES + 1))
printf 'src/named%s (not bundled: %s lines)\n' "$FX_EXT" $((MAX_LINES + 1)) > "$REPO/files.txt"
run_lint file-length --files files.txt
expect_exit 0 && expect_has "src/named$FX_EXT:" && expect_not "src/other$FX_EXT:" && ok
finish

begin "in a git repository an ignored file is not measured"
write_src "src/kept$FX_EXT" $((MAX_LINES + 1)); write_src "build/out$FX_EXT" $((MAX_LINES + 1))
printf 'build/\n' > "$REPO/.gitignore"
(cd "$REPO" && git init -q)
run_lint file-length
expect_exit 0 && expect_has "src/kept$FX_EXT:" && expect_not "build/out$FX_EXT:" && ok
finish

begin "a path that starts with a dash is measured, never read as an option"
fill_dir "-pkg" "$MAX_FILES"; write_src "-src/over$FX_EXT" $((MAX_LINES + 1))
run_lint package-size; first="$OUT"
run_lint file-length
expect_exit 0 && { [[ "$first" == *"-pkg: $MAX_FILES source files"* ]] || bad "the dash-named directory was not counted"; } \
  && [[ "$first" == *"-pkg: $MAX_FILES source files"* ]] && expect_has "-src/over$FX_EXT: $((MAX_LINES + 1)) code lines" && ok
finish

begin "in a git repository an ignored source file is not counted in its directory"
fill_dir pkg "$MAX_FILES"
printf 'pkg/*\n!pkg/m1%s\n' "$FX_EXT" > "$REPO/.gitignore"
(cd "$REPO" && git init -q)
run_lint package-size
expect_exit 0 && expect_no_finding && ok
finish

begin "--files picks the directories, and each is counted in full"
fill_dir pkg "$MAX_FILES"
printf 'pkg/m1%s\n' "$FX_EXT" > "$REPO/files.txt"
run_lint package-size --files files.txt
expect_exit 0 && expect_has "pkg: $MAX_FILES source files (limit $MAX_FILES, profile default)" && ok
finish

begin "two runs print the same output"
write_src "src/over$FX_EXT" $((MAX_LINES + 1)); fill_dir pkg "$MAX_FILES"
run_lint package-size; first="$OUT"
run_lint package-size
expect_exit 0 && { [[ "$OUT" == "$first" ]] || bad "the second run printed something else"; } && [[ "$OUT" == "$first" ]] && ok
finish

begin "a tree without a source file is measured clean"
printf 'notes\n' > "$REPO/README.md"
run_lint file-length
expect_exit 0 && expect_has "no source file in scope" && ok
finish

} # run_row_cases

for ROW in $FX_ROWS; do
  use_row "$ROW"
  run_row_cases
done
ROW=""

# --- row-independent ---
begin "a missing subcommand is a usage error (exit 2)"
run_lint
expect_exit 2 && expect_has "name a subcommand" && ok
finish

begin "a --files list that does not exist is a usage error (exit 2)"
run_lint file-length --files no-such-list.txt
expect_exit 2 && expect_has "no such file list" && ok
finish

# run_bounded <args...> — runs the script without the harness's --root, and
# stops it after five seconds, so a regression that loops fails, never hangs
run_bounded() {
  local outf pid i; outf=$(mktemp)
  ( cd "$REPO" && exec bash "$LINT" "$@" ) > "$outf" 2>&1 &
  pid=$!
  for (( i = 0; i < 50; i++ )); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; CODE=124; else wait "$pid"; CODE=$?; fi
  OUT=$(cat "$outf"); ERR=""; rm -f "$outf"
}

for opt in --root --files --glob --test-re; do
  begin "$opt without its value is a usage error (exit 2)"
  run_bounded file-length "$opt"
  expect_exit 2 && expect_has "$opt needs a value" && ok
  finish
done

# --- the recommended configs under setup/, checked by their own linters when
# the machine has them ---
SETUP_DIR="$(dirname "$LINT")/../setup"

while IFS=$'\t' read -r setup_file setup_tool; do
  begin "setup/$setup_file passes its own linter's check"
  if ! command -v "$setup_tool" >/dev/null 2>&1; then skip "$setup_tool is not on PATH"; finish; continue; fi
  OUT=$(lint_setup_check "$setup_file" "$SETUP_DIR" "$REPO" 2>&1); CODE=$?; ERR=""
  expect_exit 0 && ok
  finish
done < <(lint_setup_files)

# ========================= summary =========================
echo
echo "ldd-lint_test: $pass passed, $failed failed, $skipped skipped"
(( failed == 0 ))
