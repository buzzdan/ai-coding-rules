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
#   FX_SKIP_FILES      source file names a directory count leaves out
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
FX_ROWS="typescript"
FX_NATIVE="typescript"

# The row's glob is `*.ts`, not the block's `*.ts*`: the matrix derives file
# names for the files it creates from it, and `fresh.ts*` is no file name.
# Every file the row writes is a `.ts` file, so both globs select the same set.
use_row() {
  FX_LINTER_CONFIG='eslint.config.mjs'
  FX_SETUP_FILE='eslint.config.ldd.mjs'
  FX_LENGTH_RULE='sonarjs/max-lines'
  FX_LINTER_COMMENT='//'
  FX_EXT='.ts'
  FX_LINE_COMMENT='// note'
  FX_BLOCK_OPEN='/*'
  FX_BLOCK_CLOSE='*/'
  FX_SKIP_FILES='index.ts card.stories.ts'
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

fx_write_linter_config() {
  printf "export default [{\n  rules: {\n    'sonarjs/max-lines': ['error', { maximum: 400 }],\n  },\n}]\n" > "$REPO/eslint.config.mjs"
}

fx_write_linter_config_in_comment() {
  printf "export default [{\n  rules: {\n    /* 'sonarjs/max-lines': ['error', { maximum: 400 }],\n       'max-lines': ['error', 400], */\n    'no-console': 'error', // 'max-lines': ['error', 400]\n  },\n}]\n" > "$REPO/eslint.config.mjs"
}

# max-lines-per-function limits a function, not a file.
fx_write_linter_config_other() {
  printf "export default [{\n  rules: {\n    'max-lines-per-function': ['error', 50],\n    'sonarjs/max-lines-per-function': ['error', { maximum: 50 }],\n  },\n}]\n" > "$REPO/eslint.config.mjs"
}
