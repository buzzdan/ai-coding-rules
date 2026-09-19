# ---------- fixture rows: the Python row this gate's adapter serves ----------
# The matrix runs its cases once per row. use_row sets the row's variables and
# the fx_* builders write that language's files; the cases read only these.
#
#   FX_ROWS            the row ids, space-separated
#   FX_MARKER          the project marker at a project root
#   FX_CODE_FILE       the conformant code file the docs cite (declares Policy,
#                      ParsePolicy, Policy.Do, DefaultAttempts, ErrExhausted,
#                      ErrCancelled and errString.Error in module retry)
#   FX_FENCE           the fenced-block language tag
#   FX_DOTTED_CONFIG   a dotted config-file name that must be skipped as a token
#   FX_GLOB1/FX_GLOB2  generated-file glob patterns that must not read as paths
#   FX_EXTERNAL1/2     module-qualified tokens from outside the repo (exempt)
#   FX_URL             a documentation URL carrying a symbol anchor
#   fx_write_marker <dir> <module>     write the marker for a (sub-)project
#   fx_write_conformant_code           write $FX_CODE_FILE with the cited symbols
#   fx_append_missing_edge             add a symbol whose docstring cites docs/backoff.md
#   fx_write_subproject_code <dir>     write <dir>'s code file: Thing, citing docs/thing.md
#   fx_write_other_package             write other/: a module declaring Nope
#   fx_adapter_cases                   detection cases; this adapter detects nothing
FX_ROWS="python"

use_row() {
  FX_MARKER="pyproject.toml"
  FX_CODE_FILE="retry/policy.py"
  FX_FENCE="python"
  FX_DOTTED_CONFIG=".ruff.toml"
  FX_GLOB1='*_pb2.py'; FX_GLOB2='*.pyi'
  FX_EXTERNAL1="datetime.timedelta"; FX_EXTERNAL2="http.client"
  FX_URL="https://example.readthedocs.io/en/latest/retry.html#Policy.Do"
}

fx_write_marker() { # <dir> <module>
  printf '[project]\nname = "%s"\nversion = "0.1.0"\n' "$2" > "$1/pyproject.toml"
}

fx_write_conformant_code() {
  mkdir -p "$REPO/retry"
  cat > "$REPO/retry/policy.py" <<'PY'
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
PY
}

fx_append_missing_edge() {
  cat >> "$REPO/retry/policy.py" <<'PY'


def Backoff(n: int) -> int:
    """Backoff computes the delay. See docs/backoff.md."""
    return n
PY
}

fx_write_subproject_code() { # <dir>
  mkdir -p "$1/pkg"
  cat > "$1/pkg/x.py" <<'PY'
class Thing:
    """Thing does things. See docs/thing.md."""
PY
}

fx_write_other_package() {
  mkdir -p "$REPO/other"
  cat > "$REPO/other/other.py" <<'PY'
def Nope():
    """Nope exists here, not in retry."""
PY
}

fx_adapter_cases() { :; }
