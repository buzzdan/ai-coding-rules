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
#   FX_COMMENT         the line-comment marker of the row's code files
#   FX_PRUNED_DIRS     the dependency and build-output directories the adapter prunes
#   FX_CONST_SHAPE     "checked" when the symbol shape takes UPPER_SNAKE constants,
#                      "skipped" when it does not
#   fx_write_marker <dir> <module>     write the marker for a (sub-)project
#   fx_write_conformant_code           write $FX_CODE_FILE with the cited symbols
#   fx_append_missing_edge             add a symbol whose docstring cites docs/backoff.md
#   fx_write_subproject_code <dir>     write <dir>'s code file: Thing, citing docs/thing.md
#   fx_write_other_package             write other/: a module declaring Nope
#   fx_adapter_cases                   Python-only cases: module-level assignment shapes
#                                      and the scope of a class body
FX_ROWS="python"

use_row() {
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

fx_adapter_cases() {
  py_assignment_case
  py_class_scope_cases
}

# py_assignment_case — a module-level assignment declares its name for the
# module and the package, with or without spaces and a type annotation.
py_assignment_case() {
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
