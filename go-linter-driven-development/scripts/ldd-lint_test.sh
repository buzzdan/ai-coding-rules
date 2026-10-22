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
FX_ROWS="go"
FX_NATIVE="go"

use_row() {
  FX_LINTER_CONFIG='.golangci.yaml'
  FX_SETUP_FILE='golangci.yaml'
  FX_ADOPTED_CONFIG=''
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
#   lint_doctor_linter <id>         the linter the doctor compares for the
#                                   language; "" when the plugin recommends none
#   lint_reports_settings <linter>  exit 0 when the linter reports the setting
#                                   of each rule, so the doctor compares values;
#                                   exit 1 when it reports only which rules run
#   lint_doctor <id> <setup dir> <file>  compare the repository's linter with
#                                   the plugin's recommended config for the
#                                   language. <file> is a source file of the
#                                   language, for a linter that resolves its
#                                   settings per file. Prints tab-separated
#                                   records, never an empty field:
#                                     note TAB <text>
#                                     row TAB <linter> TAB <rule> TAB <state> TAB <recommended> TAB <current> TAB <source>
#                                   The rules: the ones the recommended config
#                                   enables, as the linter resolves it, beyond
#                                   the linter's default set, and the default
#                                   rules it names that the repository does not
#                                   run. state: runs · missing · limit looser
#                                   or limit stricter (the repository's setting
#                                   lets more code pass, or less, than the
#                                   recommended one) · options differ (the two
#                                   settings differ in a way that is not one
#                                   limit) · named (the rule is
#                                   named outside comments in the repository's
#                                   config; the linter was not asked) · cannot
#                                   verify: <why>. recommended and current: the
#                                   setting as the linter reports it, or "see
#                                   <file>: <key>" when the linter cannot report
#                                   it and a reader must look there, or "-".
#                                   source: linter (the linter said whether the
#                                   rule runs) or presence check (the rule was
#                                   found by name). An output the doctor cannot
#                                   read is "cannot verify", never an empty list

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
  local re="$1" f p; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    p="./$f"; [[ "$f" == /* ]] && p="$f"
    lint_strip_comments "$(_lint_config_style "$f")" "$p" 2>/dev/null | grep -qE -- "$re" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# The ESLint configs a repository root may hold. eslint.config.ldd.mjs is the
# plugin's recommended fragment: a repository that adopts it keeps it beside
# eslint.config.js and imports it.
LINT_ESLINT_CONFIGS=(eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts
                     eslint.config.ldd.mjs .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml)

lint_file_length_rule() {
  local f
  case "$1" in
    go)
      f=$(_lint_names 'file-length-limit' .golangci.yaml .golangci.yml .golangci.toml .golangci.json) \
        && printf 'revive file-length-limit in %s' "$f" ;;
    typescript|javascript)
      if f=$(_lint_names 'sonarjs/max-lines([^-a-zA-Z]|$)' "${LINT_ESLINT_CONFIGS[@]}"); then
        printf 'sonarjs/max-lines in %s' "$f"
      elif f=$(_lint_names '(^|[^-/a-zA-Z])max-lines([^-a-zA-Z]|$)' "${LINT_ESLINT_CONFIGS[@]}"); then
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

# ---------- doctor ----------
lint_doctor_linter() {
  case "$1" in
    go)                    printf 'golangci-lint' ;;
    python)                printf 'ruff' ;;
    typescript|javascript) printf 'eslint' ;;
  esac
  return 0
}

lint_reports_settings() {
  case "$1" in
    golangci-lint) return 1 ;;
  esac
  return 0
}

lint_doctor() { # <id> <setup dir> <file>
  # Under the caller's LINT_TMP when it sets one, so its exit trap removes it
  local t; t=$(mktemp -d "${LINT_TMP:-${TMPDIR:-/tmp}}/ldd-doctor.XXXXXX")
  case "$1" in
    go)                    _lint_doctor_golangci "$2/golangci.yaml" "$t" ;;
    python)                _lint_doctor_ruff "$2/ruff.toml" "$3" "$t" ;;
    typescript|javascript) _lint_doctor_eslint "$2/eslint.config.ldd.mjs" "$3" "$t" ;;
  esac
  rm -rf "$t"
}

_lint_doctor_cannot() { # <linter> <why>
  printf 'row\t%s\t-\tcannot verify: %s\t-\t-\tlinter\n' "$1" "$2"
}

# _lint_first_error <file> — the first line of a linter's stderr that names an
# error, else its first line, on one line
_lint_first_error() {
  { grep -m1 -iE 'error' "$1" || head -1 "$1"; } | tr '\t' ' '
}

# _lint_doctor_sets <recommended> <default> <repository> <recommended config>
# — "rule TAB runs" or "rule TAB missing" for every rule the recommended set
# enables beyond the linter's default set, and for every default rule the
# recommended config names outside comments that the repository does not run.
# Each of the first three files holds one rule per line, sorted with LC_ALL=C.
_lint_doctor_sets() {
  local r
  { LC_ALL=C comm -23 "$1" "$2"
    LC_ALL=C comm -12 "$1" "$2" | LC_ALL=C comm -23 - "$3" | while IFS= read -r r; do
      _lint_names "(^|[^A-Za-z0-9_-])$r([^A-Za-z0-9_-]|\$)" "$4" >/dev/null && printf '%s\n' "$r"
    done; } \
    | LC_ALL=C sort -u | while IFS= read -r r; do
      if grep -qxF -- "$r" "$3"; then printf '%s\truns\n' "$r"; else printf '%s\tmissing\n' "$r"; fi
    done
}

# golangci-lint reports which linters a config enables, never their settings.
# A setting of the recommended config is "see <file>: <key>" on both sides.

# _lint_golangci_names <file> — the linter names of a "linters --json"
# output's Enabled list, sorted
_lint_golangci_names() {
  tr -d '\n' < "$1" | sed 's/"Disabled":.*//' | grep -oE '"name":"[^"]+"' | sed 's/^"name":"//; s/"$//' | LC_ALL=C sort -u
}

# _lint_golangci_alternative <linter> — a linter the recommended config
# accepts in its place (its own comment says to enable one of the two)
_lint_golangci_alternative() {
  case "$1" in
    gocyclo) printf 'cyclop' ;;
  esac
  return 0
}

# _lint_golangci_tuned <config> <linter> — exit 0 when the config has a
# settings block for the linter
_lint_golangci_tuned() {
  lint_strip_comments hash "$1" | grep -qE -- "^[[:space:]]+$2:[[:space:]]*$"
}

