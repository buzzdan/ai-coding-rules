#!/usr/bin/env bash
# Fixture matrix for check-repo-brain.sh — the gate's own conformance test.
#
# Each case builds a throwaway repo under a temp dir, runs the gate against it,
# and asserts the exit code plus the presence/absence of specific report lines.
# The matrix doubles as the language-adapter contract: the cases are the same
# for every language, and the language-specific files they need — the project
# marker, the conformant code file the docs cite, the sub-project and the
# second package — come from the fixture rows spliced in below. A gate whose
# adapter serves several languages runs the whole matrix once per row.
#
# Usage:  bash scripts/check-repo-brain_test.sh [path/to/check-repo-brain.sh]
#         (default: the sibling check-repo-brain.sh)
#         GATE_REF=old.sh bash scripts/check-repo-brain_test.sh — differential
#         mode: also runs the reference script on each fixture and fails on any
#         difference in output, exit code, or files written by --fix
# Exit:   0 all cases pass · 1 any failure (details on stdout)
#
# Uses only POSIX-portable tools, like the script under test.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
GATE="${1:-$HERE/check-repo-brain.sh}"
[[ -f "$GATE" ]] || { echo "no such script: $GATE" >&2; exit 2; }
GATE=$(cd "$(dirname "$GATE")" && pwd)/$(basename "$GATE")

pass=0 failed=0
CASE=""
OUT="" ERR="" CODE=0
ROW=""

# ---------- harness ----------
begin() { CASE="$1"; [[ -n "$ROW" ]] && CASE="[$ROW] $1"; REPO=$(mktemp -d); }
finish() { rm -rf "$REPO"; }

# GATE_REF=/path/to/other/check-repo-brain.sh — differential mode: every run is
# repeated with the reference script on an identical copy of the fixture, and
# any difference in stdout, stderr, or exit code fails the case. Use it to prove
# a refactor of the gate (or a new language adapter) changed no behavior.
GATE_REF="${GATE_REF:-}"
diffs=0

run_gate() { # [--fix]
  local ref_repo="" ref_out="" ref_err="" ref_code=0
  if [[ -n "$GATE_REF" ]]; then
    ref_repo=$(mktemp -d); cp -R "$REPO/." "$ref_repo/"
  fi
  OUT=$(cd "$REPO" && bash "$GATE" "$@" . 2>"$REPO/.stderr"); CODE=$?
  ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"
  if [[ -n "$GATE_REF" ]]; then
    ref_out=$(cd "$ref_repo" && bash "$GATE_REF" "$@" . 2>"$ref_repo/.stderr"); ref_code=$?
    ref_err=$(cat "$ref_repo/.stderr"); rm -f "$ref_repo/.stderr"
    if [[ "$OUT" != "$ref_out" || "$ERR" != "$ref_err" || "$CODE" != "$ref_code" ]]; then
      diffs=$((diffs + 1))
      echo "DIFF  $CASE — output differs from reference ($GATE_REF)"
      diff <(printf 'exit=%s\n%s\n%s\n' "$ref_code" "$ref_out" "$ref_err") \
           <(printf 'exit=%s\n%s\n%s\n' "$CODE" "$OUT" "$ERR") | sed 's/^/      /'
    elif (( $# > 0 )) && [[ "$1" == "--fix" ]]; then
      diff -r "$ref_repo" "$REPO" >/dev/null || { diffs=$((diffs + 1)); echo "DIFF  $CASE — --fix wrote different files than the reference"; }
    fi
    rm -rf "$ref_repo"
  fi
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
expect_count() { # <needle> <n>
  local n; n=$(printf '%s\n%s\n' "$OUT" "$ERR" | grep -cF -- "$1")
  (( n == $2 )) || { bad "expected $2 of '$1', got $n"; return 1; }
}

# ---------- fixture builders ----------
# A minimal conformant repo: one package declaring the symbols the docs cite,
# a docs/ bundle with root index + one feature doc, CLAUDE.md and AGENTS.md wired.
# The code file and the project marker are the row's (fixture rows below).
mk_conformant() {
  mkdir -p "$REPO/docs"
  fx_write_marker "$REPO" fixture
  fx_write_conformant_code
  cat > "$REPO/docs/index.md" <<'EOF'
---
okf_version: "0.2"
---
# Repo map

**Resilience**
- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; `Policy` API
EOF
  cat > "$REPO/docs/retry-policy.md" <<'EOF'
---
type: feature
description: why retries use capped full jitter; `Policy` API
---
# Retry policy

Entry point: `Policy.Do`. Construction: `ParsePolicy` caps the attempt count at
`DefaultAttempts`. Sentinels: `ErrExhausted`, `ErrCancelled`. Package: `retry`.
EOF
  cat > "$REPO/CLAUDE.md" <<'EOF'
# Fixture

@AGENTS.md
@docs/index.md
EOF
  cat > "$REPO/AGENTS.md" <<'EOF'
Start at docs/index.md. Conventions: docs/conventions.md.
EOF
}

append_index() { printf '%s\n' "$1" >> "$REPO/docs/index.md"; }

mk_doc() { # <name> <description> [body...]
  local name="$1" desc="$2"; shift 2
  {
    printf -- '---\ntype: feature\ndescription: %s\n---\n# %s\n\n' "$desc" "$name"
    printf '%s\n' "$@"
  } > "$REPO/docs/$name.md"
}

# ---------- fixture rows: one per language the detected adapter supports ----------
# The matrix runs its cases once per row. use_row sets the row's variables and
# the fx_* builders write that language's files; the cases read only these.
#
#   FX_ROWS            the row ids, space-separated
#   FX_MARKER          the project marker at a project root
#   FX_CODE_FILE       the conformant code file the docs cite (declares Policy,
#                      ParsePolicy, Policy.Do, DefaultAttempts, ErrExhausted,
#                      ErrCancelled and errString.Error in package/module retry)
#   FX_FENCE           the fenced-block language tag
#   FX_DOTTED_CONFIG   a dotted config-file name that must be skipped as a token
#   FX_GLOB1/FX_GLOB2  generated-file glob patterns that must not read as paths
#   FX_EXTERNAL1/2     package-qualified tokens from outside the repo (exempt)
#   FX_URL             a documentation URL carrying a symbol anchor
#   FX_COMMENT         the line-comment marker of the row's code files
#   FX_PRUNED_DIRS     the dependency and build-output directories the adapter prunes
#   FX_CONST_SHAPE     "checked" when the symbol shape takes UPPER_SNAKE constants,
#                      "skipped" when it does not
#   fx_write_marker <dir> <module>     write the marker for a (sub-)project
#   fx_write_conformant_code           write $FX_CODE_FILE with the cited symbols
#   fx_append_missing_edge             add a symbol whose comment cites docs/backoff.md
#   fx_write_subproject_code <dir>     write <dir>'s code file: Thing, citing docs/thing.md
#   fx_write_other_package             write other/: a package declaring Nope
FX_ROWS="go python"

use_row() {
  case "$1" in
    go)
      FX_MARKER="go.mod"
      FX_CODE_FILE="retry/policy.go"
      FX_FENCE="go"
      FX_DOTTED_CONFIG=".golangci.yaml"
      FX_GLOB1='*_gen.go'; FX_GLOB2='*.pb.go'
      FX_EXTERNAL1="time.Duration"; FX_EXTERNAL2="http.Client"
      FX_URL="https://pkg.go.dev/example.com/fixture/retry#Policy.Do"
      FX_COMMENT="//"
      FX_PRUNED_DIRS="vendor"
      FX_CONST_SHAPE="skipped"
      ;;
    python)
      FX_MARKER="pyproject.toml"
      FX_CODE_FILE="retry/policy.py"
      FX_FENCE="python"
      FX_DOTTED_CONFIG=".ruff.toml"
      FX_GLOB1='*_pb2.py'; FX_GLOB2='*.pyi'
      FX_EXTERNAL1="datetime.timedelta"; FX_EXTERNAL2="http.client"
      FX_URL="https://example.readthedocs.io/en/latest/retry.html#Policy.Do"
      FX_COMMENT="#"
      FX_PRUNED_DIRS=".venv venv __pycache__ site-packages .tox node_modules build dist .eggs"
      FX_CONST_SHAPE="checked"
      ;;
  esac
}

fx_write_marker() { # <dir> <module>
  case "$ROW" in
    go)     printf 'module example.com/%s\n\ngo 1.22\n' "$2" > "$1/go.mod" ;;
    python) printf '[project]\nname = "%s"\nversion = "0.1.0"\n' "$2" > "$1/pyproject.toml" ;;
  esac
}

