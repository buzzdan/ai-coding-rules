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

# No test reads the machine's own installed plugins: an installed plugin
# written for a language changes what the generic doctor does.
NO_PLUGINS=$(mktemp)
printf '{ "version": 2, "plugins": {} }\n' > "$NO_PLUGINS"
export LDD_INSTALLED_PLUGINS="$NO_PLUGINS"

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

{{include "scripts/ldd-lint-langs.sh"}}

{{include "scripts/ldd-lint-fakes.sh"}}

# run_doctor [options...] — runs the doctor over $REPO with only the fakes in
# $REPO/.bin and the system directories on PATH, so an installed linter never
# answers for a fake
run_doctor() {
  local errf; errf=$(mktemp)
  OUT=$(cd "$REPO" && PATH="$REPO/.bin:/usr/bin:/bin" "$BASH" "$LINT" doctor "$@" --root . 2>"$errf"); CODE=$?
  ERR=$(cat "$errf"); rm -f "$errf"
}

# run_brief [options...] — runs doctor --brief over $REPO, with the doctor's PATH
run_brief() {
  local errf; errf=$(mktemp)
  OUT=$(cd "$REPO" && PATH="$REPO/.bin:/usr/bin:/bin" "$BASH" "$LINT" doctor --brief "$@" --root . 2>"$errf"); CODE=$?
  ERR=$(cat "$errf"); rm -f "$errf"
}

# brief_line <dir> <what differs> — the line --brief prints for a project
brief_line() { printf '⚙️ Lint setup (%s): %s — run /{{.CmdPrefix}}-setup' "$1" "$2"; }

# linter_not_called — exit 0 when the fake linter of the run was not called (only one
# fake logs its calls); the other fakes cannot tell, so they pass
linter_not_called() { [[ ! -e "$REPO/.bin/calls.log" ]]; }

# write_record <yaml body> — the agreement record of the repository
write_record() { printf '%s\n' "$1" > "$REPO/.ldd-lint.yaml"; }