# _lint_revive_rules <config> — "rule TAB 1" for a revive rule with
# arguments, "rule TAB 0" for one without, for every rule the config's revive
# block names
_lint_revive_rules() {
  lint_strip_comments hash "$1" | awk -v q="'" '
    function indent(s) { match(s, /^ */); return RLENGTH }
    /^[ \t]*$/ { next }
    inrev && indent($0) <= revind { inrev = 0; if (name != "") print name "\t0"; name = "" }
    /^[ \t]+revive:[ \t]*$/ { inrev = 1; revind = indent($0); next }
    !inrev { next }
    name != "" { print name "\t" ($0 ~ /^[ \t]+arguments:/ ? 1 : 0); name = "" }
    /^[ \t]*-[ \t]*name:[ \t]*/ { name = $0; sub(/^[ \t]*-[ \t]*name:[ \t]*/, "", name); gsub("[\"" q " \t]", "", name) }
    END { if (name != "") print name "\t0" }'
}

_lint_doctor_golangci() { # <recommended config> <work dir>
  local rec="$1" t="$2" out cfg r re state tuned rv cv here alt held why
  command -v golangci-lint >/dev/null 2>&1 || { _lint_doctor_cannot golangci-lint "golangci-lint is not installed"; return 0; }
  golangci-lint linters --json -c "$rec" > "$t/rec.json" 2> "$t/err" \
    || { _lint_doctor_cannot golangci-lint "golangci-lint cannot run with the recommended config: $(_lint_first_error "$t/err")"; return 0; }
  golangci-lint linters --json --no-config > "$t/def.json" 2> "$t/err" \
    || { _lint_doctor_cannot golangci-lint "the linter fails with no config: $(_lint_first_error "$t/err")"; return 0; }
  # "path" is "" when the linter finds no config from this directory up
  out=$(golangci-lint config path --json 2>/dev/null) \
    || { _lint_doctor_cannot golangci-lint "the linter cannot say which config it reads"; return 0; }
  case "$out" in
    *'"path":'*) cfg=$(printf '%s' "$out" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p') ;;
    *) _lint_doctor_cannot golangci-lint "cannot read the linter's answer to which config it reads"; return 0 ;;
  esac
  if [[ -n "$cfg" ]]; then
    # A schema failure is a rejection; any other failure (no network for the
    # schema, for example) leaves the check unanswered and the doctor goes on.
    if ! golangci-lint config verify > /dev/null 2> "$t/err" && grep -q '^jsonschema:' "$t/err"; then
      why=$(grep -m1 '^jsonschema:' "$t/err" | tr '\t' ' ')
      _lint_doctor_cannot golangci-lint "the repository config fails the linter's check: $why"
      return 0
    fi
    golangci-lint linters --json > "$t/repo.json" 2> "$t/err" \
      || { _lint_doctor_cannot golangci-lint "the linter rejects $cfg: $(_lint_first_error "$t/err")"; return 0; }
    printf 'note\tgolangci-lint, the repository config %s; the linter reports which linters run, not their settings; revive rules are found by name, so enable-all-rules and a disabled rule are not seen\n' "$cfg"
    here="see $cfg"
  else
    cp "$t/def.json" "$t/repo.json"
    printf 'note\tgolangci-lint, no repository config: the linter runs its default set\n'
    here="the linter's default"
  fi
  _lint_golangci_names "$t/rec.json" > "$t/rec"
  _lint_golangci_names "$t/def.json" > "$t/def"
  _lint_golangci_names "$t/repo.json" > "$t/repo"
  [[ -s "$t/rec" && -s "$t/def" ]] \
    || { _lint_doctor_cannot golangci-lint "cannot read the linter's list of the linters it runs"; return 0; }
  _lint_doctor_sets "$t/rec" "$t/def" "$t/repo" "$rec" | while IFS=$'\t' read -r r state; do
    rv=-; cv=-; alt=$(_lint_golangci_alternative "$r"); held="$r"
    if [[ "$state" == missing && -n "$alt" ]] && grep -qxF -- "$alt" "$t/repo"; then
      state=runs; held="$alt"
    fi
    if _lint_golangci_tuned "$rec" "$r"; then
      rv="see $rec: linters.settings.$r"
      [[ "$state" == runs && -n "$cfg" ]] && cv="see $cfg: linters.settings.$held, the linter's default when absent"
      [[ "$state" == runs && -z "$cfg" ]] && cv="the linter's default"
    fi
    [[ "$held" != "$r" ]] && cv="$held runs in its place; $cv"
    printf 'row\tgolangci-lint\t%s\t%s\t%s\t%s\tlinter\n' "$r" "$state" "$rv" "$cv"
  done
  grep -qxF revive "$t/rec" || return 0
  # The linter cannot say which revive rules run: a rule the repository's
  # config names outside comments is "named". The name field reads alike in
  # YAML (name: r), TOML (name = "r") and JSON ("name": "r").
  _lint_revive_rules "$rec" | while IFS=$'\t' read -r r tuned; do
    rv=-; cv=-; state=missing
    re="(^|[^A-Za-z0-9_-])[\"']?name[\"']?[[:space:]]*[:=][[:space:]]*[\"']?$r[\"']?([[:space:],}]|$)"
    grep -qxF revive "$t/repo" && [[ -n "$cfg" ]] && _lint_names "$re" "$cfg" >/dev/null && state=named
    if [[ "$tuned" == 1 ]]; then
      rv="see $rec: linters.settings.revive.rules, name $r"
      [[ "$state" == named ]] && cv="$here: linters.settings.revive.rules, name $r"
    fi
    printf 'row\tgolangci-lint\trevive %s\t%s\t%s\t%s\tpresence check\n' "$r" "$state" "$rv" "$cv"
  done
}

# ruff reports the rules it runs and every setting, resolved per file.

# _lint_ruff_rules <file> — the rule codes of a --show-settings output's
# linter.rules.enabled list, sorted
_lint_ruff_rules() {
  awk '/^linter\.rules\.enabled = \[\]/ { exit }
       /^linter\.rules\.enabled = \[/ { f = 1; next }
       f && /^\]/ { exit }
       f' "$1" | grep -oE '\([A-Z]+[0-9]+\)' | tr -d '()' | LC_ALL=C sort -u
}

# _lint_ruff_value <file> <key> — the value of linter.<key> in a
# --show-settings output
_lint_ruff_value() {
  awk -v k="linter.$2" '$1 == k && $2 == "=" { print $3; exit }' "$1"
}

# _lint_ruff_setting <code> — the setting that holds the rule's limit. Each is
# a maximum: a larger value lets more code pass.
_lint_ruff_setting() {
  case "$1" in
    C901)    printf 'mccabe.max_complexity' ;;
    PLR0911) printf 'pylint.max_returns' ;;
    PLR0912) printf 'pylint.max_branches' ;;
    PLR0913) printf 'pylint.max_args' ;;
    PLR0915) printf 'pylint.max_statements' ;;
    PLR1702) printf 'pylint.max_nested_blocks' ;;
  esac
  return 0
}