fx_write_conformant_code() {
  mkdir -p "$REPO/retry"
  case "$ROW" in
    go)
      cat > "$REPO/retry/policy.go" <<'EOF'
package retry

import "time"

// Policy bounds retries. See docs/retry-policy.md for the jitter decision.
type Policy struct {
	maxAttempts int
	baseDelay   time.Duration
}

func ParsePolicy(maxAttempts int, base time.Duration) (Policy, error) {
	return Policy{maxAttempts: maxAttempts, baseDelay: base}, nil
}

func (p Policy) Do(op func() error) error { return op() }

const (
	DefaultAttempts = 3
	defaultBase     = time.Second
)

var (
	ErrExhausted, ErrCancelled = errString("exhausted"), errString("cancelled")
)

type errString string

func (e errString) Error() string { return string(e) }
EOF
      ;;
    python)
      cat > "$REPO/retry/policy.py" <<'EOF'
"""Retry policies."""

from datetime import timedelta


class Policy:
    """Policy bounds retries. See docs/retry-policy.md for the jitter decision."""

    def __init__(self, max_attempts: int, base: timedelta) -> None:
        self._max_attempts = max_attempts
        self._base = base

    def Do(self, op):
        return op()


def ParsePolicy(max_attempts: int, base: timedelta) -> Policy:
    return Policy(max_attempts, base)


DefaultAttempts = 3
defaultBase = timedelta(seconds=1)

ErrExhausted, ErrCancelled = "exhausted", "cancelled"


class errString(str):
    def Error(self) -> str:
        return str(self)
EOF
      ;;
  esac
}

fx_append_missing_edge() {
  case "$ROW" in
    go)
      cat >> "$REPO/retry/policy.go" <<'EOF'

// Backoff computes the delay. See docs/backoff.md.
func Backoff(n int) int { return n }
EOF
      ;;
    python)
      cat >> "$REPO/retry/policy.py" <<'EOF'


def Backoff(n: int) -> int:
    """Backoff computes the delay. See docs/backoff.md."""
    return n
EOF
      ;;
  esac
}

fx_write_subproject_code() { # <dir>
  mkdir -p "$1/pkg"
  case "$ROW" in
    go)
      cat > "$1/pkg/x.go" <<'EOF'
package pkg

// Thing does things. See docs/thing.md.
type Thing struct{}
EOF
      ;;
    python)
      cat > "$1/pkg/x.py" <<'EOF'
class Thing:
    """Thing does things. See docs/thing.md."""
EOF
      ;;
  esac
}

fx_write_other_package() {
  mkdir -p "$REPO/other"
  case "$ROW" in
    go)
      cat > "$REPO/other/other.go" <<'EOF'
package other

// Nope exists here, not in retry.
func Nope() {}
EOF
      ;;
    python)
      cat > "$REPO/other/other.py" <<'EOF'
def Nope():
    """Nope exists here, not in retry."""
EOF
      ;;
  esac
}

# ---------- adapter cases: detection itself, outside the per-row loop ----------
fx_adapter_cases() {
  begin "detected adapter: no marker keeps the structure checks and says the edges are unverified"
  mkdir -p "$REPO/docs" "$REPO/src"
  printf 'plain text, no marker\n' > "$REPO/src/notes.txt"
  printf -- '---\nokf_version: "0.2"\n---\n# Repo map\n\n- [ghost.md](ghost.md) — a ghost symbol\n' > "$REPO/docs/index.md"
  mk_doc ghost "a ghost symbol" "Uses \`SnapshotRunner\`, declared nowhere."
  printf '# Fixture\n\n@docs/index.md\n' > "$REPO/CLAUDE.md"
  printf 'Start at docs/index.md.\n' > "$REPO/AGENTS.md"
  run_gate
  expect_exit 0 && expect_has "structure checks only" && expect_has "edges are unverified" \
    && expect_not "does not resolve" && expect_has "check-repo-brain: clean" && ok
  finish

  begin "detected adapter: no marker still bans line-number citations and reports orphans"
  mkdir -p "$REPO/docs"
  printf -- '---\nokf_version: "0.2"\n---\n# Repo map\n\n- [where.md](where.md) — where things live\n' > "$REPO/docs/index.md"
  mk_doc where "where things live" "The parser starts at line 42 of the main file."
  mk_doc orphan "an unlinked doc" "Nothing links here."
  printf '# Fixture\n\n@docs/index.md\n' > "$REPO/CLAUDE.md"
  run_gate
  expect_exit 1 && expect_has "cites a file path or line number" && expect_has "[Q1] docs/orphan.md — orphan" && ok
  finish

  begin "detected adapter: a marker below the root selects that language"
  ROW=go; use_row go
  mk_conformant
  rm "$REPO/go.mod"
  fx_write_marker "$REPO/retry" retry
  run_gate
  expect_exit 0 && expect_not "structure checks only" && expect_not "does not resolve" && ok
  finish

  begin "detected adapter: go.mod at the root wins over a Python marker beside it"
  ROW=go; use_row go
  mk_conformant
  printf '[project]\nname = "tools"\n' > "$REPO/pyproject.toml"
  mkdir -p "$REPO/scripts"; printf 'def helper_fn():\n    pass\n' > "$REPO/scripts/tool.py"
  run_gate
  expect_exit 0 && expect_not "does not resolve" && ok
  finish

  begin "detected adapter: a go.mod whose path holds a newline does not select Go over a Python marker"
  mkdir -p "$REPO/skip"$'\n'"me" "$REPO/service/docs"
  printf 'module example.com/skip\n\ngo 1.22\n' > "$REPO/skip"$'\n'"me/go.mod"
  printf '[project]\nname = "service"\n' > "$REPO/service/pyproject.toml"
  printf -- '---\nokf_version: "0.2"\n---\n# Service map\n' > "$REPO/service/docs/index.md"
  printf -- '---\ntype: guide\ndescription: an unlinked doc\n---\n# Orphan\n' > "$REPO/service/docs/orphan.md"
  run_gate
  expect_exit 1 && expect_has "[Q1] service/docs/orphan.md — orphan" && ok
  finish

  ROW=python; use_row python
  begin "module-level assignments declare module-qualified names"
  mk_conformant
  printf '\nMaxDelay: float = 2.0\nmin_delay=0.1\n' >> "$REPO/retry/policy.py"
  mk_doc consts "module constants" \
    "Defaults: \`policy.DefaultAttempts\`, \`policy.MaxDelay\` and \`retry.min_delay\`."
  append_index "- [consts.md](consts.md) — module constants"
  run_gate
  expect_exit 0 && expect_not "does not resolve" && ok
  finish

  ROW=go; use_row go
  begin "Q2 every name of a Go name list resolves"
  mk_conformant; go_write_shapes
  mk_doc lists "name lists" "Errors \`retry.ErrSecond\`, size \`retry.SizeMB\`, group \`retry.GroupSecond\`, limit \`retry.LimitThird\` and split \`retry.SplitSecond\`."
  append_index "- [lists.md](lists.md) — name lists"
  run_gate
  expect_exit 0 && expect_not "does not resolve" && ok
  finish

  ROW=go; use_row go
  begin "Q2 a method on a type with two type parameters resolves"
  mk_conformant; go_write_shapes
  mk_doc generic "generic receivers" "Read with \`Cache.Lookup\` on a \`retry.Cache\`."
  append_index "- [generic.md](generic.md) — generic receivers"
  run_gate
  expect_exit 0 && expect_not "does not resolve" && ok
  finish

  ROW=go; use_row go
  begin "Q2 a Go list below a group entry, or after an empty group, gives no package names"
  mk_conformant; go_write_shapes
  mk_doc nonames "not package names" "Not \`retry.FieldSecond\`, \`retry.FuncSecond\` or \`retry.EmptySecond\`."
  append_index "- [nonames.md](nonames.md) — not package names"
  run_gate
  expect_exit 1 && expect_has "\`retry.FieldSecond\` does not resolve" \
    && expect_has "\`retry.FuncSecond\` does not resolve" \
    && expect_has "\`retry.EmptySecond\` does not resolve" && ok
  finish

  ROW=go; use_row go
  begin "Q2 the first field of a struct in a type group, or a line in a raw string, gives no package name"
  mk_conformant; go_write_shapes
  mk_doc nofirst "not package names" "Not \`retry.FieldFirst\` or \`retry.RawLine\`."
  append_index "- [nofirst.md](nofirst.md) — not package names"
  run_gate
  expect_exit 1 && expect_has "\`retry.FieldFirst\` does not resolve" \
    && expect_has "\`retry.RawLine\` does not resolve" && ok
  finish

  ROW=go; use_row go
  begin "Q2 a declaration after an empty group resolves, and its struct field does not"
  mk_conformant; go_write_shapes
  mk_doc afterempty "after an empty group" "Real: \`retry.AfterEmpty\`. Fake: \`retry.AfterField\`."
  append_index "- [afterempty.md](afterempty.md) — after an empty group"
  run_gate
  expect_exit 1 && expect_has "\`retry.AfterField\` does not resolve" \
    && expect_not "\`retry.AfterEmpty\` does not resolve" && ok
  finish

  ROW=go; use_row go
  begin "Q2 a group entry after a func literal, a brace in a string or a raw string resolves"
  mk_conformant; go_write_shapes
  mk_doc aftergroup "group entries" "Entries \`retry.AfterHandler\`, \`retry.AfterBrace\` and \`retry.AfterRaw\`."
  append_index "- [aftergroup.md](aftergroup.md) — group entries"
  run_gate
  expect_exit 0 && expect_not "does not resolve" && ok
  finish

  py_class_scope_cases
}

