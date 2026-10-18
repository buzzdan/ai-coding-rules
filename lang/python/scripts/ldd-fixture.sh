# ---------- fixture rows: the Python row this script's language block serves ----------
# The matrix runs its cases once per row. use_row sets the row's variables and
# the fx_* builders write that language's files; the cases read only these.
#
#   FX_ROWS            the row ids, space-separated
#   FX_NATIVE          of the mixed repository's languages (d, go, python,
#                      typescript), the ones this plugin's block reviews itself
#   FX_GLOB            find(1) -name pattern for the row's source files
#   FX_SRC_FILE        the production file under a layer directory: two sleep
#                      calls and one suppression directive
#   FX_SUPPRESS_LINE   the suppression directive's line, as the diff adds it
#   fx_write_marker <dir> <module>   write the project marker for a (sub-)project
#   fx_write_code                    write $FX_SRC_FILE and a test file with a sleep
#
# The gap linter's matrix (ldd-lint_test.sh) reads these as well:
#   FX_EXT             the source suffix of the files the lint cases write
#   FX_LINE_COMMENT    a comment-only line
#   FX_BLOCK_OPEN      the line that opens a block comment, "" when the
#   FX_BLOCK_CLOSE     language has none, and the line that closes it
#   FX_SKIP_FILE       a source file name a directory count leaves out
#   fx_test_file <dir> <n>             a test file's path in <dir>
#   fx_write_linter_config <max>       the repository linter config that holds
#                                      the file-length limit at <max>, counting
#                                      every line
#   fx_write_linter_config_code <max>  the config of a linter that counts only
#                                      code lines, holding the limit at <max>;
#                                      exit 1 when the language has none
#   fx_write_linter_config_unreadable  a config that names the rule with a limit
#                                      the linter table cannot read; exit 1 when
#                                      every config form is readable
FX_ROWS="python"
FX_NATIVE="python"

use_row() {
  FX_EXT='.py'
  FX_LINE_COMMENT='# note'
  FX_BLOCK_OPEN=''
  FX_BLOCK_CLOSE=''
  FX_SKIP_FILE='__init__.py'
  FX_GLOB='*.py'
  FX_SRC_FILE="services/worker.py"
  FX_SUPPRESS_LINE='CACHE: dict[str, str] = {}  # noqa: PLW0603'
}

fx_write_marker() { # <dir> <module>
  printf '[project]\nname = "%s"\nversion = "0.1.0"\n' "$2" > "$1/pyproject.toml"
}

fx_write_code() {
  mkdir -p "$REPO/services" "$REPO/tests"
  cat > "$REPO/services/worker.py" <<'PY'
"""Polling worker."""

import time

CACHE: dict[str, str] = {}  # noqa: PLW0603


def run(deadline: float) -> None:
    """Poll until the deadline."""
    while time.monotonic() < deadline:
        time.sleep(1)
    time.sleep(0.05)
PY
  cat > "$REPO/tests/test_worker.py" <<'PY'
import time


def test_run() -> None:
    time.sleep(0.01)
PY
}

fx_test_file() { printf '%s/test_m%s.py' "$1" "$2"; }

fx_write_linter_config() { # <max>
  printf '[tool.pylint.format]\nmax-module-lines = %s\n' "$1" > "$REPO/pyproject.toml"
}

# pylint counts every line; ruff has no file-length rule.
fx_write_linter_config_code() { return 1; }

fx_write_linter_config_unreadable() {
  printf '[tool.pylint.format]\nmax-module-lines = "${MODULE_LIMIT}"\n' > "$REPO/pyproject.toml"
}