# _lint_limit_state <recommended> <current> — of a maximum: "runs" when the
# two are equal, "limit looser" when the current one is larger, "limit
# stricter" when it is smaller; "options differ" when one is not a whole number
_lint_limit_state() {
  if [[ "$1" == "$2" ]]; then printf 'runs'
  elif [[ ! "$1" =~ ^[0-9]+$ || ! "$2" =~ ^[0-9]+$ ]]; then printf 'options differ'
  elif (( $2 > $1 )); then printf 'limit looser'
  else printf 'limit stricter'; fi
}

_lint_doctor_ruff() { # <recommended config> <file> <work dir>
  local rec="$1" f="./$2" t="$3" sp r state key rv cv a b
  command -v ruff >/dev/null 2>&1 || { _lint_doctor_cannot ruff "ruff is not installed"; return 0; }
  [[ -n "$2" ]] || { _lint_doctor_cannot ruff "no source file to resolve the settings for"; return 0; }
  ruff check --no-cache --color never --show-settings --config "$rec" "$f" > "$t/rec.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "ruff cannot run with the recommended config: $(_lint_first_error "$t/err")"; return 0; }
  ruff check --no-cache --color never --show-settings --isolated "$f" > "$t/def.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter fails with no config: $(_lint_first_error "$t/err")"; return 0; }
  ruff check --no-cache --color never --show-settings "$f" > "$t/repo.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter rejects the repository's config: $(_lint_first_error "$t/err")"; return 0; }
  sp=$(sed -n 's/^Settings path: "\(.*\)"$/\1/p' "$t/repo.txt")
  sp="${sp#"$(pwd -P)"/}"; sp="${sp#"$(pwd)"/}"
  [[ -n "$sp" ]] || sp="no config file, the linter's defaults"
  printf 'note\truff, the settings resolved for %s from %s\n' "$2" "$sp"
  _lint_ruff_rules "$t/rec.txt" > "$t/rec"
  _lint_ruff_rules "$t/def.txt" > "$t/def"
  _lint_ruff_rules "$t/repo.txt" > "$t/repo"
  [[ -s "$t/rec" && -s "$t/def" ]] \
    || { _lint_doctor_cannot ruff "cannot read the linter's list of the rules it runs"; return 0; }
  _lint_doctor_sets "$t/rec" "$t/def" "$t/repo" "$rec" | while IFS=$'\t' read -r r state; do
    rv=-; cv=-
    key=$(_lint_ruff_setting "$r")
    if [[ -n "$key" ]]; then
      a=$(_lint_ruff_value "$t/rec.txt" "$key"); b=$(_lint_ruff_value "$t/repo.txt" "$key")
      rv="$key = $a"
      if [[ -z "$a" || ( "$state" == runs && -z "$b" ) ]]; then
        state="cannot verify: the linter reports no $key"; rv=-
      elif [[ "$state" == runs ]]; then
        cv="$key = $b"
        state=$(_lint_limit_state "$a" "$b")
      fi
    fi
    printf 'row\truff\t%s\t%s\t%s\t%s\tlinter\n' "$r" "$state" "$rv" "$cv"
  done
}

# ESLint: the doctor runs the project's own ESLint (node_modules/.bin/eslint)
# with --print-config on one source file: the config as ESLint resolves it,
# shared configs included.

# _lint_eslint_rules <config> — "rule TAB options" for every rule the
# recommended config sets, once per rule, in the order the config first sets
# it: options is the text after the severity when it fits on the rule's line,
# "..." when it runs on, "-" when there is none; a rule set to "off" (as for
# test files) is left out
_lint_eslint_rules() {
  lint_strip_comments c "$1" | awk -v q="'" '
    { line = $0; sub(/^[ \t]+/, "", line)
      if (substr(line, 1, 1) != q) next
      rest = substr(line, 2); i = index(rest, q); if (i == 0) next
      name = substr(rest, 1, i - 1); after = substr(rest, i + 1)
      if (substr(after, 1, 1) != ":") next
      sub(/^:[ \t]*/, "", after); c = substr(after, 1, 1)
      sev = after; sub(/^\[[ \t]*/, "", sev)
      if (substr(sev, 1, 5) == q "off" q || seen[name]++) next
      if (c == q) { print name "\t-"; next }
      if (c != "[") next
      opts = after; sub(/[ \t]*,?[ \t]*$/, "", opts)
      if (opts !~ /\]$/) { print name "\t..."; next }
      sub(/\]$/, "", opts); sub(/^\[[^,]*/, "", opts)
      if (opts == "") { print name "\t-"; next }
      sub(/^,[ \t]*/, "", opts); print name "\t" opts }'
}

# _lint_eslint_resolved <file> — "rule TAB severity TAB options" for every rule
# of an "eslint --print-config" output (JSON, two spaces per level); options
# is the rest of the rule's array on one line, "-" when there is none. A first
# line "#rules" says the output has a rules object, which may be empty
_lint_eslint_resolved() {
  awk '
    function flush() {
      if (key == "") return
      sub(/,$/, "", val); sub(/^\[/, "", val); sub(/\]$/, "", val)
      sev = val; sub(/,.*$/, "", sev); gsub(/"/, "", sev)
      opts = "-"; if (index(val, ",") > 0) opts = substr(val, index(val, ",") + 1)
      print key "\t" sev "\t" opts; key = ""
    }
    /^  "rules": [{][}]/ { print "#rules"; exit }
    /^  "rules": [{]/ { print "#rules"; r = 1; next }
    !r { next }
    /^  [}]/ { flush(); exit }
    /^    "/ { flush(); key = $0; sub(/^    "/, "", key); sub(/".*$/, "", key)
               val = $0; sub(/^    "[^"]*":[ ]*/, "", val); next }
    { v = $0; sub(/^ +/, "", v); val = val v }
    END { flush() }' "$1"
}

# _lint_eslint_error <file> — the line of ESLint's stderr that says what went
# wrong, past its "Oops!" banner and version line
_lint_eslint_error() {
  grep -vE '^(Oops!|ESLint: [0-9]|[[:space:]]*$)' "$1" > "$1.lines"
  { grep -m1 -i 'error' "$1.lines" || head -1 "$1.lines"; } | tr '\t' ' '
}

# _lint_eslint_compare <recommended options> <current options> — the state of
# a rule that runs: runs when the options agree, or when either side sets
# none; limit looser or limit stricter when the recommended options are one
# limit (a number, or one key with a number) and the current one holds that
# limit at another value; options differ otherwise. Each limit is a maximum.
_lint_eslint_compare() {
  local rn cn re_num='^[0-9]+$' re_key='^[{]([A-Za-z]+):([0-9]+)[}]$' k n m
  case "$1" in -|...) printf 'runs'; return 0 ;; esac
  [[ "$2" == - ]] && { printf 'runs'; return 0; }
  rn=$(printf '%s' "$1" | tr -d "\"' \t"); cn=$(printf '%s' "$2" | tr -d "\"' \t")
  [[ "$rn" == "$cn" ]] && { printf 'runs'; return 0; }
  if [[ "$rn" =~ $re_num ]]; then
    if [[ "$cn" =~ $re_num ]]; then _lint_limit_state "$rn" "$cn"; else printf 'options differ'; fi
    return 0
  fi
  if [[ "$rn" =~ $re_key ]]; then
    k="${BASH_REMATCH[1]}"; n="${BASH_REMATCH[2]}"
    m=$(printf '%s\n' "$cn" | sed -n "s/.*[{,]$k:\([0-9][0-9]*\)[,}].*/\1/p")
    if [[ -n "$m" && "$m" != "$n" ]]; then _lint_limit_state "$n" "$m"; return 0; fi
  fi
  printf 'options differ'
}

