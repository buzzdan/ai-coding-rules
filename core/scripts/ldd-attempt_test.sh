#!/usr/bin/env bash
# Fixture matrix for ldd-attempt.sh and ldd-verify-guard.sh — the worker's
# verification bound and the hook that enforces it.
#
# Each case runs the wrapper against a throwaway report directory, or feeds the
# guard a hook input on stdin, and asserts the exit code, the files written and
# the lines printed. The verification commands the guard must deny come from
# the fixture rows spliced in below (fx_verify_commands), one row per language
# the block serves, and so does the lint command the delta form must print.
#
# Usage:  bash scripts/ldd-attempt_test.sh [path/to/ldd-attempt.sh]
#         (default: the sibling ldd-attempt.sh; the sibling ldd-verify-guard.sh
#         is the guard under test)
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the scripts under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ATTEMPT="${1:-$HERE/ldd-attempt.sh}"
[[ -f "$ATTEMPT" ]] || { echo "no such script: $ATTEMPT" >&2; exit 2; }
ATTEMPT=$(cd "$(dirname "$ATTEMPT")" && pwd)/$(basename "$ATTEMPT")
GUARD=$(dirname "$ATTEMPT")/ldd-verify-guard.sh
WORKER="{{.Plugin}}:move-implementer"

pass=0 failed=0
CASE=""
OUT="" ERR="" CODE=0
ROW=""
REPO=""

# ---------- harness ----------
begin() { CASE="$1"; [[ -n "$ROW" ]] && CASE="[$ROW] $1"; REPO=$(mktemp -d); }
finish() { rm -rf "$REPO"; }

run_attempt() { # <move> <kind> <command...> — the wrapper over $REPO/report
  local move="$1" kind="$2"; shift 2
  OUT=$(cd "$REPO" && bash "$ATTEMPT" "$REPO/report" "$move" "$kind" -- "$@" 2>"$REPO/.stderr"); CODE=$?
  ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"
}
run_guard() { # <agent_type|-> <command> — the guard on a hook input; "-" omits agent_type
  local json
  if [[ "$1" == "-" ]]; then
    json=$(printf '{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"d"},"cwd":"%s"}' "$2" "$REPO")
  else
    json=$(printf '{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"d"},"cwd":"%s","agent_id":"a1","agent_type":"%s"}' "$2" "$REPO" "$1")
  fi
  OUT=$(printf '%s' "$json" | bash "$GUARD" 2>"$REPO/.stderr"); CODE=$?
  ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"
}
guard_denies() { # <command> — fails the case unless the guard denies it for the worker
  run_guard "$WORKER" "$1"
  (( CODE == 2 )) || { bad "not denied: $1"; return 1; }
  printf '%s\n' "$ERR" | grep -qF "use ldd-attempt.sh" || { bad "denial without the wrapper's name: $1"; return 1; }
}
guard_allows() { # <agent_type|-> <command>
  run_guard "$1" "$2"
  (( CODE == 0 )) || { bad "denied, expected allowed ($1): $2"; return 1; }
}

ok()   { pass=$((pass + 1)); echo "PASS  $CASE"; }
bad()  { failed=$((failed + 1)); echo "FAIL  $CASE — $1"; echo "      exit=$CODE"; printf '%s\n' "$OUT" "$ERR" | sed 's/^/      | /'; }

expect_exit() { (( CODE == $1 )) || { bad "expected exit $1"; return 1; }; }
expect_has() { # <needle> — in stdout or stderr
  printf '%s\n%s\n' "$OUT" "$ERR" | grep -qF -- "$1" || { bad "missing: $1"; return 1; }
}
expect_file() { [[ -f "$1" ]] || { bad "no file: ${1#"$REPO"/}"; return 1; }; }
expect_no_file() { [[ ! -e "$1" ]] || { bad "unexpected file: ${1#"$REPO"/}"; return 1; }; }

{{include "scripts/ldd-fixture.sh"}}

# ========================= cases =========================
for ROW in $FX_ROWS; do use_row "$ROW"; break; done
ROW=""

begin "1 the first run writes move-1/run-1-test.txt and exits with the command's code"
run_attempt move-1 test sh -c 'echo hello; exit 7'
expect_exit 7 && expect_file "$REPO/report/move-1/run-1-test.txt" && grep -q hello "$REPO/report/move-1/run-1-test.txt" && expect_has "test run 1/3" && ok
finish

begin "2 the fourth run of a move is refused with BOUND: and exit 3"
run_attempt move-1 test true; run_attempt move-1 test true; run_attempt move-1 test true
run_attempt move-1 test true
expect_exit 3 && expect_has "BOUND: move 1 has had three runs" && expect_no_file "$REPO/report/move-1/run-4-test.txt" && ok
finish

begin "3 a test, a lint and a build share one count"
run_attempt move-1 test true; run_attempt move-1 lint true; run_attempt move-1 build true
run_attempt move-1 test true
expect_exit 3 && expect_has "BOUND:" && expect_file "$REPO/report/move-1/run-2-lint.txt" && expect_file "$REPO/report/move-1/run-3-build.txt" && ok
finish