go_write_shapes() {
  cat > "$REPO/retry/shapes.go" <<'GO'
package retry

var (
	ErrFirst, ErrSecond = errString("first"), errString("second")
	SizeKB, SizeMB int64 = 1, 2
	GroupFirst, GroupSecond,
	GroupThird int
	handler = func() {
		FuncFirst, FuncSecond = 1, 2
	}
	AfterHandler = 3
	brace        = "{"
	AfterBrace   = 4
	usage        = `
RawLine {
`
	AfterRaw = 5
)

type (
	Outcome struct {
		FieldFirst, FieldSecond string
	}
)

var LimitFirst, LimitSecond, LimitThird = 1, 2, 3

var SplitFirst, SplitSecond,
	SplitThird int

type Cache[K comparable, V any] struct{ items map[K]V }

func (c *Cache[K, V]) Lookup(key K) V { return c.items[key] }

var ()

type AfterEmpty struct {
	AfterField string
}

func reset() {
	EmptyFirst, EmptySecond = 1, 2
}
GO
}

# py_class_scope_cases — "<Class>.<name>" comes only from a def at the indent of
# the class body. A def nested in a method, or under a column-0 if after the
# class, gives no such name. A multi-line class header, a column-0 comment, a
# column-0 docstring line and a column-0 closing bracket keep the class open.
py_class_scope_cases() {
  ROW=python; use_row python
  begin "Q2 a def nested in a method gives no method name"
  mk_conformant
  cat > "$REPO/retry/nested.py" <<'PY'
class Policy:
    def run(self):
        def helper():
            return 1

        return helper()

    def stop(self):
        return 0
PY
  mk_doc nested "nested defs" "Real: \`Policy.stop\`. Fake: \`Policy.helper\`."
  append_index "- [nested.md](nested.md) — nested defs"
  run_gate
  expect_exit 1 && expect_has "\`Policy.helper\` does not resolve" \
    && expect_not "\`Policy.stop\` does not resolve" && ok
  finish

  ROW=python; use_row python
  begin "Q2 a def under a column-0 if after a class gives no method name"
  mk_conformant
  cat > "$REPO/retry/cond.py" <<'PY'
class Policy:
    def run(self):
        return 1


if True:
    def helper():
        return 2
PY
  mk_doc cond "conditional defs" "Not \`Policy.helper\`."
  append_index "- [cond.md](cond.md) — conditional defs"
  run_gate
  expect_exit 1 && expect_has "\`Policy.helper\` does not resolve" && ok
  finish

  ROW=python; use_row python
  begin "Q2 a class stays open across its header, a column-0 comment, a column-0 docstring line and a column-0 bracket"
  mk_conformant
  cat > "$REPO/retry/kept.py" <<'PY'
class Multi(
    object,
):
    """Multi keeps its methods.

Text at column 0 inside the docstring.
"""

    def kept_first(self):
        marker = '"""'
        return print(
            marker,
)
# a column-0 comment inside the class

    @property
    def kept_second(self):
        return 2
PY
  mk_doc kept "kept methods" "Methods \`Multi.kept_first\` and \`Multi.kept_second\`."
  append_index "- [kept.md](kept.md) — kept methods"
  run_gate
  expect_exit 0 && expect_not "does not resolve" && ok
  finish
}

