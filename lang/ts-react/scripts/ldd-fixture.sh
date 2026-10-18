# ---------- fixture rows: the TypeScript row this script's language block serves ----------
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
FX_ROWS="typescript"
FX_NATIVE="typescript"

# The row's glob is `*.ts`, not the block's `*.ts*`: the matrix derives file
# names for the files it creates from it, and `fresh.ts*` is no file name.
# Every file the row writes is a `.ts` file, so both globs select the same set.
use_row() {
  FX_EXT='.ts'
  FX_LINE_COMMENT='// note'
  FX_BLOCK_OPEN='/*'
  FX_BLOCK_CLOSE='*/'
  FX_SKIP_FILE='index.ts'
  FX_GLOB='*.ts'
  FX_SRC_FILE="services/worker.ts"
  FX_SUPPRESS_LINE='// eslint-disable-next-line import/no-mutable-exports'
}

fx_write_marker() { # <dir> <module>
  printf '{"name": "%s", "private": true}\n' "$2" > "$1/package.json"
}

fx_write_code() {
  mkdir -p "$REPO/services"
  cat > "$REPO/services/worker.ts" <<'TS'
// Polling worker.

// eslint-disable-next-line import/no-mutable-exports
export let cache: Map<string, string> = new Map()

// Polls until the deadline.
export async function run(deadline: number): Promise<void> {
  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
  await new Promise((resolve) => setTimeout(resolve, 50))
}
TS
  cat > "$REPO/services/worker.test.ts" <<'TS'
import { it } from 'vitest'

it('runs', async () => {
  await new Promise((resolve) => setTimeout(resolve, 10))
})
TS
}

fx_test_file() { printf '%s/m%s.test.ts' "$1" "$2"; }

# ESLint's own max-lines counts every line unless told to skip comments.
fx_write_linter_config() { # <max>
  printf "export default [{\n  rules: {\n    'max-lines': ['error', { max: %s }],\n  },\n}]\n" "$1" > "$REPO/eslint.config.mjs"
}

# sonarjs/max-lines counts only code lines.
fx_write_linter_config_code() { # <max>
  printf "export default [{\n  rules: {\n    'sonarjs/max-lines': ['error', { maximum: %s }],\n    'max-lines-per-function': ['error', 50],\n  },\n}]\n" "$1" > "$REPO/eslint.config.mjs"
}

# Every ESLint config form resolves: a rule named without a limit takes
# ESLint's documented default.
fx_write_linter_config_unreadable() { return 1; }
