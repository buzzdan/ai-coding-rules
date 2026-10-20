# ---------- fixture rows: the Go row this script's language block serves ----------
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
FX_ROWS="go"
FX_NATIVE="go"

use_row() {
  FX_LINTER_CONFIG='.golangci.yaml'
  FX_SETUP_FILE='golangci.yaml'
  FX_ADOPTED_CONFIG=''
  FX_ROUTED_FILE='golangci.yaml'
  FX_RULE_ID_RE='^[a-z][a-z0-9-]*$'
  # cyclop is the alternative to gocyclo; package-size is the gap linter's
  FX_ROUTED_SKIP='cyclop package-size'
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
}

fx_write_marker() { # <dir> <module>
  printf 'module example.com/%s\n\ngo 1.22\n' "$2" > "$1/go.mod"
}

fx_write_code() {
  mkdir -p "$REPO/services"
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
}

fx_test_file() { printf '%s/m%s_test.go' "$1" "$2"; }

fx_write_linter_config() {
  printf 'version: "2"\nlinters:\n  settings:\n    revive:\n      rules:\n        - name: file-length-limit\n          arguments: [{max: 400}]\n' > "$REPO/.golangci.yaml"
}

fx_write_linter_config_in_comment() {
  printf 'version: "2" # consider file-length-limit\nlinters:\n  default: standard # "#" in a string: file-length-limit\n' > "$REPO/.golangci.yaml"
}

fx_write_linter_config_other() {
  printf 'version: "2"\nlinters:\n  settings:\n    revive:\n      rules:\n        - name: argument-limit\n          arguments: [4]\n' > "$REPO/.golangci.yaml"
}
