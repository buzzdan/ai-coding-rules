#!/usr/bin/env bash
# evals/postcheck/lib.sh — shared helpers for the cases' postcheck.sh scripts.
#
# Source it from a case's postcheck.sh:
#   . "$(dirname "$(readlink -f "$0")")/../postcheck/lib.sh"
#
# The runner executes postcheck.sh with cwd=$EVAL_DIR (the kept scaffold dir)
# and EVAL_OUT (the run's output dir). Every helper here works in $EVAL_DIR.
# Helpers print what they measured; `assert*` record failures and `finish`
# turns them into the exit code. Append-only: other stages add functions below
# their own marker, never rewrite existing ones.

: "${EVAL_DIR:=$PWD}"
: "${EVAL_OUT:=/tmp}"
export PATH="$PATH:/root/go/bin:$(go env GOPATH 2>/dev/null || echo /root/go)/bin"

LDD_POSTCHECK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LDD_POSTCHECK_DIR

# Pinned complexity tools. Both run via `go run pkg@version`, which ignores the
# fixture's go.mod, and both IGNORE //nolint directives — unlike golangci-lint,
# which would hide the planted functions behind their suppressions.
GOCOGNIT_PKG="github.com/uudashr/gocognit/cmd/gocognit@v1.2.0"
GOCYCLO_PKG="github.com/fzipp/gocyclo/cmd/gocyclo@v0.6.0"

_pc_failures=0

# ── assertions ───────────────────────────────────────────────────────────────

# assert <description> <command...>   — PASS/FAIL by the command's exit code.
assert() {
	local desc=$1
	shift
	if "$@"; then
		echo "PASS  $desc"
	else
		echo "FAIL  $desc"
		_pc_failures=$((_pc_failures + 1))
	fi
}

# assert_le <description> <actual> <max>
assert_le() {
	local desc=$1 actual=${2:-} max=$3
	if [[ "$actual" =~ ^-?[0-9]+$ ]] && ((actual <= max)); then
		echo "PASS  $desc ($actual <= $max)"
	else
		echo "FAIL  $desc (got '${actual:-<none>}', want <= $max)"
		_pc_failures=$((_pc_failures + 1))
	fi
}

# assert_ge <description> <actual> <min>
assert_ge() {
	local desc=$1 actual=${2:-} min=$3
	if [[ "$actual" =~ ^-?[0-9]+$ ]] && ((actual >= min)); then
		echo "PASS  $desc ($actual >= $min)"
	else
		echo "FAIL  $desc (got '${actual:-<none>}', want >= $min)"
		_pc_failures=$((_pc_failures + 1))
	fi
}

# assert_eq <description> <actual> <expected>
assert_eq() {
	local desc=$1 actual=${2:-} expected=$3
	if [[ "$actual" == "$expected" ]]; then
		echo "PASS  $desc ($actual)"
	else
		echo "FAIL  $desc (got '${actual:-<none>}', want '$expected')"
		_pc_failures=$((_pc_failures + 1))
	fi
}

# finish — exit 1 when any assertion failed, 0 otherwise. Call it last.
finish() {
	if ((_pc_failures > 0)); then
		echo "postcheck: $_pc_failures check(s) failed"
		exit 1
	fi
	echo "postcheck: all checks passed"
	exit 0
}

# ── build / test / lint ──────────────────────────────────────────────────────

# run_task <name> — runs `task <name>` in $EVAL_DIR, prints the tail of its
# output, returns its exit code.
run_task() {
	local name=$1 out rc=0
	out=$(cd "$EVAL_DIR" && task "$name" 2>&1) || rc=$?
	if ((rc != 0)); then
		echo "task $name: exit $rc"
		echo "$out" | tail -40
	else
		echo "task $name: ok"
	fi
	return $rc
}

# ── complexity ───────────────────────────────────────────────────────────────

# _complexity_of <tool-pkg> <func> [path] — prints the highest complexity the
# tool reports for a function named <func> (methods match on the bare name,
# `(*T).Name` and `(T).Name` alike) under <path> (default: the whole module).
# Returns 1 and prints nothing when no such function exists.
_complexity_of() {
	local pkg=$1 fn=$2 path=${3:-.}
	(cd "$EVAL_DIR" && go run "$pkg" -over 0 "$path" 2>/dev/null) |
		awk -v fn="$fn" '
			BEGIN { max = -1 }
			{
				name = $3
				sub(/^\([*]?[A-Za-z0-9_]+\)\./, "", name)
				if (name == fn && $1 + 0 > max) max = $1 + 0
			}
			END { if (max < 0) exit 1; print max }'
}

# gocognit_of <func> [path] — cognitive complexity of one function.
gocognit_of() { _complexity_of "$GOCOGNIT_PKG" "$@"; }

# gocyclo_of <func> [path] — cyclomatic complexity of one function.
gocyclo_of() { _complexity_of "$GOCYCLO_PKG" "$@"; }

# ── greps over the working tree ──────────────────────────────────────────────

