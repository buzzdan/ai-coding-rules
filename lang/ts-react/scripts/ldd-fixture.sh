# ---------- fixture rows: the TypeScript row this script's language block serves ----------
# The matrix runs its cases once per row. use_row sets the row's variables and
# the fx_* builders write that language's files; the cases read only these.
#
#   FX_ROWS            the row ids, space-separated
#   FX_GLOB            find(1) -name pattern for the row's source files
#   FX_SRC_FILE        the production file under a layer directory: two sleep
#                      calls and one suppression directive
#   FX_SUPPRESS_LINE   the suppression directive's line, as the diff adds it
#   fx_write_marker <dir> <module>   write the project marker for a (sub-)project
#   fx_write_code                    write $FX_SRC_FILE and a test file with a sleep
FX_ROWS="ts-react"

# The row's glob is `*.ts`, not the block's `*.ts*`: the matrix derives file
# names for the files it creates from it, and `fresh.ts*` is no file name.
# Every file the row writes is a `.ts` file, so both globs select the same set.
use_row() {
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