# record_item <linter> <rule> <value> <reason> — one item line, as the
# record writes it: a double-quoted scalar with a backslash and a quote escaped
record_item() {
  local t="$1 $2 = $3 | $4"
  t=${t//\\/\\\\}; t=${t//\"/\\\"}
  printf '  - "%s"\n' "$t"
}

# names_linter — an item of "agreed" that names the row's linter and agrees no
# row, so a --brief run counts the linter's rows and nothing else changes
names_linter() { record_item "$FAKE_LINTER" "ldd-test-no-rule" "org" "the record names the linter"; }

# doctor_field <rule> <field number> — one field of the doctor's TSV row
doctor_field() { printf '%s\n' "$OUT" | awk -F'\t' -v r="$1" -v n="$2" '$3 == r { print $n; exit }'; }

# run_agree [options...] — runs the agree subcommand over $REPO with the doctor's fakes
run_agree() {
  local errf; errf=$(mktemp)
  OUT=$(cd "$REPO" && PATH="$REPO/.bin:/usr/bin:/bin" "$BASH" "$LINT" agree "$@" --root . 2>"$errf"); CODE=$?
  ERR=$(cat "$errf"); rm -f "$errf"
}

# record_read <function> [args...] — runs a record reader of the script over
# the record in $REPO, so a test reads a line back as the doctor reads it
record_read() {
  ( cd "$REPO" && OVERRIDE_FILE=.ldd-lint.yaml \
    && eval "$(sed -n '/^record_has() {/,/^}/p;/^record_items() {/,/^}/p;/^record_agreed() {/,/^}/p;/^record_linters() {/,/^}/p' "$LINT")" \
    && "$@" )
}

# expect_out <text> — stdout is exactly that text
expect_out() { [[ "$OUT" == "$1" ]] || { bad "expected output: $1"; return 1; }; }

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

begin "agree prints the record line with the doctor's current value"
write_src "src/a$FX_EXT" 1; fake_doctor relaxed
run_doctor --tsv
cur=$(doctor_field "$FAKE_RULE" 6)
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason "the team keeps it"
expect_exit 0 && expect_out "$(record_item "$FAKE_LINTER" "$FAKE_RULE" "$cur" "the team keeps it")" && ok
finish

begin "agree off and org print the decision as the value"
write_src "src/a$FX_EXT" 1; fake_doctor relaxed
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision off --reason "the team does not use it"
off_ok=0; expect_exit 0 && expect_out "$(record_item "$FAKE_LINTER" "$FAKE_RULE" off "the team does not use it")" && off_ok=1
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision org --reason "the company plan owns it"
(( off_ok )) && expect_exit 0 && expect_out "$(record_item "$FAKE_LINTER" "$FAKE_RULE" org "the company plan owns it")" && ok
finish

begin "a record line with : # | quote and backslash reads back unchanged"
write_src "src/a$FX_EXT" 1; fake_doctor relaxed
run_doctor --tsv
cur=$(doctor_field "$FAKE_RULE" 6)
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason 'a: b # c | "d" \e'
write_record "agreed:
$OUT"
want="$FAKE_LINTER $FAKE_RULE = $cur | "'a: b # c / "d" \e'
got=$(record_read record_items agreed); val=$(record_read record_agreed "$FAKE_LINTER" "$FAKE_RULE")
expect_exit 0 && { [[ "$got" == "$want" ]] || bad "read back: $got"; } \
  && { [[ "$val" == "$cur" ]] || bad "value read back: $val"; } && ok
finish

begin "agree writes a line the doctor accepts: the row turns agreed"
if [[ -z "$FAKE_RELAXED" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor relaxed
  run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason 'a: b # c | "d" \e'
  write_record "agreed:
$OUT"
  run_doctor
  expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && ok
  finish
fi

begin "agree: a rule that runs and is kept as it is turns the row agreed"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason "the team keeps it"
write_record "agreed:
$OUT"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && ok
finish

begin "agree: current on a rule that does not run is exit 2 and says to use off"
write_src "src/a$FX_EXT" 1; fake_doctor missing
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason "the team keeps it"
expect_exit 2 && expect_has "does not run" && expect_has "--decision off" && [[ -z "$OUT" ]] && ok
finish

begin "agree: off on a rule that does not run turns the row agreed"
write_src "src/a$FX_EXT" 1; fake_doctor missing
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision off --reason "the team does not use it"
write_record "agreed:
$OUT"
run_doctor
expect_exit 0 && expect_has "$FAKE_RULE: agreed;" && ok
finish

begin "agree --fingerprint notes a linter with no compared config file and exits 0"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  rm -f "$REPO/$FAKE_CONFIG"
  run_agree --fingerprint
  expect_exit 0 && [[ -z "$OUT" ]] && expect_has "no config file of $FAKE_LINTER was compared" && ok
  finish
fi

begin "agree --linters prints the linter of the run as one item"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linters
expect_exit 0 && expect_out "  - \"$FAKE_LINTER\"" && ok
finish

begin "agree --linters prints the line although the repository drifts from the recommended config"
write_src "src/a$FX_EXT" 1; fake_doctor missing
run_agree --linters
expect_exit 0 && expect_out "  - \"$FAKE_LINTER\"" && ok
finish

begin "agree --linters skips a linter that cannot verify, with a note, and exits 0"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  run_agree --linters
  expect_exit 0 && [[ -z "$OUT" ]] && expect_has "agree: no linter of this run could be checked, so there is no linters line" \
    && expect_has "$FAKE_LINTER" && ok
  finish
fi

begin "agree --linters never edits a file"
write_src "src/a$FX_EXT" 1; fake_doctor missing
before=$(tree_sum)
run_agree --linters
expect_exit 0 && { [[ "$(tree_sum)" == "$before" ]] || bad "the tree changed"; } && ok
finish

begin "agree --linters does not combine with the other agree options (exit 2)"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
: > "$REPO/x.cfg"
r1=1
run_agree --linters --fingerprint; expect_exit 2 && expect_has "agree takes one of" && [[ -z "$OUT" ]] || r1=0
run_agree --linters --lint-config "$FAKE_LINTER" x.cfg; expect_exit 2 && expect_has "agree takes one of" || r1=0
run_agree --linters --rule "$FAKE_RULE"; expect_exit 2 && expect_has "agree takes one of" || r1=0
run_agree --linters --linter "$FAKE_LINTER"; expect_exit 2 && expect_has "agree takes one of" || r1=0
run_agree --linters --decision off --reason why; expect_exit 2 && expect_has "agree takes one of" || r1=0
(( r1 )) && ok
finish

begin "doctor --linters is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_doctor --linters
expect_exit 2 && expect_has "only agree takes: --linters" && ok
finish

begin "the linters record key is read back by record_linters"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linters
write_record "agreed: []
linters:
$OUT"
got=$(record_read record_linters)
[[ "$got" == "$FAKE_LINTER" ]] && ok || bad "read: $got"
finish

begin "record_linters reads the linters key with the items of the other keys, once each"
write_record "agreed:
  - \"b-linter r = 1 | why\"
lint_fingerprint:
  - \"a-linter x.cfg 0000\"
linters:
  - \"c-linter\"
  - \"a-linter\"
  - \"b-linter\""
got=$(record_read record_linters | tr '\n' ' ')
[[ "$got" == "a-linter b-linter c-linter " ]] && ok || bad "read: $got"
finish

begin "agree for a rule with no row is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linter "$FAKE_LINTER" --rule no-such-rule --decision off --reason "typo"
expect_exit 2 && expect_has "no doctor row for $FAKE_LINTER no-such-rule" && [[ -z "$OUT" ]] && ok
finish

begin "agree with an unknown decision, an empty reason or a missing option is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision maybe --reason "why"
r1=0 r2=0
expect_exit 2 && expect_has "decision" && expect_has "maybe" && r1=1
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision off --reason ""
expect_exit 2 && expect_has "reason" && r2=1
run_agree --linter "$FAKE_LINTER" --decision off --reason "why"
(( r1 && r2 )) && expect_exit 2 && expect_has "--rule" && ok
finish

begin "agree for a linter that cannot verify is exit 2 and names the cause"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision off --reason "why"
  expect_exit 2 && expect_has "cannot verify: $FAKE_BIN is not " && [[ -z "$OUT" ]] && ok
  finish
fi

begin "agree replaces every | of a reason, so the value stays the first part"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision off --reason "a | | b | c"
expect_exit 0 && expect_out "  - \"$FAKE_LINTER $FAKE_RULE = off | a / / b / c\"" && ok
finish

begin "agree --fingerprint prints one hash per compared config"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint
  expect_exit 0 && expect_out "  - \"$FAKE_LINTER $FAKE_CONFIG $(git hash-object "$REPO/$FAKE_CONFIG")\"" && ok
  finish
fi

begin "agree --fingerprint falls back to the checksum when git cannot hash"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  mkdir -p "$REPO/.bin"; printf '#!/bin/sh\nexit 1\n' > "$REPO/.bin/git"; chmod +x "$REPO/.bin/git"
  run_agree --fingerprint
  sum=$(cksum < "$REPO/$FAKE_CONFIG" | cut -d' ' -f1)
  expect_exit 0 && expect_out "  - \"$FAKE_LINTER $FAKE_CONFIG $sum\"" && ok
  finish
fi

begin "agree --fingerprint for a linter that cannot verify is exit 2"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  run_agree --fingerprint
  expect_exit 2 && expect_has "cannot verify: $FAKE_BIN is not " && ok
  finish
fi

begin "doctor --config compares that file"
write_src "src/a$FX_EXT" 1; fake_doctor missing; fake_doctor_strict strict-cfg
run_doctor
r1=0; expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: missing;" && r1=1
run_doctor --config strict-cfg
(( r1 )) && expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: $FAKE_RUNS;" && expect_not ": missing;" \
  && expect_has "the chosen config strict-cfg" && ok
finish

begin "doctor: a lint_config item makes the doctor compare that file"
write_src "src/a$FX_EXT" 1; fake_doctor missing; fake_doctor_strict strict-cfg
write_record "lint_config:
  - \"$FAKE_LINTER strict-cfg\""
run_doctor
expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: $FAKE_RUNS;" && expect_not ": missing;" \
  && expect_has "the chosen config strict-cfg" && ok
finish

begin "doctor: a lint_config item of a linter the run does not report is ignored"
write_src "src/a$FX_EXT" 1; fake_doctor missing; fake_doctor_strict strict-cfg
write_record "lint_config:
  - \"other-linter strict-cfg\""
run_doctor
expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: missing;" && expect_not "strict-cfg" && ok
finish

begin "doctor --config overrides a lint_config item"
write_src "src/a$FX_EXT" 1; fake_doctor missing; fake_doctor_strict strict-cfg; : > "$REPO/weak-cfg"
write_record "lint_config:
  - \"$FAKE_LINTER strict-cfg\""
run_doctor --config weak-cfg
expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: missing;" && expect_has "the chosen config weak-cfg" && ok
finish

begin "doctor: a lint_config item whose path is not a file cannot verify"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "lint_config:
  - \"$FAKE_LINTER no-such.cfg\""
run_doctor
expect_exit 0 && expect_has "$FAKE_LINTER -: cannot verify: the agreed config no-such.cfg does not exist" && expect_not ": runs;" && ok
finish

begin "doctor: the linter's own config check reads the chosen file"
if [[ -z "$FAKE_CONFIG_CHECK" ]]; then skip "the linter has no config check of its own"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor invalid; fake_doctor_strict strict-cfg
  run_doctor --config strict-cfg
  expect_exit 0 && expect_not "cannot verify" && expect_has "$FAKE_RULE: $FAKE_RUNS;" \
    && { grep -q 'config verify -c strict-cfg' "$REPO/.bin/calls.log" || bad "the check did not get the chosen file"; } && ok
  finish
fi

begin "agree reads the rows of the chosen file"
write_src "src/a$FX_EXT" 1; fake_doctor missing; fake_doctor_strict strict-cfg
run_doctor --tsv --config strict-cfg
cur=$(doctor_field "$FAKE_RULE" 6)
run_agree --config strict-cfg --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason "the team keeps it"
expect_exit 0 && expect_out "$(record_item "$FAKE_LINTER" "$FAKE_RULE" "$cur" "the team keeps it")" && ok
finish

begin "agree --fingerprint prints the chosen file and the repository's own config"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt; fake_doctor_strict strict-cfg
  run_agree --fingerprint --config strict-cfg
  want="  - \"$FAKE_LINTER strict-cfg $(git hash-object "$REPO/strict-cfg")\"
  - \"$FAKE_LINTER $FAKE_CONFIG $(git hash-object "$REPO/$FAKE_CONFIG")\""
  expect_exit 0 && expect_out "$want" && ok
  finish
fi

begin "agree --fingerprint with a lint_config item prints both files too"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt; fake_doctor_strict strict-cfg
  write_record "lint_config:
  - \"$FAKE_LINTER strict-cfg\""
  run_agree --fingerprint
  expect_exit 0 && expect_out "$want" && ok
  finish
fi

begin "agree --fingerprint prints one line when the chosen file is the repository's own config"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint --config "$FAKE_CONFIG"
  expect_exit 0 && expect_out "  - \"$FAKE_LINTER $FAKE_CONFIG $(git hash-object "$REPO/$FAKE_CONFIG")\"" && ok
  finish
fi

begin "doctor: a config changed since the agreement is named"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint
  write_record "lint_fingerprint:
$OUT"
  printf '# edited\n' >> "$REPO/$FAKE_CONFIG"
  run_doctor
  expect_exit 0 && { printf '%s\n' "$ERR" | grep -qx "doctor: $FAKE_CONFIG changed since the setup was agreed" \
    || bad "no change line on stderr"; } && ok
  finish
fi

begin "doctor: a config that is gone since the agreement is named"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint
  write_record "lint_fingerprint:
$OUT"
  rm -f "$REPO/$FAKE_CONFIG"
  run_doctor
  expect_exit 0 && expect_has "doctor: $FAKE_CONFIG changed since the setup was agreed" && ok
  finish
fi

begin "doctor: an unchanged config prints no change line"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint
  write_record "lint_fingerprint:
$OUT"
  run_doctor
  expect_exit 0 && expect_not "changed since" && ok
  finish
fi

begin "doctor: a fingerprint of a linter the run does not report is ignored"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "lint_fingerprint:
  - \"other-linter $FAKE_CONFIG 0000\""
run_doctor
expect_exit 0 && expect_not "changed since" && ok
finish

begin "agree --fingerprint prints no line for a linter that reports its settings"
if [[ -n "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports no setting, so its drift shows through the fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt; fake_doctor_strict strict-cfg
  run_agree --fingerprint
  r1=0; expect_exit 0 && expect_out "" && expect_not "no config file of" && r1=1
  run_agree --fingerprint --config strict-cfg
  (( r1 )) && expect_exit 0 && expect_out "" && expect_not "no config file of" && ok
  finish
fi

begin "doctor: a fingerprint item of a linter that reports its settings is ignored"
if [[ -n "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports no setting, so its drift shows through the fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  write_record "lint_fingerprint:
  - \"$FAKE_LINTER $FAKE_CONFIG 0000\"
agreed: []"
  printf '\n' >> "$REPO/$FAKE_CONFIG"
  run_doctor
  r1=0; expect_exit 0 && expect_not "changed since" && r1=1
  run_brief
  (( r1 )) && expect_exit 0 && expect_out "" && ok
  finish
fi

begin "doctor: a record line that matches no row is named in a warning"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "agreed:
$(record_item "$FAKE_LINTER" "no-such-rule" "off" "a typo")
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "org" "the company plan owns this value")"
run_doctor --tsv
expect_exit 0 && expect_has "doctor: .ldd-lint.yaml: no row for $FAKE_LINTER no-such-rule; the line is ignored" \
  && expect_not "no row for $FAKE_LINTER $FAKE_RULE;" \
  && { [[ "$(printf '%s\n' "$OUT" | awk -F'\t' '$4 == "agreed"' | wc -l | tr -d ' ')" == 1 ]] || bad "another row turned agreed"; } \
  && { printf '%s\n' "$ERR" | grep -q '^doctor: .ldd-lint.yaml: no row' || bad "the warning is not on stderr"; } && ok
finish

begin "doctor: a record line of a linter the run does not report is not warned about"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "agreed:
$(record_item "other-linter" "$FAKE_RULE" "off" "the team does not use it")"
run_doctor
expect_exit 0 && expect_not "no row for" && ok
finish

begin "doctor: a linter that cannot verify gets no warning for its record lines"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "off" "the team does not use it")"
  run_doctor
  expect_exit 0 && expect_has "cannot verify" && expect_not "no row for" && ok
  finish
fi

begin "doctor: a linter that is not installed cannot verify, never passes"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  run_doctor
  expect_exit 0 && expect_has "$FAKE_LINTER -: cannot verify: $FAKE_BIN is not " && expect_not ": runs;" && ok
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

begin "doctor: a config above the project is named relative to the project"
if [[ -z "$FAKE_ABOVE" ]]; then skip "the linter looks for its config in the project only"; finish
else
  real=$REPO; REPO="$real/svc"; mkdir -p "$REPO"
  write_src "src/a$FX_EXT" 1; fake_doctor adopt; fake_doctor_config_above
  up=$(cd "$real" && pwd -P)
  run_doctor
  r1=0; expect_exit 0 && expect_has "../$FAKE_CONFIG" && expect_not "$up/$FAKE_CONFIG" && r1=1
  if (( r1 )) && [[ -n "$FAKE_NO_SETTINGS" ]]; then
    run_agree --fingerprint
    expect_exit 0 && expect_out "  - \"$FAKE_LINTER ../$FAKE_CONFIG $(git hash-object "$real/$FAKE_CONFIG")\"" || r1=0
  fi
  (( r1 )) && ok
  REPO=$real; finish
fi

begin "doctor: the note names the linter binary the doctor ran"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_doctor
expect_exit 0 && expect_has "$FAKE_BIN_NOTE" && ok
finish

begin "doctor: a linter only in the project's virtual environment cannot verify and says to put it on PATH"
if [[ -z "$FAKE_VENV" ]]; then skip "the linter of this language has no virtual environment"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  mkdir -p "$REPO/$(dirname "$FAKE_VENV")" && mv "$REPO/.bin" "$REPO/$FAKE_VENV"
  run_doctor
  expect_exit 0 && expect_has "cannot verify: $FAKE_BIN is not on PATH; put the project's $FAKE_BIN on PATH (for example, activate the project's virtual environment) and run again" \
    && expect_not ": runs;" && ok
  finish
fi

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

# --- doctor --brief ---
begin "--brief says nothing for a project with no record"
write_src "src/a$FX_EXT" 1; fake_doctor missing
run_brief
expect_exit 0 && expect_out "" && expect_not "doctor:" && linter_not_called && ok
finish

begin "--brief says nothing when every row runs or is agreed"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "org" "the company plan owns this value")"
run_brief
expect_exit 0 && expect_out "" && expect_not "doctor:" && ok
finish

begin "--brief names the count of rules not agreed"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(names_linter)"
run_brief
expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
finish

begin "--brief counts a missing rule and a changed config as two differences"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor missing
  run_agree --fingerprint
  write_record "agreed: []
lint_fingerprint:
$OUT"
  printf '# edited\n' >> "$REPO/$FAKE_CONFIG"
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "2 rules differ from what the team agreed")" && ok
  finish
fi

begin "--brief counts a changed config"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint
  write_record "agreed: []
lint_fingerprint:
$OUT"
  printf '# edited\n' >> "$REPO/$FAKE_CONFIG"
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
  finish
fi

begin "--brief says nothing for an unchanged config"
if [[ -z "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports its settings, so it has no fingerprint"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor adopt
  run_agree --fingerprint
  write_record "agreed: []
lint_fingerprint:
$OUT"
  run_brief
  expect_exit 0 && expect_out "" && ok
  finish
fi

begin "--brief does not count a missing rule that is agreed off"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "off" "the team does not use it")"
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief counts a drifted agreed rule, whose state is not agreed"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "7" "the team keeps seven")"
run_brief
expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
finish

begin "--brief counts a rule agreed off that now runs, whatever its state"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "agreed:
$(record_item "$FAKE_LINTER" "$FAKE_RULE" "off" "the team does not use it")"
run_doctor --tsv
expect_has "${TAB}runs${TAB}" && expect_has "; agreed: off" \
  && { run_brief; expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")"; } && ok
finish

begin "--brief does not count limit stricter"
if [[ -z "$FAKE_TIGHTENED" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor tightened
  write_record "agreed:
$(names_linter)"
  run_doctor
  expect_has "$FAKE_TIGHTENED" && { run_brief; expect_exit 0 && expect_out ""; } && ok
  finish
fi

begin "--brief does not count options that differ"
if [[ -z "$FAKE_OPTIONS" ]]; then skip "the linter reports no such options"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor optsdiffer
  write_record "agreed:
$(names_linter)"
  run_doctor
  expect_has "$FAKE_OPTIONS" && { run_brief; expect_exit 0 && expect_out ""; } && ok
  finish
fi

begin "--brief does not count a rule that is named in the config"
case " $FAKE_FORMATS " in
  *" toml "*)
    write_src "src/a$FX_EXT" 1; fake_doctor toml
    # every row the doctor lists as missing is agreed off, so only the named row is left
    agreed_all="agreed:"
    while IFS=$'\t' read -r r_linter r_rule; do
      agreed_all="$agreed_all
$(record_item "$r_linter" "$r_rule" "off" "the team does not use it")"
    done < <(cd "$REPO" && PATH="$REPO/.bin:/usr/bin:/bin" "$BASH" "$LINT" doctor --tsv --root . 2>/dev/null | awk -F'\t' '$4 == "missing" { print $2 "\t" $3 }')
    write_record "$agreed_all"
    run_doctor --tsv
    expect_has "${TAB}named${TAB}" && { run_brief; expect_exit 0 && expect_out ""; } && ok ;;
  *) skip "the language's linter has no named rows" ;;
esac
finish

begin "a project with a record below a root without one gets its line, the root none"
real=$REPO; REPO="$real/sub"; mkdir -p "$REPO"
write_src "src/a$FX_EXT" 1; fake_doctor missing
REPO=$real
[[ ! -d "$real/sub/.bin" ]] || mv "$real/sub/.bin" "$real/.bin"
write_src "src/b$FX_EXT" 1
write_record "agreed:
$(names_linter)"; mv "$REPO/.ldd-lint.yaml" "$REPO/sub/.ldd-lint.yaml"
( cd "$REPO" && git init -q . && git add -A ) >/dev/null 2>&1
run_brief
expect_exit 0 && expect_out "$(brief_line sub/ "1 rule differs from what the team agreed")" && ok
finish

begin "a project with a record below a root without git is found too"
real=$REPO; REPO="$real/sub"; mkdir -p "$REPO"
write_src "src/a$FX_EXT" 1; fake_doctor missing
REPO=$real
[[ ! -d "$real/sub/.bin" ]] || mv "$real/sub/.bin" "$real/.bin"
printf 'agreed:\n%s\n' "$(names_linter)" > "$REPO/sub/.ldd-lint.yaml"
run_brief
expect_exit 0 && expect_out "$(brief_line sub/ "1 rule differs from what the team agreed")" && ok
finish

begin "--brief with no linter on PATH names the project and exits 0"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  write_record "agreed:
$(names_linter)"
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "the linter cannot check this project")" && ok
  finish
fi

begin "--brief names a linter that cannot check before it counts rules"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor reject
  write_record "agreed:
$(names_linter)"
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "the linter cannot check this project")" && ok
  finish
fi

begin "--brief says nothing for a record with no item of the linter"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed: []"
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief says nothing for a record that names only another linter"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(record_item other-linter some-rule off "another plugin's decision")
lint_fingerprint:
  - \"other-linter other.cfg 0000\"
lint_config:
  - \"other-linter other.cfg\""
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief says nothing about a linter that cannot check when no item names it"
if [[ -z "$FAKE_BIN" ]]; then skip "the doctor runs no linter for this language"; finish
else
  write_src "src/a$FX_EXT" 1
  write_record "agreed:
$(record_item other-linter some-rule off "another plugin's decision")"
  run_brief
  expect_exit 0 && expect_out "" && ok
  finish
fi

begin "--brief counts the rows of a linter that only a lint_config item names"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed: []
lint_config:
  - \"$FAKE_LINTER $FAKE_CONFIG\""
run_brief
expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
finish

begin "--brief says nothing when the record names the linter and every row runs"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
run_agree --linters
write_record "agreed: []
linters:
$OUT"
run_brief
expect_exit 0 && expect_out "" && expect_not "doctor:" && ok
finish

begin "--brief counts a missing rule when the record names the linter and agrees no rule"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed: []
linters:
  - \"$FAKE_LINTER\""
run_brief
expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
finish

begin "--brief counts a looser limit when the record names the linter and agrees no rule"
if [[ -z "$FAKE_RELAXED" || -n "$FAKE_NO_SETTINGS" ]]; then skip "the linter reports no setting to compare"; finish
else
  write_src "src/a$FX_EXT" 1; fake_doctor relaxed
  write_record "agreed: []
linters:
  - \"$FAKE_LINTER\""
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
  finish
fi

begin "--brief says nothing for a record that agrees no rule and has no linters key"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed: []"
run_brief
expect_exit 0 && expect_out "" && linter_not_called && ok
finish

begin "--brief says nothing for a linters key with no agreed key"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "linters:
  - \"$FAKE_LINTER\""
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief says nothing about a linter that the linters key leaves out"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed: []
linters:
  - \"other-linter\""
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief says nothing for a .ldd-lint.yaml that holds only file_max_lines"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "file_max_lines: 500"
run_brief
expect_exit 0 && expect_out "" && linter_not_called && ok
finish

begin "--brief reads a record with no difference as no line"
write_src "src/a$FX_EXT" 1; fake_doctor adopt
write_record "agreed:
$(names_linter)"
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief says nothing and exits 0 for a record in a tree without a source file"
write_record "agreed: []"
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief says nothing when the project has no recommended config (a doctor exit 2)"
write_src "src/a.rs" 1
write_record "agreed: []"
run_brief
expect_exit 0 && expect_out "" && ok
finish

begin "--brief never edits a file"
write_src "src/a$FX_EXT" 1; fake_doctor missing
write_record "agreed:
$(names_linter)"
before=$(tree_sum)
run_brief
expect_exit 0 && { [[ "$(tree_sum)" == "$before" ]] || bad "the tree changed"; } && ok
finish

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

PLUGIN_NAME="{{.Plugin}}"
{{include "scripts/ldd-doctor-skip-cases.sh"}}

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

# rows_linters — the distinct linters of the fixture rows, one per line
rows_linters() {
  local r
  for r in $FX_ROWS; do ROW=$r; fake_doctor_row; printf '%s\n' "$FAKE_LINTER"; done | awk '!seen[$0]++'
  ROW=""
}

# two_linters <mode> — every row's source file and fake linter in that mode;
# FIRST_LINTER and FIRST_RULE name the first row's linter and rule, and the
# FAKE_* variables are the last row's
two_linters() {
  local r; FIRST_LINTER=""
  for r in $FX_ROWS; do
    use_row "$r"; ROW=$r; fake_doctor_row; write_src "src/a$FX_EXT" 1; fake_doctor "$1"
    [[ -n "$FIRST_LINTER" ]] || { FIRST_LINTER=$FAKE_LINTER; FIRST_RULE=$FAKE_RULE; }
  done
}

begin "--config with a run of two linters and no --linter is a usage error (exit 2)"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  for r in $FX_ROWS; do use_row "$r"; write_src "src/a$FX_EXT" 1; done
  : > "$REPO/x.cfg"
  run_doctor --config x.cfg
  expect_exit 2 && expect_has "--config" && expect_has "--linter" && ok
fi
finish

begin "--config with --linter compares that file for that linter only"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  two_linters missing; fake_doctor_strict strict-cfg
  run_doctor --config strict-cfg --linter "$FAKE_LINTER"
  r1=0; expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: $FAKE_RUNS;" && expect_has "$FIRST_LINTER $FIRST_RULE: missing;" \
    && expect_has "the chosen config strict-cfg" && r1=1
  run_agree --config strict-cfg --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason "kept"
  r2=0; (( r1 )) && expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE = " && r2=1
  run_agree --fingerprint --config strict-cfg --linter "$FAKE_LINTER"
  (( r2 )) && expect_exit 0 && ok
fi
ROW=""; finish

begin "--linter that names a linter the run does not report is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1; : > "$REPO/x.cfg"
run_doctor --config x.cfg --linter no-such-linter
expect_exit 2 && expect_has "--linter no-such-linter" && ok
finish

begin "doctor --linter without --config is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1
run_doctor --linter a-linter
expect_exit 2 && expect_has "--linter" && expect_has "--config" && ok
finish

begin "--brief counts only the rows of the linters the record names"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  two_linters missing
  write_record "agreed:
$(names_linter)"
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
fi
ROW=""; finish

begin "agree --linters prints each linter of a run of two linters"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  two_linters adopt
  run_agree --linters
  want=$(rows_linters | LC_ALL=C sort | while IFS= read -r l; do printf '  - "%s"\n' "$l"; done)
  expect_exit 0 && expect_out "${want%$'\n'}" && ok
fi
ROW=""; finish

begin "--brief counts the rows of every linter that agree --linters named, with no rule agreed"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  two_linters missing
  run_agree --linters
  write_record "agreed: []
linters:
$OUT"
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "2 rules differ from what the team agreed")" && ok
fi
ROW=""; finish

begin "--brief counts only the linters the linters key names, with no rule agreed"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  two_linters missing
  write_record "agreed: []
linters:
  - \"$FAKE_LINTER\""
  run_brief
  expect_exit 0 && expect_out "$(brief_line . "1 rule differs from what the team agreed")" && ok
fi
ROW=""; finish

begin "--brief says nothing about a linter that cannot check when the record names only another"
if (( $(rows_linters | wc -l) < 2 )); then skip "the plugin reports one linter"
else
  for r in $FX_ROWS; do use_row "$r"; write_src "src/a$FX_EXT" 1; done
  # only the last row's linter is installed; the record names only that one
  ROW=$r; fake_doctor_row; fake_doctor adopt
  write_record "agreed:
$(names_linter)"
  run_brief
  expect_exit 0 && expect_out "" && ok
fi
ROW=""; finish

begin "--config with a path that is not a file is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1
run_doctor --config no-such.cfg
expect_exit 2 && expect_has "--config: not a file: no-such.cfg" && ok
finish

begin "--config on another subcommand is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1; : > "$REPO/x.cfg"
run_lint file-length --config x.cfg
expect_exit 2 && expect_has "only doctor and agree take --config" && ok
finish

begin "agree --lint-config prints the line and needs no source file"
mkdir -p "$REPO/sub"; : > "$REPO/sub/strict.yaml"
run_lint agree --lint-config a-linter sub/strict.yaml
expect_exit 0 && expect_out '  - "a-linter sub/strict.yaml"' && ok
finish

begin "agree --lint-config for a path that is not a file is exit 2"
mkdir -p "$REPO/sub"
run_lint agree --lint-config a-linter sub
expect_exit 2 && expect_has "not a file: sub" && [[ -z "$OUT" ]] && ok
finish

begin "agree --lint-config escapes a quote and a backslash in the path"
: > "$REPO/a\"b.yaml"
run_lint agree --lint-config a-linter 'a"b.yaml'
expect_exit 0 && expect_out '  - "a-linter a\"b.yaml"' && ok
finish

begin "agree --lint-config without its two values is a usage error (exit 2)"
run_bounded agree --lint-config a-linter
expect_exit 2 && expect_has "--lint-config needs" && ok
finish

begin "agree in a tree without a source file is inconclusive (exit 2)"
run_lint agree --fingerprint
expect_exit 2 && expect_has "no source file in scope" && ok
finish

begin "the record readers: a key kept as an empty list is present, an absent key is not"
write_record "agreed: []
lint_config:
  - \"a-linter x.yaml\""
record_read record_has agreed; a=$?
record_read record_has lint_config; b=$?
record_read record_has lint_fingerprint; c=$?
rm -f "$REPO/.ldd-lint.yaml"; record_read record_has agreed; d=$?
(( a == 0 && b == 0 && c != 0 && d != 0 )) && [[ -z "$(record_read record_items agreed)" ]] && ok || bad "has: $a $b $c $d"
finish

begin "the record readers: an item with no indent is read"
write_record 'agreed:
- "a-linter r1 = 3 | at column zero"
  - "a-linter r2 = off | indented"'
got=$(record_read record_items agreed); val=$(record_read record_agreed a-linter r1)
[[ "$got" == "a-linter r1 = 3 | at column zero
a-linter r2 = off | indented" && "$val" == 3 ]] && ok || bad "read: $got; value: $val"
finish

# root_relative <path> — runs the script's path helper from $REPO/svc
root_relative() {
  ( cd "$REPO/svc" && eval "$(sed -n '/^root_relative() {/,/^}/p' "$LINT")" && root_relative "$1" )
}

begin "a config path above the project is written relative to the project"
mkdir -p "$REPO/svc/sub"; : > "$REPO/a.cfg"; : > "$REPO/svc/sub/b.cfg"
up=$(cd "$REPO" && pwd -P)
r1=$(root_relative "$up/a.cfg"); r2=$(root_relative "$up/svc/sub/b.cfg"); r3=$(root_relative "sub/b.cfg"); r4=$(root_relative "../a.cfg")
[[ "$r1" == ../a.cfg && "$r2" == sub/b.cfg && "$r3" == sub/b.cfg && "$r4" == ../a.cfg ]] && ok || bad "got: $r1 | $r2 | $r3 | $r4"
finish

begin "--brief on another subcommand is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1
run_lint file-length --brief
expect_exit 2 && expect_has "only doctor takes --brief" && ok
finish

begin "--brief with a --config or a --files is a usage error (exit 2)"
write_src "src/a$FX_EXT" 1; : > "$REPO/x.cfg"; : > "$REPO/list.txt"
run_doctor --brief --config x.cfg
expect_exit 2 && expect_has "--brief takes no --config or --files" \
  && { run_doctor --brief --files list.txt; expect_exit 2 && expect_has "--brief takes no --config or --files"; } && ok
finish

begin "a missing subcommand is a usage error (exit 2)"
run_lint
expect_exit 2 && expect_has "name a subcommand" && ok
finish

begin "a --files list that does not exist is a usage error (exit 2)"
run_lint file-length --files no-such-list.txt
expect_exit 2 && expect_has "no such file list" && ok
finish

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