# count_matches <ERE> <path-glob>... — number of lines matching ERE across the
# files the globs select (relative to $EVAL_DIR; `**` recurses). Missing globs
# count as 0.
count_matches() {
	local ere=$1
	shift
	(
		cd "$EVAL_DIR" || exit 1
		shopt -s nullglob globstar
		local files=() g f
		for g in "$@"; do
			for f in $g; do [[ -f "$f" ]] && files+=("$f"); done
		done
		((${#files[@]} == 0)) && { echo 0; exit 0; }
		grep -hE -- "$ere" "${files[@]}" | wc -l | tr -d ' '
	)
}

# count_matches_prod <ERE> <path-glob>... — count_matches restricted to
# production files (every *_test.go the globs select is skipped).
count_matches_prod() {
	local ere=$1
	shift
	(
		cd "$EVAL_DIR" || exit 1
		shopt -s nullglob globstar
		local files=() g f
		for g in "$@"; do
			for f in $g; do [[ -f "$f" && "$f" != *_test.go ]] && files+=("$f"); done
		done
		((${#files[@]} == 0)) && { echo 0; exit 0; }
		grep -hE -- "$ere" "${files[@]}" | wc -l | tr -d ' '
	)
}

# count_matches_at <rev> <ERE> <pathspec>... — like count_matches but over a
# git revision, using git pathspecs (e.g. '*.go' ':(exclude)cmd/').
count_matches_at() {
	local rev=$1 ere=$2
	shift 2
	git -C "$EVAL_DIR" grep -E -c -e "$ere" "$rev" -- "$@" 2>/dev/null |
		awk -F: '{ s += $NF } END { print s + 0 }'
}

# func_body <name> <file> — prints the source of the function or method
# <name> in <file>, from its `func` line to the closing brace.
func_body() {
	local name=$1 file=$2
	awk -v name="$name" '
		!p && $0 ~ ("^func (\\([^)]*\\) )?" name "\\(") { p = 1 }
		p { print }
		p && /^}/ { exit }' "$EVAL_DIR/$file"
}

# receiver_calls_in <name> <file> — names of the receiver methods `<recv>.X(`
# a method calls in its body (the receiver variable is read from its decl).
receiver_calls_in() {
	local name=$1 file=$2 body recv
	body=$(func_body "$name" "$file")
	[[ -z "$body" ]] && return 1
	recv=$(head -1 <<<"$body" | sed -nE 's/^func \(([A-Za-z_][A-Za-z0-9_]*) .*/\1/p')
	[[ -z "$recv" ]] && return 0
	tail -n +2 <<<"$body" | grep -oE "\b$recv\.[A-Za-z_][A-Za-z0-9_]*\(" |
		sed -E "s/^$recv\.//; s/\($//" | sort -u
}

# new_func_names <ERE> <path-glob>... — names of functions whose `func` line
# matches ERE in the working tree but did not exist at the scaffold base
# commit (so a pre-existing constructor cannot satisfy a "new type" check).
new_func_names() {
	local ere=$1
	shift
	(
		cd "$EVAL_DIR" || exit 1
		shopt -s nullglob globstar
		local files=() g f
		for g in "$@"; do
			for f in $g; do [[ -f "$f" ]] && files+=("$f"); done
		done
		((${#files[@]} == 0)) && exit 0
		comm -13 \
			<(git grep -hoE -e "$ere" "$(base_commit)" -- "${files[@]}" "$@" 2>/dev/null | sed -E 's/^func (\([^)]*\) )?//; s/\(.*$//' | sort -u) \
			<(grep -hoE -- "$ere" "${files[@]}" | sed -E 's/^func (\([^)]*\) )?//; s/\(.*$//' | sort -u)
	)
}

# external_test_calls <ERE> <path-glob>... — matching lines in *_test.go files
# whose package clause ends in `_test` (rung-0 tests through the public API).
external_test_calls() {
	local ere=$1
	shift
	(
		cd "$EVAL_DIR" || exit 1
		shopt -s nullglob globstar
		local total=0 g f n
		for g in "$@"; do
			for f in $g; do
				[[ -f "$f" && "$f" == *_test.go ]] || continue
				head -30 "$f" | grep -qE '^package [A-Za-z0-9_]+_test$' || continue
				n=$(grep -cE -- "$ere" "$f" || true)
				total=$((total + n))
			done
		done
		echo "$total"
	)
}

# ── git history ──────────────────────────────────────────────────────────────

# base_commit — the scaffold's first (root) commit.
base_commit() {
	git -C "$EVAL_DIR" rev-list --max-parents=0 HEAD | tail -1
}

# commits_since_base — how many commits the agent added on top of the scaffold.
commits_since_base() {
	git -C "$EVAL_DIR" rev-list --count HEAD "^$(base_commit)"
}

# ratchet_nonincreasing <ERE> <pathspec>... — walks the commits oldest→newest
# and asserts the number of matching lines never rises and ends at 0. Prints
# one line per commit. Returns 1 on any violation.
ratchet_nonincreasing() {
	local ere=$1
	shift
	local prev=-1 c cnt bad=0
	for c in $(git -C "$EVAL_DIR" rev-list --reverse HEAD); do
		cnt=$(count_matches_at "$c" "$ere" "$@")
		printf '  %s  %3d  %s\n' "$(git -C "$EVAL_DIR" rev-parse --short "$c")" "$cnt" \
			"$(git -C "$EVAL_DIR" log -1 --format=%s "$c")"
		if ((prev >= 0 && cnt > prev)); then
			echo "  ratchet: count rose from $prev to $cnt"
			bad=1
		fi
		prev=$cnt
	done
	if ((prev != 0)); then
		echo "  ratchet: final count is $prev, want 0"
		bad=1
	fi
	return $bad
}

# max_pkgs_touched_per_commit — over the commits after the base, the largest
# number of distinct package directories whose non-test .go files one commit
# changed. Prints the number (0 when there are no commits).
max_pkgs_touched_per_commit() {
	local c n max=0
	for c in $(git -C "$EVAL_DIR" rev-list HEAD "^$(base_commit)"); do
		n=$(git -C "$EVAL_DIR" diff-tree --no-commit-id --name-only -r "$c" |
			grep -E '\.go$' | grep -vE '_test\.go$' | xargs -r -n1 dirname | sort -u | wc -l)
		((n > max)) && max=$n
	done
	echo "$max"
}

# ── the hidden top rung ──────────────────────────────────────────────────────

# run_blackbox — runs the heartbeat black-box suite against $EVAL_DIR. Prints
# its full output on failure (it is the loudest signal a refactor case has).
run_blackbox() {
	local dir="$LDD_POSTCHECK_DIR/heartbeat-blackbox" out rc=0
	echo "== black-box suite: builds cmd/svc, replays the recorded heartbeats =="
	out=$(cd "$dir" && EVAL_DIR="$EVAL_DIR" go test -count=1 -v ./... 2>&1) || rc=$?
	if ((rc != 0)); then
		echo "$out"
		echo "black-box: FAIL (exit $rc) — the HTTP behavior of POST /heartbeat changed"
		return 1
	fi
	if grep -q -- '--- SKIP' <<<"$out"; then
		echo "$out"
		echo "black-box: the suite skipped — EVAL_DIR was not honoured"
		return 1
	fi
	grep -E '^(--- PASS|ok)' <<<"$out"
	echo "black-box: PASS"
}

# ── stage 4a: workflow cases (quickfix / prepare / wire-repo-brain) ──────────

# lint_issue_count — number of issues `golangci-lint run ./...` reports on the
# tree (0 when green). Informational for the quickfix case: escalations may
# legitimately still be pending when the run ends.
lint_issue_count() {
	(cd "$EVAL_DIR" && golangci-lint run --output.text.path=stdout \
		--output.text.print-issued-lines=false --output.text.colors=false ./... 2>&1 || true) |
		grep -cE '^[^ ]+\.go:[0-9]+:[0-9]+: '
}

# count_assertions <test-file> — lines calling t.Fatal*/t.Error* in one file.
count_assertions() {
	grep -c 't\.\(Fatal\|Error\)' "$EVAL_DIR/$1" 2>/dev/null || true
}

# total_assertions — assertion lines across every _test.go in the tree.
total_assertions() {
	(cd "$EVAL_DIR" && grep -rc 't\.\(Fatal\|Error\)' --include='*_test.go' . 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
}

# assert_assertions_kept <baseline-file> — every _test.go listed in the
# baseline (`<count> <path>` per line, paths relative to the repo root) still
# exists and carries at least as many assertion lines as it did (the
# lint-fixer's "never weaken a test" hard limit). One assert per file. A file
# that no longer exists is a legitimate move when its package was dissolved
# (an R4 fix), so it passes only if the tree as a whole still carries at least
# the baseline's total assertion lines; otherwise assertions were lost.
assert_assertions_kept() {
	local want path baseline_total
	baseline_total=$(awk '{s+=$1} END {print s+0}' "$1")
	while read -r want path; do
		[[ -z "$path" ]] && continue
		if [[ ! -f "$EVAL_DIR/$path" ]]; then
			assert_ge "test file $path removed (had $want assertion lines): tree total still covers the baseline $baseline_total" "$(total_assertions)" "$baseline_total"
			continue
		fi
		assert_ge "assertions kept in $path" "$(count_assertions "$path")" "$want"
	done <"$1"
}

# file_unchanged_since_base <path> — true when the working-tree file is
# byte-identical to the scaffold's commit (uncommitted edits count as changes).
file_unchanged_since_base() {
	git -C "$EVAL_DIR" diff --quiet "$(base_commit)" -- "$1"
}

# last_message_contains <ERE> — greps the run's final agent message, taken from
# the result event in $EVAL_OUT/trace.jsonl (result.json is written after the
# graders run, so the trace is the only artifact a postcheck can read).
last_message_contains() {
	[[ -f "$EVAL_OUT/trace.jsonl" ]] || return 1
	grep '"type":"result"' "$EVAL_OUT/trace.jsonl" | grep -qE -- "$1"
}
