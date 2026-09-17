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
      ;;
    python)
      FX_MARKER="pyproject.toml"
      FX_CODE_FILE="retry/policy.py"
      FX_FENCE="python"
      FX_DOTTED_CONFIG=".ruff.toml"
      FX_GLOB1='*_pb2.py'; FX_GLOB2='*.pyi'
      FX_EXTERNAL1="datetime.timedelta"; FX_EXTERNAL2="http.client"
      FX_URL="https://example.readthedocs.io/en/latest/retry.html#Policy.Do"
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
}