begin "4 a second move has its own count"
run_attempt move-1 test true; run_attempt move-1 test true; run_attempt move-1 test true
run_attempt move-2 test true
expect_exit 0 && expect_file "$REPO/report/move-2/run-1-test.txt" && ok
finish

begin "5 the tail is printed, the full output is in the file"
run_attempt move-1 test sh -c 'seq 1 60'
expect_exit 0 && expect_has "60" && { ! printf '%s\n' "$OUT" | grep -qx 1 || bad "line 1 of 60 printed: the tail is not a tail"; } \
  && (( $(grep -c . "$REPO/report/move-1/run-1-test.txt") == 60 )) && ok
finish

begin "6a a bare move number and the move-<n> form name the same directory"
run_attempt 1 test true; run_attempt move-1 test true
expect_exit 0 && expect_file "$REPO/report/move-1/run-2-test.txt" && ok
finish

begin "6b a kind that is not test, lint or build is a usage error"
run_attempt move-1 bench true
expect_exit 2 && expect_has "kind" && ok
finish

begin "6c the guard allows the wrapper, a plain command, and every command of a caller that is not the worker"
first=$(fx_verify_commands | sed -n 1p)
guard_allows "$WORKER" "bash /x/scripts/ldd-attempt.sh /tmp/r move-1 test -- $first" \
  && guard_allows "$WORKER" "cd /p && bash scripts/ldd-attempt.sh /tmp/r 2 lint -- $(fx_verify_commands | sed -n 3p)" \
  && guard_allows "$WORKER" "git status" && guard_allows "$WORKER" "cat -n a.txt" \
  && guard_allows - "$first" && guard_allows "other:agent" "$first" && ok
finish

begin "6d the guard denies the task-runner forms for the worker"
guard_denies "task test" && guard_denies "make lint" && guard_denies "cd pkg && task build" \
  && guard_denies "task test:race" && guard_denies "task test-unit" && guard_denies "make -C internal test" && guard_denies "make check" && ok
finish

begin "6f a verification run chained behind a wrapper call is still denied"
first=$(fx_verify_commands | sed -n 1p)
guard_denies "bash /p/scripts/ldd-attempt.sh /r move-1 test -- true && $first" \
  && guard_denies "bash /p/scripts/ldd-attempt.sh /r move-1 test -- true; $first" \
  && guard_denies "echo ldd-attempt.sh; $first" \
  && guard_denies "cat scripts/ldd-attempt.sh && $first" \
  && guard_allows "$WORKER" "bash /p/scripts/ldd-attempt.sh /r move-1 test -- $first && echo done" && ok
finish

begin "6h a quoted compound command after the wrapper's -- is one wrapper run and allowed; unquoted it is not"
first=$(fx_verify_commands | sed -n 1p); build=$(fx_verify_commands | sed -n 5p)
guard_allows "$WORKER" "bash /p/scripts/ldd-attempt.sh /r move-1 build -- sh -c \"$build && $build -o bin/svc ./cmd/svc\"" \
  && guard_allows "$WORKER" "bash /p/scripts/ldd-attempt.sh /r move-1 build -- \"$build && $first\"" \
  && guard_allows "$WORKER" "bash /p/scripts/ldd-attempt.sh /r move-1 test -- bash -c '$first; $first -run TestX ./...'" \
  && guard_denies "bash /p/scripts/ldd-attempt.sh /r move-1 build -- $build && $build -o bin/svc ./cmd/svc" && ok
finish

begin "6g the guard sees through a tool path, extra spaces and a -C flag"
tool=$(fx_verify_commands | sed -n 3p | cut -d' ' -f1)
guard_denies "/usr/local/bin/$(fx_verify_commands | sed -n 3p)" \
  && guard_denies "$(fx_verify_commands | sed -n 1p | sed 's/ /   /')" \
  && guard_denies "$(fx_verify_commands | sed -n 1p | sed 's/^\([a-z0-9]*\) /\1 -C internal /')" && ok
finish

for ROW in $FX_ROWS; do
  use_row "$ROW"
  begin "6e the guard denies the language's test, lint, build and vet forms for the worker"
  all=1
  while IFS= read -r c; do guard_denies "$c" || { all=0; break; }; done < <(fx_verify_commands)
  (( all )) && ok
  finish
done
ROW=""

for ROW in $FX_ROWS; do
  use_row "$ROW"
  begin "7 --lint-delta prints the lint command over the slice's changes"
  fx_write_marker "$REPO" fixture
  ext=${FX_GLOB#\*}
  OUT=$(cd "$REPO" && bash "$ATTEMPT" --lint-delta abc123 "internal/services/x$ext" "internal/services/y$ext" "internal/models/t$ext" 2>"$REPO/.stderr"); CODE=$?
  ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"
  expect_exit 0 && expect_has "$(fx_lint_delta_expected abc123 "internal/services/x$ext" "internal/services/y$ext" "internal/models/t$ext")" && ok
  finish
done
ROW=""

# ========================= summary =========================
echo
echo "ldd-attempt_test: $pass passed, $failed failed"
(( failed == 0 ))
