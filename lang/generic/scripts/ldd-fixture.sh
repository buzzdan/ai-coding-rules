# ---------- fixture rows: one per language the detected block supports ----------
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
#   FX_ADOPTED_CONFIG  the name under which a repository keeps the plugin's
#                      recommended config as its own file and imports it; ""
#                      when the setup is copied into the linter's own config
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
FX_ROWS="go python"
FX_NATIVE="go python d typescript"

use_row() {
  case "$1" in
    go)
      FX_LINTER_CONFIG='.golangci.yml'
      FX_SETUP_FILE='golangci.yaml'
      FX_ADOPTED_CONFIG=''
      FX_ROUTED_FILE=''
      FX_RULE_ID_RE=''
      FX_ROUTED_SKIP=''
      FX_LENGTH_RULE='file-length-limit'
      FX_LINTER_COMMENT='#'
      FX_EXT='.go'
      FX_LINE_COMMENT='// note'
      FX_BLOCK_OPEN='/*'
      FX_BLOCK_CLOSE='*/'
      FX_SKIP_FILES='api.pb.go store_gen.go'
      FX_GLOB='*.go'
      FX_SRC_FILE="services/worker.go"
      FX_SUPPRESS_LINE='var cache = map[string]string{} //nolint:gochecknoglobals // TODO'
      ;;
    python)
      FX_LINTER_CONFIG='.pylintrc'
      FX_SETUP_FILE=''
      FX_ADOPTED_CONFIG=''
      FX_ROUTED_FILE=''
      FX_RULE_ID_RE=''
      FX_ROUTED_SKIP=''
      FX_LENGTH_RULE=''
      FX_LINTER_COMMENT=';'
      FX_EXT='.py'
      FX_LINE_COMMENT='# note'
      FX_BLOCK_OPEN=''
      FX_BLOCK_CLOSE=''
      FX_SKIP_FILES='__init__.py api_pb2.py'
      FX_GLOB='*.py'
      FX_SRC_FILE="services/worker.py"
      FX_SUPPRESS_LINE='CACHE: dict[str, str] = {}  # noqa: PLW0603'
      ;;
  esac
}

fx_write_marker() { # <dir> <module>
  case "$ROW" in
    go)     printf 'module example.com/%s\n\ngo 1.22\n' "$2" > "$1/go.mod" ;;
    python) printf '[project]\nname = "%s"\nversion = "0.1.0"\n' "$2" > "$1/pyproject.toml" ;;
  esac
}

fx_write_code() {
  mkdir -p "$REPO/services"
  case "$ROW" in
    go)
      cat > "$REPO/services/worker.go" <<'GO'
package services

import "time"

var cache = map[string]string{} //nolint:gochecknoglobals // TODO

// Run polls until the deadline.
func Run(deadline time.Time) {
	for time.Now().Before(deadline) {
		time.Sleep(time.Second)
	}
	time.Sleep(50 * time.Millisecond)
}
GO
      cat > "$REPO/services/worker_test.go" <<'GO'
package services_test

import (
	"testing"
	"time"
)

func TestRun(t *testing.T) {
	time.Sleep(10 * time.Millisecond)
}
GO
      ;;
    python)
      mkdir -p "$REPO/tests"
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
      ;;
  esac
}

fx_test_file() {
  case "$ROW" in
    go)     printf '%s/m%s_test.go' "$1" "$2" ;;
    python) printf '%s/test_m%s.py' "$1" "$2" ;;
  esac
}

fx_write_linter_config() {
  case "$ROW" in
    go)     printf 'linters-settings:\n  revive:\n    rules:\n      - name: file-length-limit\n        arguments:\n          - max: 400\n' > "$REPO/.golangci.yml" ;;
    python) printf '[MAIN]\nmax-module-lines=400\n' > "$REPO/.pylintrc" ;;
  esac
}

fx_write_linter_config_in_comment() {
  case "$ROW" in
    go)     printf 'version: "2" # consider file-length-limit\n' > "$REPO/.golangci.yml" ;;
    python) printf '[MAIN]\nmax-args=4  # max-module-lines=400 later\n' > "$REPO/.pylintrc" ;;
  esac
}

fx_write_linter_config_other() {
  case "$ROW" in
    go)     printf 'linters-settings:\n  revive:\n    rules:\n      - name: argument-limit\n        arguments: [4]\n' > "$REPO/.golangci.yml" ;;
    python) printf '[MAIN]\nmax-args=4\n' > "$REPO/.pylintrc" ;;
  esac
}