# _lint_eslint_bin — the project's ESLint: node_modules/.bin/eslint in this
# directory, or in a directory above it up to the top of the git work tree,
# where a workspace keeps its hoisted packages
_lint_eslint_bin() {
  local d top
  d=$(pwd -P); top=$(git rev-parse --show-toplevel 2>/dev/null) || top="$d"
  top=$(cd "$top" && pwd -P)
  while :; do
    [[ -x "$d/node_modules/.bin/eslint" ]] && { printf '%s' "$d/node_modules/.bin/eslint"; return 0; }
    [[ "$d" == "$top" || "$d" == / ]] && return 1
    d=$(dirname "$d")
  done
}

# _lint_eslint_pnp — exit 0 when a Yarn Plug'n'Play install serves this
# directory: then no node_modules/.bin holds ESLint
_lint_eslint_pnp() {
  local d top
  d=$(pwd -P); top=$(git rev-parse --show-toplevel 2>/dev/null) || top="$d"
  top=$(cd "$top" && pwd -P)
  while :; do
    [[ -f "$d/.pnp.cjs" ]] && return 0
    [[ "$d" == "$top" || "$d" == / ]] && return 1
    d=$(dirname "$d")
  done
}

_lint_doctor_eslint() { # <recommended config> <file> <work dir>
  local rec="$1" t="$3" bin r ro sev opts state rv cv a b
  if ! bin=$(_lint_eslint_bin); then
    if _lint_eslint_pnp; then
      _lint_doctor_cannot eslint "eslint is not installed in node_modules: the project uses Yarn Plug'n'Play"
    else
      local sub
      sub=$(find . -maxdepth 4 -path '*/node_modules/.bin/eslint' -not -path '*/node_modules/*/node_modules/*' 2>/dev/null \
            | sed 's|^\./||; s|/node_modules/\.bin/eslint$||' | LC_ALL=C sort | head -3 | tr '\n' ' ')
      if [[ -n "$sub" ]]; then
        _lint_doctor_cannot eslint "eslint is not installed here, but in a project below: ${sub% }; run the doctor with --root on that project"
      else
        _lint_doctor_cannot eslint "eslint is not installed in this project (no node_modules/.bin/eslint): install its packages"
      fi
    fi
    return 0
  fi
  _lint_eslint_rules "$rec" > "$t/rec"
  [[ -s "$t/rec" ]] || { _lint_doctor_cannot eslint "cannot read the rules of the recommended config $rec"; return 0; }
  [[ -n "$2" ]] || { _lint_doctor_cannot eslint "no source file to resolve the config for"; return 0; }
  "$bin" --print-config "./$2" > "$t/repo.json" 2> "$t/err" \
    || { _lint_doctor_cannot eslint "the linter rejects the repository's config: $(_lint_eslint_error "$t/err")"; return 0; }
  if [[ "$(tr -d '[:space:]' < "$t/repo.json")" == undefined ]]; then
    _lint_doctor_cannot eslint "ESLint ignores $2; run the doctor with --root on a directory whose files ESLint checks"
    return 0
  fi
  _lint_eslint_resolved "$t/repo.json" > "$t/resolved"
  grep -qx '#rules' "$t/resolved" || { _lint_doctor_cannot eslint "cannot read the linter's resolved config for $2"; return 0; }
  printf 'note\tESLint %s, the config resolved for %s\n' "$bin" "$2"
  while IFS=$'\t' read -r r ro; do
    rv=-; cv=-; state=missing
    case "$ro" in
      -)    ;;
      ...)  rv="see $rec: rules['$r']" ;;
      *)    rv="$ro" ;;
    esac
    IFS=$'\t' read -r sev opts < <(awk -F'\t' -v r="$r" '$1 == r { print $2 "\t" $3; exit }' "$t/resolved")
    case "${sev:-0}" in
      0|off) ;;
      *)
        state=runs; cv="$opts"
        [[ "$sev" == 1 || "$sev" == warn ]] && cv="warn; $opts"
        state=$(_lint_eslint_compare "$ro" "$opts") ;;
    esac
    sev=""; opts=""
    printf 'row\teslint\t%s\t%s\t%s\t%s\tlinter\n' "$r" "$state" "$rv" "$cv"
  done < "$t/rec"
}
# ================== end linter table ==================

# ==================== fake linters for the doctor ====================
# What the doctor cases need per language id: a fake of the language's
# linter, which prints the output the real one prints, and the repository
# config the case writes. The fakes let the matrix run where no linter is
# installed; the "installed linter" case checks the parsers against the real
# output where one is.
# residue-exempt: the fakes name every language's linter and config file on
# purpose, the same in every rendering.
#
#   fake_doctor_row          set the row's FAKE_* variables (below)
#   fake_doctor <mode>       write the fake linter ($REPO/.bin, or the
#                            project's node_modules/.bin) and the repository
#                            config.
#                            Modes: adopt (the repository runs every
#                            recommended rule at the recommended settings),
#                            missing (it leaves FAKE_RULE out), relaxed (it sets
#                            a looser limit for FAKE_RULE), tightened (a
#                            stricter one), alternative (it runs, in place
#                            of a recommended linter, the one the recommended
#                            config accepts instead), commented (it names
#                            FAKE_NAMED_RULE only inside a comment), reject
#                            (the linter rejects the repository's config),
#                            garbled (the linter prints an output of another
#                            shape), ignored (the linter skips the file the
#                            doctor resolves the config for), optsdiffer
#                            (a rule set with other options), norules (the
#                            config loads and sets no rule), toml and json (the
#                            repository's config is in that format and names
#                            FAKE_NAMED_RULE), invalid (the linter's own
#                            config check fails on a schema error) and
#                            noschema (that check cannot fetch the schema)
#   real_doctor_adopt        copy the plugin's recommended config into $REPO as
#                            the repository's own config
#
#   FAKE_LINTER      the linter the doctor names in its rows
#   FAKE_BIN         the linter's executable
#   FAKE_REAL        the executable on PATH the installed-linter case needs;
#                    "" when the linter is installed per project
#   FAKE_RULE        a recommended rule with a setting
#   FAKE_RUNS        the state of a rule the adopted config holds
#   FAKE_RELAXED     the text of FAKE_RULE's row in the relaxed mode, and
#   FAKE_TIGHTENED   in the tightened mode; "" when the linter reports no
#                    setting, so the doctor cannot compare one
#   FAKE_ALTERNATIVE the text of the row in the alternative mode; "" when
#                    the recommended config names no alternative
#   FAKE_NAMED_RULE  a rule the doctor finds by name in the repository's
#                    config; "" when the linter reports every rule itself
#   FAKE_CONFIG      the repository config the fake modes write
#   FAKE_WARN        the text of a row whose rule the adopted config runs as a
#                    warning; "" when the linter reports no severity
#   FAKE_IGNORED     the text the doctor prints in the ignored mode; "" when
#                    the linter resolves its settings for any file
#   FAKE_NORULES     1 when the linter can report a config with no rule, is
#                    installed per project, and resolves its config per file
#   FAKE_OPTIONS     the text of a row in the optsdiffer mode (a rule set with
#                    options that are not one limit); "" when the linter
#                    reports no such options
#   FAKE_FORMATS     the other config formats the toml and json modes write;
#                    "" when the language has one
#   FAKE_NO_SETTINGS "yes" when the linter reports only which rules run, never
#                    a setting, so an agreed rule is matched by name; "" if not
#   FAKE_BARE_RULE   a rule that runs in the adopted config and has no setting
#                    in its row (recommended and current are "-"); "" when no
#                    such rule exists
#   FAKE_SEE_RULE    a rule whose recommended side is a place to read, though
#                    the linter reports the current setting; "" if none
#   FAKE_CONFIG_CHECK "yes" when the linter has a config check of its own,
#                    which the invalid and noschema modes fail; "" if not

