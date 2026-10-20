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
#   FX_SKIP_FILES      source file names a directory count leaves out
#   FX_ROUTED_FILE     the plugin's recommended config under setup/ for the
#                      language, which enables every rule id the refactoring
#                      routing table routes to a design rule; FX_RULE_ID_RE the
#                      shape of the language's rule ids in that table, and
#                      FX_ROUTED_SKIP the ids the config leaves out on purpose;
#                      all "" when the plugin's table names no linter rule
#   FX_SETUP_FILE      the plugin's recommended config under setup/ that holds
#                      the file-length limit, and FX_LENGTH_RULE its rule; both
#                      "" when the language's linter has no file-length rule
#   fx_test_file <dir> <n>             a test file's path in <dir>
#   FX_LINTER_CONFIG   the path, under the repository root, of the file that
#                      fx_write_linter_config writes, and FX_LINTER_COMMENT the
#                      marker that turns one of its lines into a comment
#   fx_write_linter_config           the repository linter config that names
#                                    the language's file-length rule
#   fx_write_linter_config_other     a linter config that names a rule of a
#                                    similar name and no file-length rule
#   fx_write_linter_config_in_comment  a linter config that names the file-length
#                                    rule only inside comments
FX_ROWS="python"
FX_NATIVE="python"

use_row() {
  FX_LINTER_CONFIG='pyproject.toml'
  FX_SETUP_FILE=''
  FX_ROUTED_FILE='ruff.toml'
  FX_RULE_ID_RE='^[A-Z]+[0-9]+$'
  FX_ROUTED_SKIP=''
  FX_LENGTH_RULE=''
  FX_LINTER_COMMENT='#'
  FX_EXT='.py'
  FX_LINE_COMMENT='# note'
  FX_BLOCK_OPEN=''
  FX_BLOCK_CLOSE=''
  FX_SKIP_FILES='__init__.py api_pb2.py'
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

fx_write_linter_config() {
  printf '[tool.pylint.format]\nmax-module-lines = 400\n' > "$REPO/pyproject.toml"
}

fx_write_linter_config_in_comment() {
  printf '[tool.pylint.design]\nmax-args = 4  # max-module-lines = 400 later\n' > "$REPO/pyproject.toml"
}

fx_write_linter_config_other() {
  printf '[tool.pylint.design]\nmax-args = 4\n' > "$REPO/pyproject.toml"
}
