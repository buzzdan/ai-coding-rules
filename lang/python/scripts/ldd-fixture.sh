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
FX_ROWS="python"
FX_NATIVE="python"

use_row() {
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