fake_doctor_row() {
  case "$ROW" in
    go)
      FAKE_LINTER='golangci-lint'; FAKE_BIN='golangci-lint'; FAKE_REAL='golangci-lint'; FAKE_RULE='funlen'; FAKE_RUNS='runs'; FAKE_TIGHTENED=''
      FAKE_WARN=''; FAKE_IGNORED=''; FAKE_NORULES=''; FAKE_OPTIONS=''; FAKE_FORMATS='toml json'; FAKE_CONFIG_CHECK='yes'
      FAKE_NO_SETTINGS='yes'; FAKE_BARE_RULE='gochecknoglobals'; FAKE_SEE_RULE=''
      FAKE_ALTERNATIVE="gocyclo: runs; recommended: see $(_fake_setup golangci.yaml): linters.settings.gocyclo; current: cyclop runs in its place; see .golangci.yaml: linters.settings.cyclop"
      FAKE_RELAXED="funlen: runs; recommended: see $(_fake_setup golangci.yaml): linters.settings.funlen; current: see .golangci.yaml: linters.settings.funlen, the linter's default when absent"
      FAKE_NAMED_RULE='revive file-length-limit'; FAKE_CONFIG='.golangci.yaml' ;;
    python)
      FAKE_LINTER='ruff'; FAKE_BIN='ruff'; FAKE_REAL='ruff'; FAKE_RULE='PLR0913'; FAKE_RUNS='runs'; FAKE_ALTERNATIVE=''
      FAKE_WARN=''; FAKE_IGNORED=''; FAKE_NORULES=''; FAKE_OPTIONS=''; FAKE_FORMATS=''; FAKE_CONFIG_CHECK=''
      FAKE_NO_SETTINGS=''; FAKE_BARE_RULE=''; FAKE_SEE_RULE=''
      FAKE_RELAXED='PLR0913: limit looser; recommended: pylint.max_args = 4; current: pylint.max_args = 7'
      FAKE_TIGHTENED='PLR0913: limit stricter; recommended: pylint.max_args = 4; current: pylint.max_args = 3'
      FAKE_NAMED_RULE=''; FAKE_CONFIG='pyproject.toml' ;;
    typescript)
      FAKE_LINTER='eslint'; FAKE_BIN='eslint'; FAKE_REAL=''; FAKE_RULE='max-params'; FAKE_RUNS='runs'; FAKE_ALTERNATIVE=''
      FAKE_RELAXED='max-params: limit looser; recommended: 4; current: 6'
      FAKE_TIGHTENED='max-params: limit stricter; recommended: 4; current: 3'
      FAKE_OPTIONS='no-param-reassign: options differ; recommended: { props: true }; current: {"props": false}'
      FAKE_WARN='sonarjs/elseif-without-else: runs; recommended: -; current: warn; -'
      FAKE_IGNORED='cannot verify: ESLint ignores src/a'
      FAKE_NORULES=1; FAKE_FORMATS=''; FAKE_CONFIG_CHECK=''
      FAKE_NO_SETTINGS=''; FAKE_BARE_RULE=''; FAKE_SEE_RULE='no-magic-numbers'
      FAKE_NAMED_RULE=''; FAKE_CONFIG='eslint.config.mjs' ;;
  esac
}

# _fake_setup <file> — the plugin's recommended config of that name
_fake_setup() { printf '%s/%s' "$(cd "$(dirname "$LINT")/../setup" && pwd)" "$1"; }

# _fake_golangci_json <name>... — a "linters --json" output enabling those
_fake_golangci_json() {
  local n sep=""
  printf '{"Enabled":['
  for n in "$@"; do printf '%s{"name":"%s","description":"Checks \\"name\\":\\"x\\" text.","fast":true}' "$sep" "$n"; sep=","; done
  printf '],"Disabled":[{"name":"dupl","description":"Detects duplicate fragments of code."}]}\n'
}

# _fake_ruff_settings <settings path or ""> <max_args> <code>... — a
# "--show-settings" output enabling those codes
_fake_ruff_settings() {
  local sp="$1" args="$2" root c; shift 2
  root=$(cd "$REPO" && pwd -P)
  printf 'Resolved settings for: "%s/src/a.py"\n' "$root"
  [[ -n "$sp" ]] && printf 'Settings path: "%s/%s"\n' "$root" "$sp"
  printf '\n# Linter Settings\nlinter.exclude = []\nlinter.rules.enabled = [\n'
  for c in "$@"; do printf '\tsome-rule (%s),\n' "$c"; done
  printf ']\nlinter.rules.should_fix = [\n\tsome-rule (B006),\n]\n'
  printf 'linter.mccabe.max_complexity = 8\nlinter.pylint.max_args = %s\nlinter.pylint.max_nested_blocks = 2\n' "$args"
}

_fake_bin() { # <name> <script body> [<dir>]
  local dir="${3:-$REPO/.bin}"
  mkdir -p "$dir"
  printf '#!/bin/sh\nd=$(dirname "$0")\n%s\n' "$2" > "$dir/$1"
  chmod +x "$dir/$1"
}

