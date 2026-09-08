#!/usr/bin/env bash
# Fixture matrix for check-repo-brain.sh — the gate's own conformance test.
#
# Each case builds a throwaway repo under a temp dir, runs the gate against it,
# and asserts the exit code plus the presence/absence of specific report lines.
# The matrix doubles as the language-adapter contract: a binding for another
# language must pass every case here once its adapter is spliced in (the
# code<->docs cases then use that language's files instead of .go).
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

# ---------- harness ----------
begin() { CASE="$1"; REPO=$(mktemp -d); }
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
# A minimal conformant repo: one Go package declaring the symbols the docs cite,
# a docs/ bundle with root index + one feature doc, CLAUDE.md and AGENTS.md wired.
mk_conformant() {
  mkdir -p "$REPO/docs" "$REPO/retry"
  cat > "$REPO/go.mod" <<'EOF'
module example.com/fixture

go 1.22
EOF
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

# ========================= cases =========================

# --- baseline ---
begin "clean conformant bundle exits 0"
mk_conformant; run_gate
expect_exit 0 && expect_has "check-repo-brain: clean" && expect_not "[Q" && ok
finish

begin "no doc root is an advisory no-op (exit 0)"
mkdir -p "$REPO/src"; : > "$REPO/go.mod"; run_gate
expect_exit 0 && expect_has "nothing to check yet" && ok
finish

begin "bad repo root is a usage error (exit 2)"
begin_dir_missing="$REPO/does-not-exist"
OUT=$(bash "$GATE" "$begin_dir_missing" 2>&1); CODE=$?; ERR=""
expect_exit 2 && expect_has "not a directory" && ok
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
cat >> "$REPO/retry/policy.go" <<'EOF'

// Backoff computes the delay. See docs/backoff.md.
func Backoff(n int) int { return n }
EOF
run_gate
expect_exit 1 && expect_has "[Q2] ./retry/policy.go:" && expect_has "missing docs/backoff.md" && ok
finish

begin "Q2 code→docs edge resolving inside a go.mod sub-project passes"
mk_conformant
mkdir -p "$REPO/svc/docs" "$REPO/svc/pkg"
printf 'module example.com/svc\n\ngo 1.22\n' > "$REPO/svc/go.mod"
cat > "$REPO/svc/pkg/x.go" <<'EOF'
package pkg

// Thing does things. See docs/thing.md.
type Thing struct{}
EOF
printf -- '---\nokf_version: "0.2"\n---\n# svc map\n\n- [thing.md](thing.md) — the thing\n' > "$REPO/svc/docs/index.md"
printf -- '---\ntype: feature\ndescription: the thing\n---\n# Thing\n\n`Thing` is declared in `pkg`.\n' > "$REPO/svc/docs/thing.md"
append_index "- [svc/docs/index.md](../svc/docs/index.md) — svc sub-project map"
run_gate
expect_exit 0 && expect_not "[Q2]" && expect_not "[Q3] svc" && ok
finish

begin "Q2 file:line citation is banned"
mk_conformant
mk_doc where "where things live" "The parser lives in retry/policy.go:42 and uses \`Policy\`."
append_index "- [where.md](where.md) — where things live"
run_gate
expect_exit 1 && expect_has "[Q2] docs/where.md:" && expect_has "cites a file path or line number" && ok
finish

begin "Q2 file-path ban exempts URLs, fenced blocks, and glob patterns"
mk_conformant
mk_doc paths "path exemptions" \
  "Docs: https://pkg.go.dev/example.com/fixture/retry#Policy.Do and [src](https://github.com/x/y/blob/main/retry/policy.go)." \
  "" \
  '```go' \
  "// retry/policy.go:12 — inside a fence" \
  '```' \
  "" \
  "Generated files match \`*_gen.go\` and \`*.pb.go\`."
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

begin "Q2 grouped var/const declarations and methods resolve"
mk_conformant
mk_doc decls "declaration shapes" "Constants \`DefaultAttempts\`; sentinels \`ErrExhausted\` and \`ErrCancelled\`; method \`Policy.Do\`; bare method \`Do\`."
append_index "- [decls.md](decls.md) — declaration shapes"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "Q2 package-qualified tokens: repo package resolves, external package exempt"
mk_conformant
mk_doc qual "qualified tokens" "Call \`retry.ParsePolicy\`, then \`time.Duration\` and \`http.Client\` are stdlib; \`retry.Nope\` is not declared."
append_index "- [qual.md](qual.md) — qualified tokens"
run_gate
expect_exit 1 && expect_has "\`retry.Nope\` does not resolve" && expect_not "time.Duration" && expect_not "http.Client" && expect_not "retry.ParsePolicy" && ok
finish

begin "Q2 whole-word fallback resolves non-declared tokens found in repo files"
mk_conformant
printf 'alerts:\n  - name: RetryBudgetExhausted\n' > "$REPO/alerts.yaml"
mk_doc alerts "alert names" "Fires \`RetryBudgetExhausted\` when \`Policy\` gives up."
append_index "- [alerts.md](alerts.md) — alert names"
run_gate
expect_exit 0 && expect_not "does not resolve" && ok
finish

begin "Q2 ALL-CAPS initialisms, placeholders, and dotted config names are skipped"
mk_conformant
mk_doc caps "skipped token shapes" "Set \`TTL\` and \`<docroot>\`; the linter config is \`.golangci.yaml\`; \`HTTP\` is fine."
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
printf 'module example.com/svc\n\ngo 1.22\n' > "$REPO/svc/go.mod"
printf -- '---\nokf_version: "0.2"\n---\n# svc map\n' > "$REPO/svc/docs/index.md"
append_index "- [svc/docs/index.md](../svc/docs/index.md) — svc sub-project map"
run_gate
expect_exit 0 && expect_not "[Q3] svc" && ok
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
sed -i 's/^okf_version: "0.2"$/okf_version: "0.2"\ntimestamp: 2026-01-01/' "$REPO/docs/index.md"
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
sed -i 's/ — why retries use capped full jitter; `Policy` API$/ — retries, old wording/' "$REPO/docs/index.md"
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

# --- language scope ---
begin "repo with a doc root but no code files runs the structure checks only"
mk_conformant; rm -rf "$REPO/retry"
mk_doc ghost "a ghost symbol" "Uses \`SnapshotRunner\`."
append_index "- [ghost.md](ghost.md) — a ghost symbol"
run_gate
expect_exit 0 && expect_not "does not resolve" && expect_has "check-repo-brain: clean" && ok
finish

# ========================= summary =========================
echo
if [[ -n "$GATE_REF" ]]; then
  echo "check-repo-brain_test: $pass passed, $failed failed, $diffs differ from reference"
  (( failed == 0 && diffs == 0 ))
else
  echo "check-repo-brain_test: $pass passed, $failed failed"
  (( failed == 0 ))
fi
