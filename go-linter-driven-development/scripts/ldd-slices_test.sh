#!/usr/bin/env bash
# Fixture matrix for ldd-slices.sh — the slicing step's own conformance test.
#
# Each case writes a slices table under a temp dir, runs the script against it
# with the plugin's own rule files, and asserts the exit code and the lines of
# the printed slices. The cases are the same for every language: the table
# carries paths, not source, so the only language-specific value is the lint
# configuration file name, taken from the fixture rows spliced in below.
#
# Usage:  bash scripts/ldd-slices_test.sh [path/to/ldd-slices.sh]
#         (default: the sibling ldd-slices.sh; the rules come from ../rules
#         beside it, so the test always runs the rendered rule files)
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the script under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SLICES="${1:-$HERE/ldd-slices.sh}"
[[ -f "$SLICES" ]] || { echo "no such script: $SLICES" >&2; exit 2; }
SLICES=$(cd "$(dirname "$SLICES")" && pwd)/$(basename "$SLICES")
RULES=$(cd "$(dirname "$SLICES")/../rules" && pwd)

pass=0 failed=0
CASE=""
OUT="" ERR="" CODE=0
ROW=""
REPO=""
TAB=$'\t'
E='.go'

# ---------- harness ----------
begin() { CASE="$1"; REPO=$(mktemp -d); }
finish() { rm -rf "$REPO"; }