# _fake_eslint_json <mode> — an "eslint --print-config" output, laid out as
# ESLint lays it out, with every rule the recommended config sets at its
# recommended options: a number on its own line, a one-key limit as an object
# over several lines, other options left out
_fake_eslint_json() {
  local mode="$1" r ro rn n k sev re_num='^[0-9]+$' re_key='^[{]([A-Za-z]+):([0-9]+)[}]$'
  printf '{\n  "settings": {\n    "react": {\n      "version": "detect"\n    }\n  },\n  "rules": {\n'
  printf '    "constructor-super": [\n      0\n    ]'
  _lint_eslint_rules "$(_fake_setup eslint.config.ldd.mjs)" | while IFS=$'\t' read -r r ro; do
    rn=$(printf '%s' "$ro" | tr -d "\"' \t"); n=""; k=""; sev=2
    if [[ "$rn" =~ $re_num ]]; then n="$rn"
    elif [[ "$rn" =~ $re_key ]]; then k="${BASH_REMATCH[1]}"; n="${BASH_REMATCH[2]}"; fi
    [[ "$r" == sonarjs/elseif-without-else ]] && sev=1
    if [[ "$r" == max-params ]]; then
      case "$mode" in
        missing)   sev=0 ;;
        relaxed)   n=6 ;;
        tightened) n=3 ;;
      esac
    fi
    printf ',\n'
    if [[ "$r" == no-param-reassign && "$mode" == optsdiffer ]]; then
      printf '    "%s": [\n      2,\n      {\n        "props": false\n      }\n    ]' "$r"
    elif [[ -n "$k" && "$sev" != 0 ]]; then
      printf '    "%s": [\n      %s,\n      {\n        "%s": %s\n      }\n    ]' "$r" "$sev" "$k" "$n"
    elif [[ -n "$n" && "$sev" != 0 ]]; then
      printf '    "%s": [\n      %s,\n      %s\n    ]' "$r" "$sev" "$n"
    else
      printf '    "%s": [\n      %s\n    ]' "$r" "$sev"
    fi
  done
  printf '\n  },\n  "plugins": [\n    "react"\n  ]\n}\n'
}

fake_doctor() { # <mode>
  local mode="$1" b="$REPO/.bin"
  case "$ROW" in
    go)
      _fake_bin golangci-lint '
if [ "$1" = config ] && [ "$2" = verify ]; then
  if [ -f "$d/verify.txt" ]; then cat "$d/verify.txt" >&2; exit 3; fi
  exit 0
fi
if [ "$1" = config ]; then cat "$d/path.json"; exit 0; fi
[ "$1" = linters ] || exit 9
for a in "$@"; do
  case "$a" in
    --no-config) cat "$d/default.json"; exit 0 ;;
    */setup/golangci.yaml) cat "$d/recommended.json"; exit 0 ;;
  esac
done
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 3; fi
cat "$d/repo.json"'
      printf '{"absolutePath":"/r/.golangci.yaml","path":".golangci.yaml"}\n' > "$b/path.json"
      _fake_golangci_json errcheck govet > "$b/default.json"
      _fake_golangci_json errcheck funlen gochecknoglobals gocyclo govet nestif revive > "$b/recommended.json"
      cp "$b/recommended.json" "$b/repo.json"
      cp "$(_fake_setup golangci.yaml)" "$REPO/.golangci.yaml"
      case "$mode" in
        missing)   _fake_golangci_json errcheck gochecknoglobals gocyclo govet nestif revive > "$b/repo.json" ;;
        alternative) _fake_golangci_json cyclop errcheck funlen gochecknoglobals govet nestif revive > "$b/repo.json" ;;
        relaxed)   sed 's/lines: 50/lines: 80/' "$(_fake_setup golangci.yaml)" > "$REPO/.golangci.yaml" ;;
        commented) sed 's/- name: file-length-limit/# - name: file-length-limit/' "$(_fake_setup golangci.yaml)" > "$REPO/.golangci.yaml" ;;
        toml)      rm -f "$REPO/.golangci.yaml"
                   printf '{"absolutePath":"/r/.golangci.toml","path":".golangci.toml"}\n' > "$b/path.json"
                   printf 'version = "2"\n# name = "early-return" only in a comment\n[[linters.settings.revive.rules]]\nname = "file-length-limit"\narguments = [{ max = 450 }]\n' > "$REPO/.golangci.toml" ;;
        json)      rm -f "$REPO/.golangci.yaml"
                   printf '{"absolutePath":"/r/.golangci.json","path":".golangci.json"}\n' > "$b/path.json"
                   printf '{"version": "2", "linters": {"settings": {"revive": {"rules": [{"name": "file-length-limit", "arguments": [{"max": 450}]}]}}}}\n' > "$REPO/.golangci.json" ;;
        invalid)   printf 'jsonschema: "" does not validate with "/additionalProperties": additional properties '"'"'linters-settings'"'"' not allowed\nThe command is terminated due to an error: the configuration contains invalid elements\n' > "$b/verify.txt" ;;
        noschema)  printf 'Error: failed to get schema: Get "https://golangci-lint.run/jsonschema/golangci.jsonschema.json": dial tcp: lookup golangci-lint.run: no such host\n' > "$b/verify.txt" ;;
        reject)    printf 'Error: can'"'"'t load config: unsupported version of the configuration: ""\n' > "$b/reject.txt" ;;
        garbled)   for f in path default recommended repo; do printf 'Enabled by your configuration linters:\nfunlen: Checks for long functions.\n' > "$b/$f.json"; done ;;
      esac ;;
    python)
      _fake_bin ruff '
for a in "$@"; do
  case "$a" in
    --isolated) cat "$d/default.txt"; exit 0 ;;
    */setup/ruff.toml) cat "$d/recommended.txt"; exit 0 ;;
  esac
done
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 2; fi
cat "$d/repo.txt"'
      _fake_ruff_settings '' 5 E401 F401 > "$b/default.txt"
      _fake_ruff_settings ruff.toml 4 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/recommended.txt"
      _fake_ruff_settings pyproject.toml 4 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt"
      printf '[tool.ruff.lint]\nextend-select = ["B006", "C901", "PLR0913", "PLR1702"]\n' > "$REPO/pyproject.toml"
      case "$mode" in
        missing) _fake_ruff_settings pyproject.toml 4 B006 C901 E401 F401 PLR1702 > "$b/repo.txt" ;;
        relaxed) _fake_ruff_settings pyproject.toml 7 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt" ;;
        tightened) _fake_ruff_settings pyproject.toml 3 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt" ;;
        reject)  printf 'ruff failed\n  Cause: Failed to parse pyproject.toml\n' > "$b/reject.txt" ;;
        garbled) for f in default recommended repo; do printf 'linter.rules.enabled = 3 rules\n' > "$b/$f.txt"; done ;;
      esac ;;
    typescript)
      b="$REPO/node_modules/.bin"
      _fake_bin eslint '
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 2; fi
cat "$d/repo.json"' "$b"
      cp "$(_fake_setup eslint.config.ldd.mjs)" "$REPO/eslint.config.mjs"
      _fake_eslint_json "$mode" > "$b/repo.json"
      case "$mode" in
        reject)  rm -f "$REPO/eslint.config.mjs"
                 printf '\nOops! Something went wrong! :(\n\nESLint: 9.31.0\n\nESLint couldn'"'"'t find an eslint.config.(js|mjs|cjs) file.\n' > "$b/reject.txt" ;;
        garbled) printf 'Unexpected token < in JSON at position 0\n' > "$b/repo.json" ;;
        norules) printf '{\n  "languageOptions": {\n    "parser": "x"\n  },\n  "rules": {}\n}\n' > "$b/repo.json" ;;
        ignored) printf 'undefined\n' > "$b/repo.json" ;;
      esac ;;
  esac
}

