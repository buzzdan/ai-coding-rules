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
MAX_LINES={{.FileMaxLines}}
WARN_FILES={{.PackageWarnFiles}}
MAX_FILES={{.PackageMaxFiles}}

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

{{include "scripts/ldd-fixture.sh"}}

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
expect_exit 0 && expect_has "profile default ($MAX_LINES code lines)" && expect_has "a setting to propose, never to add on your own: " && ok
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

# ========================= summary =========================
echo
echo "ldd-lint_test: $pass passed, $failed failed, $skipped skipped"
(( failed == 0 ))