# ========================= cases =========================
run_row_cases() { # runs every case against the current row

# --- baseline ---
begin "clean conformant bundle exits 0"
mk_conformant; run_gate
expect_exit 0 && expect_has "check-repo-brain: clean" && expect_not "[Q" && ok
finish

begin "no doc root is an advisory no-op (exit 0)"
mkdir -p "$REPO/src"; : > "$REPO/$FX_MARKER"; run_gate
expect_exit 0 && expect_has "nothing to check yet" && ok
finish

# --- Q1 reachability ---
begin "Q1 orphan doc is reported"
mk_conformant; mk_doc orphan "an unlinked doc" "Nothing links here."; run_gate
expect_exit 1 && expect_has "[Q1] docs/orphan.md — orphan" && ok
finish

begin "Q1 map of maps: doc reachable through a bare sub-index"
mk_conformant
mkdir -p "$REPO/docs/ops"
cat > "$REPO/docs/ops/index.md" <<'EOF'
# Ops

- [runbook.md](runbook.md) — how to page on-call for retries
EOF
mkdir -p "$REPO/docs/ops"; cat > "$REPO/docs/ops/runbook.md" <<'EOF'
---
type: guide
description: how to page on-call for retries
---
# Runbook

Use `Policy.Do`.
EOF
append_index "- [ops/index.md](ops/index.md) — operations sub-map"
run_gate
expect_exit 0 && expect_not "[Q1]" && expect_not "[Q7] docs/ops/index.md" && ok
finish

begin "Q1 missing root index is reported"
mk_conformant; rm "$REPO/docs/index.md"; run_gate
expect_exit 1 && expect_has "[Q1] docs — no index.md" && ok
finish

# --- Q2 links and edges ---
begin "Q2 dangling doc→doc link is reported"
mk_conformant
mk_doc auth "auth flow" "Retries follow [retry-policy.md](retry-policy.md) and [missing.md](missing.md)."
append_index "- [auth.md](auth.md) — auth flow"
run_gate
expect_exit 1 && expect_has "[Q2] docs/auth.md — link target does not exist: missing.md" && ok
finish

begin "Q2 code→docs edge pointing at a missing doc is reported"
mk_conformant
fx_append_missing_edge
run_gate
expect_exit 1 && expect_has "[Q2] ./$FX_CODE_FILE:" && expect_has "missing docs/backoff.md" && ok
finish

begin "Q2 code→docs edge resolving inside a sub-project passes"
mk_conformant
mkdir -p "$REPO/svc/docs"
fx_write_marker "$REPO/svc" svc
fx_write_subproject_code "$REPO/svc"
printf -- '---\nokf_version: "0.2"\n---\n# svc map\n\n- [thing.md](thing.md) — the thing\n' > "$REPO/svc/docs/index.md"
printf -- '---\ntype: feature\ndescription: the thing\n---\n# Thing\n\n`Thing` is declared in `pkg`.\n' > "$REPO/svc/docs/thing.md"
append_index "- [svc/docs/index.md](../svc/docs/index.md) — svc sub-project map"
run_gate
expect_exit 0 && expect_not "[Q2]" && expect_not "[Q3] svc" && ok
finish

begin "Q2 file:line citation is banned"
mk_conformant
mk_doc where "where things live" "The parser lives in $FX_CODE_FILE:42 and uses \`Policy\`."
append_index "- [where.md](where.md) — where things live"
run_gate
expect_exit 1 && expect_has "[Q2] docs/where.md:" && expect_has "cites a file path or line number" && ok
finish

begin "Q2 file-path ban exempts URLs, fenced blocks, and glob patterns"
mk_conformant
mk_doc paths "path exemptions" \
  "Docs: $FX_URL and [src](https://github.com/x/y/blob/main/$FX_CODE_FILE)." \
  "" \
  '```'"$FX_FENCE" \
  "$FX_CODE_FILE:12 — inside a fence" \
  '```' \
  "" \
  "Generated files match \`$FX_GLOB1\` and \`$FX_GLOB2\`."
append_index "- [paths.md](paths.md) — path exemptions"
run_gate
expect_exit 0 && expect_not "cites a file path" && ok
finish

begin "Q2 unresolved backticked symbol is reported"
mk_conformant
mk_doc ghost "a ghost symbol" "Uses \`SnapshotRunner\` and \`Policy\`."
append_index "- [ghost.md](ghost.md) — a ghost symbol"
run_gate
expect_exit 1 && expect_has "backticked \`SnapshotRunner\` does not resolve" && expect_not "\`Policy\` does not resolve" && ok
finish

begin "CHECK_REPO_BRAIN_FAULT makes the run an internal error (exit 2), never clean"
mk_conformant
OUT=$(cd "$REPO" && CHECK_REPO_BRAIN_FAULT="a test" bash "$GATE" . 2>"$REPO/.stderr"); CODE=$?
ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"
expect_exit 2 && expect_has "internal scanner error — CHECK_REPO_BRAIN_FAULT is set (a test)" && expect_not "check-repo-brain: clean" && ok
finish

begin "a failed declaration scan is an internal error (exit 2), never clean"
mk_conformant
mk_doc ghost "a ghost symbol" "Uses \`SnapshotRunner\` and \`Policy\`."
append_index "- [ghost.md](ghost.md) — a ghost symbol"
fakebin=$(mktemp -d)
printf '#!/bin/sh\n[ "$*" = "-u" ] && { cat >/dev/null; exit 3; }\nexec %s "$@"\n' "$(command -v sort)" > "$fakebin/sort"
chmod +x "$fakebin/sort"
OUT=$(cd "$REPO" && PATH="$fakebin:$PATH" bash "$GATE" . 2>"$REPO/.stderr"); CODE=$?
ERR=$(cat "$REPO/.stderr"); rm -f "$REPO/.stderr"; rm -rf "$fakebin"
expect_exit 2 && expect_has "internal scanner error" && expect_not "check-repo-brain: clean" && ok
finish

begin "Q2 grouped declarations and methods resolve"
mk_conformant
mk_doc decls "declaration shapes" "Constants \`DefaultAttempts\`; sentinels \`ErrExhausted\` and \`ErrCancelled\`; method \`Policy.Do\`; bare method \`Do\`."
append_index "- [decls.md](decls.md) — declaration shapes"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "Q2 a package-qualified constant resolves"
mk_conformant
mk_doc pkgconst "package constants" "Retries default to \`retry.DefaultAttempts\`."
append_index "- [pkgconst.md](pkgconst.md) — package constants"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "Q2 package-qualified tokens: repo package resolves, external package exempt"
mk_conformant
mk_doc qual "qualified tokens" "Call \`retry.ParsePolicy\`, then \`$FX_EXTERNAL1\` and \`$FX_EXTERNAL2\` are library types; \`retry.Nope\` is not declared."
append_index "- [qual.md](qual.md) — qualified tokens"
run_gate
expect_exit 1 && expect_has "\`retry.Nope\` does not resolve" && expect_not "$FX_EXTERNAL1" && expect_not "$FX_EXTERNAL2" && expect_not "retry.ParsePolicy" && ok
finish

begin "Q2 whole-word fallback resolves non-declared tokens found in repo files"
mk_conformant
printf 'alerts:\n  - name: RetryBudgetExhausted\n' > "$REPO/alerts.yaml"
mk_doc alerts "alert names" "Fires \`RetryBudgetExhausted\` when \`Policy\` gives up."
append_index "- [alerts.md](alerts.md) — alert names"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "Q2 the whole-word fallback does not read a file whose path holds a newline"
mk_conformant
printf 'alerts:\n  - name: RetryBudgetExhausted\n' > "$REPO/alerts"$'\n'"old.yaml"
mk_doc alerts "alert names" "Fires \`RetryBudgetExhausted\` when \`Policy\` gives up."
append_index "- [alerts.md](alerts.md) — alert names"
run_gate
expect_exit 1 && expect_has "backticked \`RetryBudgetExhausted\` does not resolve" && ok
finish

begin "Q2 ALL-CAPS initialisms, placeholders, and dotted config names are skipped"
mk_conformant
mk_doc caps "skipped token shapes" "Set \`TTL\` and \`<docroot>\`; the linter config is \`$FX_DOTTED_CONFIG\`; \`HTTP\` is fine."
append_index "- [caps.md](caps.md) — skipped token shapes"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "Q2 ⚠️ stale and *(planned)* lines are exempt from symbol resolution"
mk_conformant
mk_doc roadmap "roadmap" "Coming: \`Circuit\` *(planned)*." "Old: ⚠️ \`LegacyPolicy\` was removed."
append_index "- [roadmap.md](roadmap.md) — roadmap"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

# --- Q3 root wiring ---
begin "Q3 unwired root is reported"
mk_conformant; rm "$REPO/CLAUDE.md" "$REPO/AGENTS.md"; run_gate
expect_exit 1 && expect_has "[Q3] . — neither CLAUDE.md nor AGENTS.md references docs/index.md" && ok
finish

begin "Q3 CLAUDE.md wired but AGENTS.md missing is an advisory, not a violation"
mk_conformant; rm "$REPO/AGENTS.md"; run_gate
expect_exit 0 && expect_has "advisory: [Q3] AGENTS.md lacks" && ok
finish

begin "Q3 a bare 'index.md' mention does not count as wiring"
mk_conformant
printf '# Fixture\n\nsee index.md\n' > "$REPO/CLAUDE.md"; rm "$REPO/AGENTS.md"; run_gate
expect_exit 1 && expect_has "[Q3]" && ok
finish

begin "Q3 a sub-project root may be wired through the repo-root index instead"
mk_conformant
mkdir -p "$REPO/svc/docs"
fx_write_marker "$REPO/svc" svc
printf -- '---\nokf_version: "0.2"\n---\n# svc map\n' > "$REPO/svc/docs/index.md"
append_index "- [svc/docs/index.md](../svc/docs/index.md) — svc sub-project map"
run_gate
expect_exit 0 && expect_not "[Q3] svc" && ok
finish

begin "Q3 a doc whose path holds a newline does not wire a sub-project root"
mk_conformant
mkdir -p "$REPO/svc/docs"
fx_write_marker "$REPO/svc" svc
printf -- '---\nokf_version: "0.2"\n---\n# svc map\n' > "$REPO/svc/docs/index.md"
mk_doc "release"$'\n'"notes" "release notes" "The svc map is svc/docs/index.md."
run_gate
expect_exit 1 && expect_has "[Q3] svc — neither" && ok
finish

# --- Q7 bundle contract ---
begin "Q7 content doc without frontmatter is reported"
mk_conformant
printf '# Bare\n\nNo frontmatter.\n' > "$REPO/docs/bare.md"
append_index "- [bare.md](bare.md) — bare"
run_gate
expect_exit 1 && expect_has "[Q7] docs/bare.md — no frontmatter block" && ok
finish

begin "Q7 unterminated frontmatter is reported"
mk_conformant
printf -- '---\ntype: feature\ndescription: never closed\n# Oops\n' > "$REPO/docs/open.md"
append_index "- [open.md](open.md) — never closed"
run_gate
expect_exit 1 && expect_has "[Q7] docs/open.md — unterminated frontmatter" && ok
finish

begin "Q7 missing required key is reported"
mk_conformant
printf -- '---\ntype: feature\n---\n# No description\n' > "$REPO/docs/nodesc.md"
append_index "- [nodesc.md](nodesc.md) — no description"
run_gate
expect_exit 1 && expect_has "[Q7] docs/nodesc.md — frontmatter missing 'description:'" && ok
finish

begin "Q7 optional keys (generated, tags, status, stale_after) are accepted"
mk_conformant
cat > "$REPO/docs/opt.md" <<'EOF'
---
type: guide
description: optional keys present
title: Optional
generated: 2026-08-20T00:00:00Z
tags: [a, b]
status: stable
stale_after: 2099-01-01
---
# Optional
EOF
append_index "- [opt.md](opt.md) — optional keys present"
run_gate
expect_exit 0 && expect_not "[Q7]" && ok
finish

begin "Q7 related: key is reported"
mk_conformant
printf -- '---\ntype: feature\ndescription: has related\nrelated: [retry-policy.md]\n---\n# Rel\n' > "$REPO/docs/rel.md"
append_index "- [rel.md](rel.md) — has related"
run_gate
expect_exit 1 && expect_has "[Q7] docs/rel.md — 'related:' frontmatter key" && ok
finish

begin "Q7 frontmatter on a sub-index is reported"
mk_conformant
mkdir -p "$REPO/docs/ops"
printf -- '---\ntype: index\n---\n# Ops\n' > "$REPO/docs/ops/index.md"
append_index "- [ops/index.md](ops/index.md) — ops"
run_gate
expect_exit 1 && expect_has "[Q7] docs/ops/index.md — frontmatter on a sub-index" && ok
finish

begin "Q7 root index missing okf_version is reported"
mk_conformant
printf '# Repo map\n\n- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; `Policy` API\n' > "$REPO/docs/index.md"
run_gate
expect_exit 1 && expect_has "[Q7] docs/index.md — root index missing its okf_version" && ok
finish

begin "Q7 root index with an extra key is reported"
mk_conformant
awk '{ print } /^okf_version: "0.2"$/ { print "timestamp: 2026-01-01" }' "$REPO/docs/index.md" > "$REPO/docs/index.md.tmp" && mv "$REPO/docs/index.md.tmp" "$REPO/docs/index.md"
run_gate
expect_exit 1 && expect_has "root index frontmatter carries 'timestamp:'" && ok
finish

begin "Q7 log.md is reported exactly once (not also as an orphan)"
mk_conformant
printf '# log\n' > "$REPO/docs/log.md"
run_gate
expect_exit 1 && expect_count "docs/log.md" 1 && expect_has "[Q7] docs/log.md — log.md is reserved" && ok
finish

begin "Q7 drifted index line fails; --fix rewrites it; re-check is clean"
mk_conformant
sed -i.bak 's/ — why retries use capped full jitter; `Policy` API$/ — retries, old wording/' "$REPO/docs/index.md"; rm -f "$REPO/docs/index.md.bak"
run_gate
if expect_exit 1 && expect_has "[Q7] docs/index.md:" && expect_has "drifted from retry-policy.md's description"; then
  run_gate --fix
  if expect_exit 0 && expect_has "fixed: docs/index.md:" && expect_has "rewrote 1 drifted index line"; then
    if grep -qF -- '— why retries use capped full jitter; `Policy` API' "$REPO/docs/index.md"; then
      run_gate
      expect_exit 0 && expect_not "[Q7]" && ok
    else
      bad "--fix did not write the description back"
    fi
  fi
fi
finish

begin "Q7 --fix touches only the drifted line"
mk_conformant
mk_doc second "second doc" "Body."
append_index "- [second.md](second.md) — stale text"
append_index "- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; \`Policy\` API"
before=$(grep -c '' "$REPO/docs/index.md")
run_gate --fix
after=$(grep -c '' "$REPO/docs/index.md")
if (( before == after )) && grep -qF -- '— second doc' "$REPO/docs/index.md" \
   && (( $(grep -cF -- 'why retries use capped full jitter' "$REPO/docs/index.md") == 2 )); then
  expect_exit 0 && ok
else
  bad "--fix changed line count or other lines"
fi
finish

begin "Q7 ⚠️-flagged index lines are exempt from the drift check"
mk_conformant
append_index "- ⚠️ [retry-policy.md](retry-policy.md) — recorded stale, text differs on purpose"
run_gate
expect_exit 0 && expect_not "drifted" && ok
finish

begin "Q7 index line to a bare sub-index (no description) is skipped by the drift check"
mk_conformant
mkdir -p "$REPO/docs/ops"; printf '# Ops\n' > "$REPO/docs/ops/index.md"
append_index "- [ops/index.md](ops/index.md) — authored sub-map line"
run_gate
expect_exit 0 && expect_not "drifted" && ok
finish

# --- ownership: a qualified token resolves only against its owner ---
begin "Q2 qualified token does not ride on a same-named member of another package"
mk_conformant
fx_write_other_package
mk_doc owners "ownership pairs" "Real: \`other.Nope\` and \`retry.ParsePolicy\`. Fake: \`retry.Nope\` — Nope lives in other."
append_index "- [owners.md](owners.md) — ownership pairs"
run_gate
expect_exit 1 && expect_has "\`retry.Nope\` does not resolve" \
  && expect_not "\`other.Nope\` does not resolve" && expect_not "retry.ParsePolicy" && ok
finish

begin "Q2 Type.Method does not ride on a same-named method of another receiver"
mk_conformant
mk_doc recv "receiver pairs" "Real: \`Policy.Do\`. Fake: \`Policy.Error\` — Error is errString's method."
append_index "- [recv.md](recv.md) — receiver pairs"
run_gate
expect_exit 1 && expect_has "\`Policy.Error\` does not resolve" && expect_not "\`Policy.Do\` does not resolve" && ok
finish

# --- lifecycle advisory ---
begin "Q7 lifecycle-stale target without a flagged index line is an advisory, not a violation"
mk_conformant
cat > "$REPO/docs/legacy.md" <<'EOF'
---
type: feature
description: the legacy exporter path
stale_after: 2020-01-01
---
# Legacy

Uses `Policy`.
EOF
append_index "- [legacy.md](legacy.md) — the legacy exporter path"
run_gate
expect_exit 0 && expect_has "stale by lifecycle (stale_after: 2020-01-01)" && ok
finish

begin "Q7 lifecycle advisory is silent when the index line already carries the flag"
mk_conformant
cat > "$REPO/docs/gone.md" <<'EOF'
---
type: feature
description: the removed batching mode
status: deprecated
---
# Gone

Uses `Policy`.
EOF
append_index "- ⚠️ [gone.md](gone.md) — the removed batching mode"
run_gate
expect_exit 0 && expect_not "stale by lifecycle" && ok
finish

# --- value checks ---
begin "Q7 a type outside feature/architecture/guide is reported"
mk_conformant
printf -- '---\ntype: nonsense\ndescription: a mistyped doc\n---\n# X\n' > "$REPO/docs/mistyped.md"
append_index "- [mistyped.md](mistyped.md) — a mistyped doc"
run_gate
expect_exit 1 && expect_has "'type:' must be feature, architecture, or guide" && ok
finish

begin "Q7 empty description is reported"
mk_conformant
printf -- '---\ntype: feature\ndescription:\n---\n# X\n' > "$REPO/docs/blank.md"
append_index "- [blank.md](blank.md) — anything"
run_gate
expect_exit 1 && expect_has "empty 'description:'" && ok
finish

begin "Q7 okf_version must be exactly \"0.2\", once"
mk_conformant
printf -- '---\nokf_version: 9.9\n---\n# Repo map\n\n- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; \`Policy\` API\n' > "$REPO/docs/index.md"
run_gate
expect_exit 1 && expect_has 'okf_version must be exactly "0.2"' && ok
finish

begin "Q7 duplicate okf_version keys are reported"
mk_conformant
printf -- '---\nokf_version: "0.2"\nokf_version: "0.2"\n---\n# Repo map\n\n- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; \`Policy\` API\n' > "$REPO/docs/index.md"
run_gate
expect_exit 1 && expect_has "duplicate okf_version" && ok
finish

# --- wiring is matched as a fixed string, and broken parents are broken links ---
begin "Q3 a dotted doc root never matches a look-alike path (xai vs .ai)"
mkdir -p "$REPO/.ai"
fx_write_marker "$REPO" fixture
printf -- '---\nokf_version: "0.2"\n---\n# Map\n' > "$REPO/.ai/index.md"
printf 'Start at xai/index.md.\n' > "$REPO/CLAUDE.md"
run_gate
expect_exit 1 && expect_has "[Q3]" && ok
finish

begin "Q2 link into a missing directory is a broken link, not a skip"
mk_conformant
mk_doc holes "a doc with a broken link" "See [x](missing-dir/x.md) for nothing."
append_index "- [holes.md](holes.md) — a doc with a broken link"
run_gate
expect_exit 1 && expect_has "link target does not exist: missing-dir/x.md" && ok
finish

# --- language scope ---
begin "repo with a doc root but no code files runs the structure checks only"
mk_conformant; rm -rf "$REPO/$(dirname "$FX_CODE_FILE")"
mk_doc ghost "a ghost symbol" "Uses \`SnapshotRunner\`."
append_index "- [ghost.md](ghost.md) — a ghost symbol"
run_gate
expect_exit 0 && expect_not "does not resolve" && expect_has "check-repo-brain: clean" && ok
finish

# --- scoped runs (--scope, --words) and the symbol resolver ---
LISTS=$(mktemp -d) # the scope and word lists live outside the repository they describe
begin "--scope: a code-only scope that no doc cites skips the doc checks"
mk_conformant; mk_doc orphan "an unlinked doc" "Nothing links here."
printf '%s\n' "$FX_CODE_FILE" > "$LISTS/scope.txt"
run_gate --scope "$LISTS/scope.txt"
expect_exit 0 && expect_has "scope — no doc in scope; doc checks skipped" && expect_not "orphan" && ok
finish

begin "--scope: a listed doc is checked, an unlisted orphan and the root wiring are not"
mk_conformant; mk_doc orphan "an unlinked doc" "Nothing links here."; mk_doc other "another unlinked doc" "Nothing."
rm "$REPO/CLAUDE.md" "$REPO/AGENTS.md"
printf '%s\n' "$FX_CODE_FILE" docs/orphan.md > "$LISTS/scope.txt"
run_gate --scope "$LISTS/scope.txt"
expect_exit 1 && expect_has "scope — 1 doc(s) to check" && expect_has "[Q1] docs/orphan.md — orphan" \
  && expect_not "docs/other.md" && expect_not "[Q3]" && ok
finish

begin "--scope: a doc that only names a scope file reports only its links into the scope"
mk_conformant
mk_doc linker "links the scope" "See [the old doc](gone.md) and [a missing one](missing.md); code: \`$FX_CODE_FILE\` at $FX_CODE_FILE:12."
printf '%s\n' "$FX_CODE_FILE" docs/gone.md > "$LISTS/scope.txt"
run_gate --scope "$LISTS/scope.txt"
expect_exit 1 && expect_has "0 touched" && expect_has "[Q2] docs/linker.md — link target does not exist: gone.md" \
  && expect_not "missing.md" && expect_not "orphan" && expect_not "file path or line number" && ok
finish

begin "--scope --words: a doc that cites a removed symbol is checked"
mk_conformant
mk_doc ghost "a ghost symbol" "Uses \`SnapshotRunner\` and \`OtherGhost\`."
append_index "- [ghost.md](ghost.md) — a ghost symbol"
printf '%s\n' "$FX_CODE_FILE" > "$LISTS/scope.txt"; printf 'SnapshotRunner\n' > "$LISTS/words.txt"
run_gate --scope "$LISTS/scope.txt"
expect_exit 0 && expect_has "no doc in scope" \
  && { run_gate --scope "$LISTS/scope.txt" --words "$LISTS/words.txt"; expect_exit 1; } \
  && expect_has "backticked \`SnapshotRunner\` does not resolve" && expect_not "OtherGhost" && ok
finish

begin "Q2 in a git work tree a token resolves from tracked and untracked files, never from ignored ones"
mk_conformant
printf 'build/\n' > "$REPO/.gitignore"
mkdir -p "$REPO/build"; printf 'IgnoredOnlyName\n' > "$REPO/build/gen.yaml"
printf 'TrackedName\n' > "$REPO/tracked.yaml"
mk_doc names "alert names" "Fires \`TrackedName\`, \`UntrackedName\` and \`IgnoredOnlyName\`."
append_index "- [names.md](names.md) — alert names"
(cd "$REPO" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
printf 'UntrackedName\n' > "$REPO/untracked.yaml"
run_gate
expect_exit 1 && expect_has "\`IgnoredOnlyName\` does not resolve" \
  && expect_not "\`TrackedName\` does not resolve" && expect_not "\`UntrackedName\` does not resolve" && ok
finish

begin "Q2 outside git a token does not resolve from a bazel-* output directory"
mk_conformant
mkdir -p "$REPO/bazel-out"; printf 'BazelOnlyName\n' > "$REPO/bazel-out/gen.yaml"
mk_doc bazel "bazel names" "Fires \`BazelOnlyName\`."
append_index "- [bazel.md](bazel.md) — bazel names"
run_gate
expect_exit 1 && expect_has "\`BazelOnlyName\` does not resolve" && ok
finish

begin "Q2 a dotted token resolves on whole dot-separated words only"
mk_conformant
printf 'limits:\n  key: Cfg.MaxRetries.value\n  other: Cfg.MaxRetriesX\n' > "$REPO/limits.yaml"
mk_doc dotted "dotted names" "Reads \`Cfg.MaxRetries\`; \`Cfg.MaxRetri\` is a typo."
append_index "- [dotted.md](dotted.md) — dotted names"
run_gate
expect_exit 1 && expect_has "\`Cfg.MaxRetri\` does not resolve" && expect_not "\`Cfg.MaxRetries\` does not resolve" && ok
finish
begin "Q2 two files with no final newline do not fuse their last and first words"
mk_conformant
printf 'FirstToken' > "$REPO/a.yaml"; printf 'SecondToken' > "$REPO/b.yaml"
mk_doc fused "fused names" "Fires \`FirstToken\` and \`SecondToken\`."
append_index "- [fused.md](fused.md) — fused names"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "--scope --words: a doc citing Type.Method is checked when the diff removes the type"
mk_conformant
mk_doc renamed "a renamed type" "Calls \`OldType.Run\`."
append_index "- [renamed.md](renamed.md) — a renamed type"
printf '%s\n' "$FX_CODE_FILE" > "$LISTS/scope.txt"; printf 'OldType\n' > "$LISTS/words.txt"
run_gate --scope "$LISTS/scope.txt" --words "$LISTS/words.txt"
expect_exit 1 && expect_has "backticked \`OldType.Run\` does not resolve" && ok
finish

begin "--scope: a citing doc reports a link to the listed doc, never a link to a same-named doc elsewhere"
mk_conformant
mk_doc linker2 "links two guides" "See [old](a/guide.md \"Title\") and [other](b/guide.md)."
append_index "- [linker2.md](linker2.md) — links two guides"
printf '%s\n' "$FX_CODE_FILE" docs/a/guide.md > "$LISTS/scope.txt"
run_gate --scope "$LISTS/scope.txt"
expect_exit 1 && expect_has "[Q2] docs/linker2.md — link target does not exist: a/guide.md" \
  && expect_not "b/guide.md" && ok
finish

begin "--scope: a touched doc's new description is checked against the index that lists it"
mk_conformant
sed 's/^description: .*/description: a new description/' "$REPO/docs/retry-policy.md" > "$REPO/docs/rp.tmp" && mv "$REPO/docs/rp.tmp" "$REPO/docs/retry-policy.md"
printf '%s\n' docs/retry-policy.md > "$LISTS/scope.txt"
run_gate --scope "$LISTS/scope.txt"
expect_exit 1 && expect_has "[Q7] docs/index.md:" && expect_has "drifted from retry-policy.md" && ok
finish

begin "--scope --words: a doc whose path holds a newline is skipped with one advisory line"
mk_conformant
NL=$'\n'
mk_doc "release${NL}notes" "release notes" "Uses \`SnapshotRunner\`."
printf '%s\n' "$FX_CODE_FILE" docs/retry-policy.md > "$LISTS/scope.txt"; printf 'SnapshotRunner\n' > "$LISTS/words.txt"
run_gate --scope "$LISTS/scope.txt" --words "$LISTS/words.txt"
expect_exit 0 && expect_has "scope — 2 doc(s) to check" && expect_count "the path holds a newline" 1 \
  && expect_not "can't open" && expect_not "internal scanner error" && expect_not "SnapshotRunner" && ok
finish

rm -rf "$LISTS"

# --- dependency and build-output directories, URLs in code, quoted descriptions, constants ---
begin "Q2 outside git a token does not resolve from the language's dependency or build-output directories"
mk_conformant
cites="" n=0
for d in $FX_PRUNED_DIRS; do
  n=$((n + 1)); mkdir -p "$REPO/$d/pkg"; printf 'PrunedName%s\n' "$n" > "$REPO/$d/pkg/gen.yaml"
  cites="$cites \`PrunedName$n\`"
done
mk_doc pruned "pruned names" "Fires$cites."
append_index "- [pruned.md](pruned.md) — pruned names"
run_gate
if expect_exit 1; then
  n=0 all=1
  for d in $FX_PRUNED_DIRS; do
    n=$((n + 1)); expect_has "\`PrunedName$n\` does not resolve" || { all=0; break; }
  done
  (( all )) && ok
fi
finish

begin "Q2 a symbol declared only in a dependency or build-output directory does not resolve"
mk_conformant
cites="" n=0
for d in $FX_PRUNED_DIRS; do
  n=$((n + 1)); mkdir -p "$REPO/$d/retry"
  sed "s/ParsePolicy/PrunedDecl$n/" "$REPO/$FX_CODE_FILE" > "$REPO/$d/$FX_CODE_FILE"
  cites="$cites \`PrunedDecl$n\`"
done
mk_doc pdecl "pruned declarations" "Calls$cites."
append_index "- [pdecl.md](pdecl.md) — pruned declarations"
run_gate
if expect_exit 1; then
  n=0 all=1
  for d in $FX_PRUNED_DIRS; do
    n=$((n + 1)); expect_has "\`PrunedDecl$n\` does not resolve" || { all=0; break; }
  done
  (( all )) && ok
fi
finish

begin "Q2 in a git work tree untracked files in dependency directories are never read; a tracked file under dist/ is"
mk_conformant
mkdir -p "$REPO/dist"; printf 'TrackedDistName\n' > "$REPO/dist/tracked.yaml"
(cd "$REPO" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
cites="" n=0
for d in $FX_PRUNED_DIRS; do
  n=$((n + 1)); mkdir -p "$REPO/$d/pkg"; printf 'UntrackedPrunedName%s\n' "$n" > "$REPO/$d/pkg/gen.yaml"
  cites="$cites \`UntrackedPrunedName$n\`"
done
mk_doc deps "dependency names" "Fires \`TrackedDistName\` and$cites."
append_index "- [deps.md](deps.md) — dependency names"
run_gate
if expect_exit 1 && expect_not "\`TrackedDistName\` does not resolve"; then
  n=0 all=1
  for d in $FX_PRUNED_DIRS; do
    n=$((n + 1)); expect_has "\`UntrackedPrunedName$n\` does not resolve" || { all=0; break; }
  done
  (( all )) && ok
fi
finish

begin "Q2 a docs path inside a URL in code is not a code edge"
mk_conformant
printf '\n%s Upstream: https://github.com/x/y/blob/main/docs/guide.md and <https://example.com/docs/other.md>.\n' \
  "$FX_COMMENT" >> "$REPO/$FX_CODE_FILE"
run_gate
expect_exit 0 && expect_not "[Q2]" && ok
finish

begin "Q2 a URL span ends at a tab: a local docs path after it is still a code edge"
mk_conformant
printf '\n%s See https://example.com/docs/guide.md\tdocs/missing.md here.\n' \
  "$FX_COMMENT" >> "$REPO/$FX_CODE_FILE"
run_gate
expect_exit 1 && expect_has "code edge points at missing docs/missing.md" && expect_not "missing docs/guide.md" && ok
finish

begin "Q2 a URL span in a doc ends at a tab: a file:line citation after it is still banned"
mk_conformant
mk_doc tabbed "a tab after a URL" "$(printf 'See %s\t%s:12 for it.' "$FX_URL" "$FX_CODE_FILE")"
append_index "- [tabbed.md](tabbed.md) — a tab after a URL"
run_gate
expect_exit 1 && expect_has "[Q2] docs/tabbed.md:" && expect_has "cites a file path or line number" && ok
finish

begin "Q2 a URL keeps its balanced parentheses; a path after its closing parenthesis is still a code edge"
mk_conformant
printf '\n%s See https://example.com/app/(group)/docs/guide.md here.\n%s Map: (https://example.com/app/(group)/page)docs/missing.md\n' \
  "$FX_COMMENT" "$FX_COMMENT" >> "$REPO/$FX_CODE_FILE"
run_gate
expect_exit 1 && expect_has "code edge points at missing docs/missing.md" && expect_not "missing docs/guide.md" && ok
finish

begin "Q2 a URL in a doc keeps its balanced parentheses: a path inside it is not a file:line citation"
mk_conformant
mk_doc parens "a URL with parentheses" "See https://example.com/app/(group)/$FX_CODE_FILE:12 and [src](https://example.com/(v1)/$FX_CODE_FILE:3)."
append_index "- [parens.md](parens.md) — a URL with parentheses"
run_gate
expect_exit 0 && expect_not "cites a file path" && ok
finish

begin "Q2 an apostrophe inside a bare URL stays in it; a quote that opens a URL also closes it"
mk_conformant
printf "\n%s See https://example.com/don't/docs/guide.md here.\n%s Load 'https://example.com/a'docs/missing.md\n" \
  "$FX_COMMENT" "$FX_COMMENT" >> "$REPO/$FX_CODE_FILE"
run_gate
expect_exit 1 && expect_has "code edge points at missing docs/missing.md" && expect_not "missing docs/guide.md" && ok
finish

begin "Q2 a backticked URL keeps its closing backtick: the next backticked symbol is still resolved"
mk_conformant
mk_doc ticked "a backticked URL" "See \`https://example.com/app/(group)/page\` and \`MissingThing\`."
append_index "- [ticked.md](ticked.md) — a backticked URL"
run_gate
expect_exit 1 && expect_has "backticked \`MissingThing\` does not resolve" && ok
finish

begin "Q2 an escaped apostrophe inside a single-quoted URL does not end the URL"
mk_conformant
printf '\n%s\n' "$FX_COMMENT url = 'https://example.com/don\\'t/docs/guide.md'" >> "$REPO/$FX_CODE_FILE"
run_gate
expect_exit 0 && expect_not "[Q2]" && ok
finish

begin "Q2 a local docs path next to a URL to the same path is still one code edge"
mk_conformant
printf '\n%s See docs/guide.md (https://github.com/x/y/blob/main/docs/guide.md).\n' \
  "$FX_COMMENT" >> "$REPO/$FX_CODE_FILE"
run_gate
expect_exit 1 && expect_count "code edge points at missing docs/guide.md" 1 && ok
finish

begin "a doc, a code file and a project marker whose paths hold a newline are skipped with one advisory line each, and no line opens with a question tag"
mk_conformant
NL=$'\n'
mk_doc "release${NL}notes" "release notes" "Uses \`MissingThing\` at $FX_CODE_FILE:12."
printf '%s See docs/missing.md\n' "$FX_COMMENT" > "$REPO/[Q2] new${NL}line.${FX_CODE_FILE##*.}"
mkdir -p "$REPO/sv${NL}c/docs"; fx_write_marker "$REPO/sv${NL}c" svc
run_gate
expect_exit 0 && expect_count "the path holds a newline; the gate does not check this file" 3 \
  && expect_has "docs/release\\nnotes.md — the path holds a newline" && expect_not "internal scanner error" \
  && expect_has "advisory: skip: [Q2] new\\nline." && expect_not "orphan" \
  && { ! printf '%s\n%s\n' "$OUT" "$ERR" | grep -qE '^[[:space:]]*(advisory: )?\[Q[0-9]+\] ' || bad "a skipped path opens a line with a question tag"; } \
  && ! printf '%s\n%s\n' "$OUT" "$ERR" | grep -qE '^[[:space:]]*(advisory: )?\[Q[0-9]+\] ' && ok
finish

begin "Q7 a quoted description matches its unquoted index line"
mk_conformant
printf -- '---\ntype: feature\ndescription: "how the \\"quoted\\" path works: a, b"\n---\n# Dq\n' > "$REPO/docs/dq.md"
printf -- "---\ntype: feature\ndescription: 'it''s single-quoted: c'\n---\n# Sq\n" > "$REPO/docs/sq.md"
append_index '- [dq.md](dq.md) — how the "quoted" path works: a, b'
append_index "- [sq.md](sq.md) — it's single-quoted: c"
run_gate
expect_exit 0 && expect_not "drifted" && expect_not "[Q7]" && ok
finish

begin "Q7 --fix writes a quoted description to the index without its quotes"
mk_conformant
printf -- '---\ntype: feature\ndescription: "the quoted: text"\n---\n# Dq\n' > "$REPO/docs/dq.md"
append_index "- [dq.md](dq.md) — old text"
run_gate --fix
if expect_exit 0 && expect_has "rewrote 1 drifted index line"; then
  if grep -qxF -- '- [dq.md](dq.md) — the quoted: text' "$REPO/docs/index.md"; then ok
  else bad "--fix did not write the decoded description"; fi
fi
finish

begin "Q7 a block-scalar description is reported once, and its index line is not called drifted"
mk_conformant
printf -- '---\ntype: feature\ndescription: >-\n  folded text\n---\n# Folded\n' > "$REPO/docs/folded.md"
append_index "- [folded.md](folded.md) — folded text"
run_gate
expect_exit 1 && expect_count "docs/folded.md" 1 && expect_has "[Q7] docs/folded.md — 'description:' is not one plain or quoted line" \
  && expect_not "drifted" && ok
finish

begin "Q7 a quoted description with a trailing space stays clean after --fix"
mk_conformant
printf -- '---\ntype: feature\ndescription: "guide text "\n---\n# Sp\n' > "$REPO/docs/sp.md"
append_index "- [sp.md](sp.md) — old text"
run_gate --fix
if expect_exit 0 && expect_has "rewrote 1 drifted index line"; then
  run_gate
  expect_exit 0 && expect_not "drifted" && ok
fi
finish

begin "Q7 a quoted description of only spaces is reported as empty"
mk_conformant
printf -- '---\ntype: feature\ndescription: "   "\n---\n# X\n' > "$REPO/docs/spaces.md"
append_index "- [spaces.md](spaces.md) — anything"
run_gate
expect_exit 1 && expect_has "[Q7] docs/spaces.md — empty 'description:'" && ok
finish

begin "Q7 an empty quoted description is reported as empty"
mk_conformant
printf -- '---\ntype: feature\ndescription: ""\n---\n# X\n' > "$REPO/docs/blankq.md"
append_index "- [blankq.md](blankq.md) — anything"
run_gate
expect_exit 1 && expect_has "[Q7] docs/blankq.md — empty 'description:'" && ok
finish

begin "Q2 an UPPER_SNAKE constant resolves like any symbol; an initialism stays skipped"
mk_conformant
printf 'limits:\n  RETRY_BUDGET_MAX: 3\n' > "$REPO/limits.yaml"
mk_doc consts "constants" "Caps at \`RETRY_BUDGET_MAX\`; \`MISSING_METRIC_BASE\` is gone; \`API\` and \`JSON\` are prose."
append_index "- [consts.md](consts.md) — constants"
run_gate
if [[ "$FX_CONST_SHAPE" == checked ]]; then
  expect_exit 1 && expect_count "does not resolve" 1 && expect_has "\`MISSING_METRIC_BASE\` does not resolve" && ok
else
  expect_exit 0 && expect_not "does not resolve" && ok
fi
finish

} # run_row_cases

for ROW in $FX_ROWS; do
  use_row "$ROW"
  run_row_cases
done
ROW=""

# --- row-independent ---
begin "bad repo root is a usage error (exit 2)"
begin_dir_missing="$REPO/does-not-exist"
OUT=$(bash "$GATE" "$begin_dir_missing" 2>&1); CODE=$?; ERR=""
expect_exit 2 && expect_has "not a directory" && ok
finish

fx_adapter_cases

# ========================= summary =========================
echo
if [[ -n "$GATE_REF" ]]; then
  echo "check-repo-brain_test: $pass passed, $failed failed, $diffs differ from reference"
  (( failed == 0 && diffs == 0 ))
else
  echo "check-repo-brain_test: $pass passed, $failed failed"
  (( failed == 0 ))
fi