real_doctor_adopt() {
  case "$ROW" in
    go)         cp "$(_fake_setup golangci.yaml)" "$REPO/.golangci.yaml" ;;
    python)     cp "$(_fake_setup ruff.toml)" "$REPO/ruff.toml" ;;
    typescript) cp "$(_fake_setup eslint.config.ldd.mjs)" "$REPO/eslint.config.mjs" ;;
  esac
}
# ================== end fake linters for the doctor ==================

# run_doctor [options...] — runs the doctor over $REPO with only the fakes in
# $REPO/.bin and the system directories on PATH, so an installed linter never
# answers for a fake
run_doctor() {
  local errf; errf=$(mktemp)
  OUT=$(cd "$REPO" && PATH="$REPO/.bin:/usr/bin:/bin" "$BASH" "$LINT" doctor "$@" --root . 2>"$errf"); CODE=$?
  ERR=$(cat "$errf"); rm -f "$errf"
}

# write_record <yaml body> — the agreement record of the repository
write_record() { printf '%s\n' "$1" > "$REPO/.ldd-lint.yaml"; }

# record_item <linter> <rule> <value> <reason> — one item line, as the
# record writes it: a double-quoted scalar with a backslash and a quote escaped
record_item() {
  local t="$1 $2 = $3 | $4"
  t=${t//\\/\\\\}; t=${t//\"/\\\"}
  printf '  - "%s"\n' "$t"
}

# doctor_field <rule> <field number> — one field of the doctor's TSV row
doctor_field() { printf '%s\n' "$OUT" | awk -F'\t' -v r="$1" -v n="$2" '$3 == r { print $n; exit }'; }

# tree_sum — one checksum line per file of $REPO, to prove a run wrote nothing
tree_sum() { (cd "$REPO" && find . -type f -not -path './.bin/*' -exec cksum {} + | LC_ALL=C sort); }

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

begin "the recommended fragment, kept as its own file and imported, hands file length to the linter"
if [[ -z "$FX_ADOPTED_CONFIG" ]]; then skip "this language's setup is copied into the linter's own config"; finish
else
  cp "$(dirname "$LINT")/../setup/$FX_ADOPTED_CONFIG" "$REPO/$FX_ADOPTED_CONFIG"
  write_src "src/over$FX_EXT" $((MAX_LINES + 50))
  run_lint file-length
  expect_exit 0 && expect_has "held by " && expect_has "in $FX_ADOPTED_CONFIG" && expect_no_finding && ok
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

# --- doctor ---
fake_doctor_row
SETUP_DIR="$(dirname "$LINT")/../setup"

begin "doctor: a repository that adopts the recommended config runs every rule"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_doctor
expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: $FAKE_RUNS;" && expect_not ": missing;" \
  && expect_not ": limit " && expect_not "cannot verify" \
  && { [[ -z "$FAKE_WARN" ]] || expect_has "$FAKE_WARN"; } && ok
finish

begin "doctor: a config that loads and sets no rule lists every recommended rule as missing"
if [[ -z "$FAKE_NORULES" ]]; then skip "the linter has no config without rules to report"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor norules
  run_doctor
  expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: missing;" && expect_not "cannot verify" && expect_not ": runs;" && ok
  finish
fi

for fmt in toml json; do
  begin "doctor: a rule named in a $fmt config is named"
  case " $FAKE_FORMATS " in
    *" $fmt "*)
      write_src "src/a$FX_EXT" 1; fake_doctor "$fmt"
      run_doctor
      expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_NAMED_RULE: named;" \
        && expect_has "$FAKE_LINTER revive early-return: missing;" && ok ;;
    *) skip "the language's linter has no $fmt config" ;;
  esac
  finish
done

begin "doctor: a rule set with options that are not one limit is options differ, never runs"
if [[ -z "$FAKE_OPTIONS" ]]; then skip "the linter reports no such options"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor optsdiffer
  run_doctor
  expect_exit 0 && expect_has "$FAKE_OPTIONS" && ok
  finish
fi

begin "doctor: the config is resolved for a source file, not a tool's config at the root"
if [[ -z "$FAKE_NORULES" ]]; then skip "the linter resolves one config for the repository"; finish
else
  write_src "tool.config$FX_EXT" 1; write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_doctor
  expect_exit 0 && expect_has "the config resolved for src/a$FX_EXT" && ok
  finish
fi

begin "doctor: a linter installed only in a project below the root names that project"
if [[ -z "$FAKE_NORULES" ]]; then skip "the linter is not installed per project"; finish
else
  write_src "web/src/a$FX_EXT" 1; fake_doctor adopt
  mkdir -p "$REPO/web" && mv "$REPO/node_modules" "$REPO/web/node_modules"
  run_doctor
  expect_exit 0 && expect_has "but in a project below: web; run the doctor with --root on that project" && ok
  finish
fi

begin "doctor: a source file the linter ignores cannot verify"
if [[ -z "$FAKE_IGNORED" ]]; then skip "the linter resolves its settings for any file"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor ignored
  run_doctor
  expect_exit 0 && expect_has "$FAKE_IGNORED" && expect_not ": runs;" && ok
  finish
fi

begin "doctor: a recommended rule the repository does not run is missing"
write_src "src/a$FX_EXT" 1; fake_doctor missing
run_doctor
expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: missing;" && ok
finish

begin "doctor: a row shows the recommended setting beside the repository's own"
write_src "src/a$FX_EXT" 1; fake_doctor relaxed
run_doctor
expect_exit 0 && expect_has "$FAKE_RELAXED" && ok
finish

