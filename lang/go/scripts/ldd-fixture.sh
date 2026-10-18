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
FX_ROWS="go"
FX_NATIVE="go"

use_row() {
  FX_EXT='.go'
  FX_LINE_COMMENT='// note'
  FX_BLOCK_OPEN='/*'
  FX_BLOCK_CLOSE='*/'
  FX_SKIP_FILE='api.pb.go'
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

# The bare-number form; the generic plugin's Go row writes the map form.
fx_write_linter_config() { # <max>
  printf 'version: "2"\nlinters:\n  settings:\n    revive:\n      rules:\n        - name: file-length-limit\n          arguments: [%s]\n        - name: exported\n' "$1" > "$REPO/.golangci.yaml"
}

fx_write_linter_config_code() { # <max>
  printf 'version: "2"\nlinters:\n  settings:\n    revive:\n      rules:\n        - name: file-length-limit\n          arguments: [{max: %s, skip-comments: true, skip-blank-lines: true}]\n' "$1" > "$REPO/.golangci.yaml"
}

fx_write_linter_config_unreadable() {
  printf '[[linters.settings.revive.rules]]\nname = "file-length-limit"\narguments = [{max = 100}]\n' > "$REPO/.golangci.toml"
}
