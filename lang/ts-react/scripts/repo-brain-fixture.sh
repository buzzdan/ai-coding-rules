# ---------- fixture rows: the TypeScript row this gate's adapter serves ----------
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
#   fx_write_marker <dir> <module>     write the marker for a (sub-)project
#   fx_write_conformant_code           write $FX_CODE_FILE with the cited symbols
#   fx_append_missing_edge             add a symbol whose JSDoc cites docs/backoff.md
#   fx_write_subproject_code <dir>     write <dir>'s code file: Thing, citing docs/thing.md
#   fx_write_other_package             write other/: a module declaring Nope
#   fx_adapter_cases                   detection cases; this adapter detects nothing
FX_ROWS="ts-react"

use_row() {
  FX_MARKER="package.json"
  FX_CODE_FILE="retry/policy.ts"
  FX_FENCE="typescript"
  FX_DOTTED_CONFIG="eslint.config.mjs"
  FX_GLOB1='*.d.ts'; FX_GLOB2='*.generated.ts'
  FX_EXTERNAL1="React.useState"; FX_EXTERNAL2="Intl.DateTimeFormat"
  FX_URL="https://example.github.io/retry/#Policy.Do"
}

fx_write_marker() { # <dir> <module>
  printf '{"name": "%s", "private": true}\n' "$2" > "$1/package.json"
}

# The names are the core matrix's, not idiomatic TypeScript. The module comment
# names the two external tokens: the driver exempts only lower-case qualifiers
# (`msw.http`), so a capitalised namespace such as `Intl.DateTimeFormat` resolves
# the way any undeclared token does — as a whole word in a non-markdown file.
fx_write_conformant_code() {
  mkdir -p "$REPO/retry"
  cat > "$REPO/retry/policy.ts" <<'TS'
/**
 * Retry policies. Delays are milliseconds; the dashboard renders the next
 * attempt with Intl.DateTimeFormat and keeps the attempt count in React.useState.
 */

/** Policy bounds retries. See docs/retry-policy.md for the jitter decision. */
export class Policy {
  private readonly maxAttempts: number
  private readonly base: number

  constructor(maxAttempts: number, base: number) {
    this.maxAttempts = maxAttempts
    this.base = base
  }

  Do<T>(op: () => T): T {
    return op()
  }
}

export function ParsePolicy(maxAttempts: number, base: number): Policy {
  return new Policy(maxAttempts, base)
}

export const DefaultAttempts = 3
const defaultBase = 1000

export const [ErrExhausted, ErrCancelled] = ['exhausted', 'cancelled'] as const

class errString {
  private readonly text: string

  constructor(text: string) {
    this.text = text
  }

  Error(): string {
    return this.text
  }
}
TS
}

fx_append_missing_edge() {
  cat >> "$REPO/retry/policy.ts" <<'TS'

/** Backoff computes the delay. See docs/backoff.md. */
export function Backoff(n: number): number {
  return n
}
TS
}

fx_write_subproject_code() { # <dir>
  mkdir -p "$1/src"
  cat > "$1/src/x.ts" <<'TS'
/** Thing does things. See docs/thing.md. */
export class Thing {}
TS
}

fx_write_other_package() {
  mkdir -p "$REPO/other"
  cat > "$REPO/other/other.ts" <<'TS'
/** Nope exists here, not in retry. */
export function Nope(): void {}
TS
}

fx_adapter_cases() { :; }