begin "doctor: a limit the repository sets lower than the recommended one is stricter"
if [[ -z "$FAKE_TIGHTENED" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor tightened
  run_doctor
  expect_exit 0 && expect_has "$FAKE_TIGHTENED" && ok
  finish
fi

begin "doctor: a linter the recommended config accepts in place of another runs for it"
if [[ -z "$FAKE_ALTERNATIVE" ]]; then skip "the recommended config names no alternative"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor alternative
  run_doctor
  expect_exit 0 && expect_has "$FAKE_ALTERNATIVE" && ok
  finish
fi

begin "doctor: a rule named only inside a comment of the repository's config is missing"
if [[ -z "$FAKE_NAMED_RULE" ]]; then skip "the linter reports every rule itself"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor commented
  run_doctor
  expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_NAMED_RULE: missing;" && ok
  finish
fi

begin "doctor: a rule kept at the agreed value is agreed"
if [[ -z "$FAKE_RELAXED" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor relaxed
  run_doctor --tsv
  cur=$(doctor_field "$FAKE_RULE" 6)
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "$cur" "the team keeps it | for now")"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && expect_not "$FAKE_RULE: limit looser" && ok
  finish
fi

begin "doctor: an agreed rule whose value changed shows both values"
if [[ -z "$FAKE_RELAXED" || -n "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor relaxed
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "99" "the team keeps it")"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_RULE: limit looser;" && expect_has "; agreed: 99" && expect_not "$FAKE_RULE: agreed;" && ok
  finish
fi

begin "doctor: a missing rule agreed off is agreed"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "off" "the team does not use it")"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && expect_not "$FAKE_RULE: missing" && ok
finish

begin "doctor: a missing rule agreed at a value keeps its state and shows the value"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "7" "the team keeps it")"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: missing;" && expect_has "; agreed: 7" && ok
finish

begin "doctor: a rule that runs and is agreed off keeps its state and shows off"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "off" "the team does not use it")"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: $FAKE_RUNS;" && expect_has "; agreed: off" && expect_not "$FAKE_RULE: agreed;" && ok
finish

begin "doctor: a rule with no setting in its row is agreed at any value but off"
if [[ -z "$FAKE_BARE_RULE" ]]; then skip "the linter has no rule without a setting"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_BARE_RULE" "an agreed value" "the team keeps it")"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_BARE_RULE: agreed;" && ok
  finish
fi

begin "doctor: a rule whose recommended side is a place to read still compares the value"
if [[ -z "$FAKE_SEE_RULE" ]]; then skip "the linter has no such rule"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_SEE_RULE" "an agreed value" "the team keeps it")"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_SEE_RULE: runs;" && expect_has "; agreed: an agreed value" && expect_not "$FAKE_SEE_RULE: agreed;" && ok
  finish
fi

begin "doctor: a rule the org owns is agreed at any value"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "org" "the company plan owns this value")"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && ok
finish

begin "doctor: a rule the org owns stays agreed when the repository sets another value"
if [[ -z "$FAKE_RELAXED" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor relaxed
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "org" "the company plan owns this value")"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && ok
  finish
fi

begin "doctor: a rule agreed by name is agreed whatever its value, when the linter reports no value"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports a value for each rule"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor relaxed
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "an old value" "the team keeps it")"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && expect_not "agreed: an old value" && ok
  finish
fi

begin "doctor: an item of another linter agrees no row"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item "other-linter" "$FAKE_RULE" "off" "the team does not use it")"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: missing;" && expect_not ": agreed;" && ok
finish

begin "doctor: an empty agreed list agrees no row"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed: []"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: missing;" && expect_not ": agreed;" && ok
finish

begin "doctor: a row that cannot verify is never agreed"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor reject
  write_record "agreed:
$(record_item "$FAKE_LINTER" "-" "org" "the team keeps it")"
  run_doctor
  expect_exit 0 && expect_has "cannot verify" && expect_not ": agreed;" && ok
  finish
fi

begin "doctor: file_max_lines still reads beside an agreed list"
write_record "file_max_lines: 100
agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "org" "the company plan owns this value")"
write_src "src/a$FX_EXT" 101
run_lint file-length
expect_exit 0 && expect_has "src/a$FX_EXT: 101 code lines (limit 100, .ldd-lint.yaml)" && ok
finish

begin "doctor: a linter that is not installed cannot verify, never passes"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  run_doctor
  expect_exit 0 && expect_has "$FAKE_LINTER -: cannot verify: $FAKE_BIN is not installed" && expect_not ": runs;" && ok
  finish
fi

begin "doctor: a linter output the doctor cannot read is cannot verify, never a pass"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor garbled
  run_doctor
  expect_exit 0 && expect_has "$FAKE_LINTER -: cannot verify: cannot read" && expect_not ": runs;" && expect_not ": missing;" && ok
  finish
fi

begin "doctor: a linter that rejects the repository's config cannot verify"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor reject
  run_doctor
  expect_exit 0 && expect_has "cannot verify: the linter rejects" && expect_not ": runs;" && ok
  finish
fi

begin "doctor: a config that fails the linter's own check cannot verify"
if [[ -z "$FAKE_CONFIG_CHECK" ]]; then skip "the linter has no config check of its own"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor invalid
  run_doctor
  expect_exit 0 && expect_has "cannot verify: the repository config fails the linter's check: jsonschema" \
    && expect_has "linters-settings" && expect_not ": missing;" && ok
  finish
fi

begin "doctor: a config check that cannot fetch the schema is not a rejection"
if [[ -z "$FAKE_CONFIG_CHECK" ]]; then skip "the linter has no config check of its own"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor noschema
  run_doctor
  expect_exit 0 && expect_not "cannot verify" && expect_has "$FAKE_RULE: $FAKE_RUNS;" && ok
  finish
fi

begin "doctor: --tsv rows have seven fields and the doctor lines go to stderr"
write_src "src/a$FX_EXT" 1; fake_doctor missing
run_doctor --tsv
expect_exit 0 && expect_has "doctor: " \
  && { [[ -n "$OUT" ]] && printf '%s\n' "$OUT" | awk -F'\t' 'NF != 7 { bad = 1 } END { exit bad }' \
       || bad "a row without seven fields"; } \
  && { printf '%s\n' "$OUT" | grep -q "^[a-z]*${TAB}$FAKE_LINTER${TAB}$FAKE_RULE${TAB}missing${TAB}" || bad "no TSV row for $FAKE_RULE"; } \
  && { printf '%s\n' "$ERR" | grep -q '^doctor: ' || bad "the doctor line is not on stderr"; } && ok
finish

begin "doctor never edits a file"
write_src "src/a$FX_EXT" 1; fake_doctor relaxed
before=$(tree_sum)
run_doctor
expect_exit 0 && { [[ "$(tree_sum)" == "$before" ]] || bad "the tree changed"; } && ok
finish

begin "doctor: the installed linter reads the recommended config adopted as the repository's own"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
elif [[ -z "$FAKE_REAL" ]]; then skip "the linter is installed per project, which the matrix cannot do"; finish
elif ! command -v "$FAKE_REAL" >/dev/null 2>&1; then skip "$FAKE_REAL is not on PATH"; finish
else
  write_src "src/a$FX_EXT" 1; real_doctor_adopt
  run_lint doctor
  expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: runs;" && expect_not ": missing;" \
    && expect_not ": limit " && expect_not "cannot verify" && ok
  finish
fi

} # run_row_cases

for ROW in $FX_ROWS; do
  use_row "$ROW"
  run_row_cases
done
ROW=""

# --- row-independent ---
begin "doctor: a tree without a source file is inconclusive (exit 2)"
run_lint doctor
expect_exit 2 && expect_has "no source file in scope" && ok
finish

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