line() { # <rule> <move> <files> <anchor> — appends one table line
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$REPO/slices.tsv"
}
run_slices() { # [options...] — runs the script over $REPO/slices.tsv
  OUT=$(cd "$REPO" && bash "$SLICES" "$@" slices.tsv 2>"$REPO/.stderr"); CODE=$?
  ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"
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
expect_count() { # <pattern> <n> — lines of stdout matching the pattern
  local got; got=$(printf '%s\n' "$OUT" | grep -c -- "$1")
  (( got == $2 )) || { bad "expected $2 line(s) matching '$1', got $got"; return 1; }
}
move_line() { # <n> — the n-th MOVE line of stdout
  printf '%s\n' "$OUT" | grep '^MOVE ' | sed -n "${1}p"
}
slice_block() { # <n> — the lines of slice n, header to RULE
  printf '%s\n' "$OUT" | awk -v n="$1" '/^== slice /{p = ($3 == n)} p'
}

# ---------- fixture rows: the Go row this script's language block serves ----------
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
FX_ROWS="go"

use_row() {
  FX_GLOB='*.go'
  FX_SRC_FILE="services/worker.go"
  FX_SUPPRESS_LINE='var cache = map[string]string{} //nolint:gochecknoglobals // TODO'
  FX_LINT_CONFIG='.golangci.yaml'
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

# fx_verify_commands — the row's test, lint, build and vet forms, one per line:
# the commands the worker's hook must send through the wrapper
fx_verify_commands() {
  printf '%s\n' "go test ./..." "go test -run TestX ./internal/..." "golangci-lint run" "golangci-lint run ./..." "go build ./..." "go vet ./..."
}
# fx_lint_delta_expected <base> <files...> — the lint-over-the-delta command for the row
fx_lint_delta_expected() {
  printf 'golangci-lint run --allow-parallel-runners --new-from-rev=%s ./internal/models ./internal/services\n' "$1"
}

for ROW in $FX_ROWS; do use_row "$ROW"; break; done
ROW=""

# ========================= cases =========================

begin "1 moves over disjoint files are two slices"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "b/two$E" "b/two$E:20"
run_slices
expect_exit 0 && expect_has "2 lines → 2 slices" && expect_has "== slice 1 (wave 1) 1 file, 1 move" && expect_has "== slice 2 (wave 1) 1 file, 1 move" && ok
finish

begin "2 moves that share a file are one slice with two moves"
line R3 "Extract Function" "a/one$E a/one_test$E" "a/one$E:10"
line R1 "Replace Primitive with Domain Type" "a/one$E a/types$E" "a/one$E:30"
run_slices
expect_exit 0 && expect_has "2 lines → 1 slice in 1 wave" && expect_has "== slice 1 (wave 1) 3 files, 2 moves" && expect_has "MOVE 2:" && ok
finish

begin "3 the moves of a slice are ordered by the sequencing table, not by input order"
line R1 "Replace Primitive with Domain Type" "a/one$E" "a/one$E:30"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
run_slices
expect_exit 0 && { [[ "$(move_line 1)" == "MOVE 1: Extract Function — R3 — a/one$E:10" ]] || bad "MOVE 1 is '$(move_line 1)'"; } \
  && [[ "$(move_line 2)" == "MOVE 2: Replace Primitive with Domain Type — R1 — a/one$E:30" ]] && ok
finish

begin "4 Extract Clean Island sorts before Push the Global Up One Level, and a Demote after both"
line R4 "Demote (rung 1)" "a/one$E" "a/one$E:5"
line R8 "Push the Global Up One Level" "a/one$E a/main$E" "a/one$E:12"
line R8 "Extract Clean Island" "a/one$E" "a/one$E:12"
run_slices
expect_exit 0 && { [[ "$(move_line 1)" == MOVE\ 1:\ Extract\ Clean\ Island* ]] || bad "MOVE 1 is '$(move_line 1)'"; } \
  && { [[ "$(move_line 2)" == MOVE\ 2:\ Push\ the\ Global* ]] || bad "MOVE 2 is '$(move_line 2)'"; } \
  && [[ "$(move_line 3)" == MOVE\ 3:\ Demote* ]] && ok
finish

begin "5 a chain of shared files over six files is one large slice with every file sorted"
line R3 "Extract Function" "p/f$E p/e$E" "p/f$E:1"
line R3 "Extract Function" "p/e$E p/d$E" "p/e$E:1"
line R3 "Extract Function" "p/d$E p/c$E" "p/d$E:1"
line R3 "Extract Function" "p/c$E p/b$E" "p/c$E:1"
line R3 "Extract Function" "p/b$E p/a$E" "p/b$E:1"
run_slices
expect_exit 0 && expect_has "1 slice in 1 wave (1 large" && expect_has "== slice 1 (wave 1) 6 files, 5 moves, large" \
  && expect_has "FILES: p/a$E p/b$E p/c$E p/d$E p/e$E p/f$E" && ok
finish

begin "6 RULE: is printed once per rule, and R1 and R10 resolve to their own files"
line R1 "Replace Primitive with Domain Type" "a/one$E" "a/one$E:30"
line R10 "Inject the Exit Path" "a/one$E" "a/one$E:40"
line R1 "Name enum strings" "a/one$E" "a/one$E:50"
run_slices
expect_exit 0 && expect_count '^RULE: ' 2 && expect_has "RULE: $RULES/R1-" && expect_has "RULE: $RULES/R10-" && ok
finish

begin "7 a line with three fields is refused with its line number"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
printf 'R3\tExtract Function\ta/two%s\n' "$E" >> "$REPO/slices.tsv"
run_slices
expect_exit 2 && expect_has "line 2:" && ok
finish

begin "8 an empty table prints nothing to slice"
: > "$REPO/slices.tsv"
run_slices
expect_exit 0 && expect_has "nothing to slice" && ok
finish

begin "9 CRLF line ends and a trailing blank line are ignored"
printf 'R3\tExtract Function\ta/one%s\ta/one%s:10\r\n\r\n\n' "$E" "$E" > "$REPO/slices.tsv"
run_slices
expect_exit 0 && expect_has "1 line → 1 slice" && { ! printf '%s' "$OUT" | grep -q $'\r' || bad "a CR in the output"; } && ! printf '%s' "$OUT" | grep -q $'\r' && ok
finish

begin "10 an exact duplicate line is dropped and counted"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
run_slices
expect_exit 0 && expect_has "1 duplicate line dropped" && expect_has "1 file, 1 move" && ok
finish

begin "11 a missing rules directory is a usage error"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
run_slices --rules "$REPO/no-rules"
expect_exit 2 && expect_has "no-rules" && ok
finish

begin "12 a rule with no file is refused"
line R99 "Extract Function" "a/one$E" "a/one$E:10"
run_slices
expect_exit 2 && expect_has "R99" && ok
finish

begin "13 a quoted path, a fifth field and a rule not R<n> are three line messages"
printf 'R3\tExtract Function\t"a/my file%s"\ta/my file%s:10\n' "$E" "$E" > "$REPO/slices.tsv"
printf 'R3\tExtract Function\ta/one%s\ta/one%s:10\tsmall\n' "$E" "$E" >> "$REPO/slices.tsv"
printf 'X3\tExtract Function\ta/two%s\ta/two%s:10\n' "$E" "$E" >> "$REPO/slices.tsv"
run_slices
expect_exit 2 && { (( $(printf '%s\n' "$ERR" | grep -c 'line [0-9]*:') == 3 )) || bad "expected three line messages"; } \
  && expect_has "line 1:" && expect_has "line 2:" && expect_has "line 3:" && ok
finish

begin "14 --order prints the sequencing keys"
run_slices --order
expect_exit 0 && expect_has "extract function named" && expect_has "move method" && ok
finish

begin "15 every sequencing key is a substring of a move bullet in the rule files (drift guard)"
run_slices --order
missing=""
while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  grep -hi '^- \*\*' "$RULES"/R*.md | grep -qiF -- "$key" || missing="$missing [$key]"
done <<< "$OUT"
expect_exit 0 && { [[ -z "$missing" ]] || bad "keys with no bullet:$missing"; } && [[ -z "$missing" ]] && ok
finish

begin "16 a move name that matches no key and no bullet is refused, and the keys are printed"
line R3 "Make it nicer" "a/one$E" "a/one$E:10"
run_slices
expect_exit 2 && expect_has "Make it nicer" && expect_has "extract function named" && ok
finish

begin "17 slices are numbered by first appearance"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "b/two$E" "b/two$E:20"
line R3 "Replace Nesting with Early Returns" "a/one$E" "a/one$E:40"
run_slices
expect_exit 0 && expect_has "== slice 1 (wave 1) 1 file, 2 moves" && { slice_block 2 | grep -q "^FILES: b/two$E\$" || bad "slice 2 is not b/two"; } \
  && slice_block 2 | grep -q "^FILES: b/two$E\$" && ok
finish

begin "18 a lint configuration file in a slice is refused"
line R3 "Extract Function" "a/one$E $FX_LINT_CONFIG" "a/one$E:10"
run_slices
expect_exit 2 && expect_has "lint configuration" && expect_has "$FX_LINT_CONFIG" && ok
finish

begin "19 two slices in different packages share wave 1"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "b/two$E" "b/two$E:20"
run_slices
expect_exit 0 && expect_has "in 1 wave" && expect_count '(wave 1)' 2 && ok
finish

begin "20 two slices with disjoint files in one package take waves 1 and 2"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "a/two$E" "a/two$E:20"
run_slices
expect_exit 0 && expect_has "in 2 waves" && expect_has "== slice 1 (wave 1)" && expect_has "== slice 2 (wave 2)" \
  && expect_has "-- wave 1" && expect_has "-- wave 2" && ok
finish

begin "21 three slices, two in one package: two waves, the odd one in wave 1"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "b/two$E" "b/two$E:20"
line R3 "Extract Function" "a/three$E" "a/three$E:30"
run_slices
expect_exit 0 && expect_has "3 slices in 2 waves" && expect_has "== slice 2 (wave 1)" && expect_has "== slice 3 (wave 2)" \
  && { printf '%s\n' "$OUT" | grep -n '^-- wave\|^== slice' | tr '\n' ' ' | grep -q -- '-- wave 1 .*== slice 1 .*== slice 2 .*-- wave 2 .*== slice 3' || bad "slices not printed under their waves"; } \
  && printf '%s\n' "$OUT" | grep -n '^-- wave\|^== slice' | tr '\n' ' ' | grep -q -- '-- wave 1 .*== slice 1 .*== slice 2 .*-- wave 2 .*== slice 3' && ok
finish

begin "22 --waves 0 puts every slice in wave 1"
line R3 "Extract Function" "a/one$E" "a/one$E:10"
line R3 "Extract Function" "a/two$E" "a/two$E:20"
run_slices --waves 0
expect_exit 0 && expect_has "2 slices in 1 wave" && expect_count '(wave 1)' 2 && ok
finish

begin "23 PKGS: lists the directories of the slice's files, sorted and once each"
line R3 "Extract Function" "internal/services/x$E internal/services/x_test$E internal/models/t$E" "internal/services/x$E:1"
run_slices
expect_exit 0 && expect_has "PKGS: internal/models internal/services" && ok
finish

# ========================= summary =========================
echo
echo "ldd-slices_test: $pass passed, $failed failed"
(( failed == 0 ))
