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
#   FX_COMMENT         the line-comment marker of the row's code files
#   FX_PRUNED_DIRS     the dependency and build-output directories the adapter prunes
#   FX_CONST_SHAPE     "checked" when the symbol shape takes UPPER_SNAKE constants,
#                      "skipped" when it does not
#   fx_write_marker <dir> <module>     write the marker for a (sub-)project
#   fx_write_conformant_code           write $FX_CODE_FILE with the cited symbols
#   fx_append_missing_edge             add a symbol whose JSDoc cites docs/backoff.md
#   fx_write_subproject_code <dir>     write <dir>'s code file: Thing, citing docs/thing.md
#   fx_write_other_package             write other/: a module declaring Nope
#   fx_adapter_cases                   TypeScript-only cases: member and destructuring shapes
FX_ROWS="ts-react"

use_row() {
  FX_MARKER="package.json"
  FX_CODE_FILE="retry/policy.ts"
  FX_FENCE="typescript"
  FX_DOTTED_CONFIG="eslint.config.mjs"
  FX_GLOB1='*.d.ts'; FX_GLOB2='*.generated.ts'
  FX_EXTERNAL1="vi.mock"; FX_EXTERNAL2="screen.getByRole"
  FX_URL="https://example.github.io/retry/#Policy.Do"
  FX_COMMENT="//"
  FX_PRUNED_DIRS="node_modules dist build .next coverage"
  FX_CONST_SHAPE="checked"
}

fx_write_marker() { # <dir> <module>
  printf '{"name": "%s", "private": true}\n' "$2" > "$1/package.json"
}

# The names are the core matrix's, not idiomatic TypeScript. The row's external
# tokens are lower-case qualifiers (`vi.mock`, `screen.getByRole`) because the
# driver exempts only those; a capitalised namespace such as `Intl.DateTimeFormat`
# resolves the way any undeclared token does — as a whole word in a non-markdown
# file — which is the same limit the Python row lives with.
fx_write_conformant_code() {
  mkdir -p "$REPO/retry"
  cat > "$REPO/retry/policy.ts" <<'TS'
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

fx_adapter_cases() {
  ts_shape_case "member, generator and multi-line destructuring names resolve" names "declaration shapes" 0 \
    "Read \`Feed.entries\`, \`Feed.latest\`, \`Bag.size\`, \`Doc.real\` and \`AfterGlob.globKept\`; settings \`shapes.tailName\`, \`shapes.one\`, \`shapes.annB\`, \`shapes.retryOpt\`, \`shapes.tailOpt\` and \`regex.afterRe\`; export \`shapes.RenamedFeed\`."
  ts_shape_case "comment text and call arguments give no declaration" ghosts "names that are not declared" 1 \
    "Not \`Doc.example\`, \`shapes.hidden\` or \`shapes.maxRetries\`."
}

# ts_shape_case <title> <doc> <description> <exit> <body> — a case over the
# files of ts_write_shapes; exit 1 expects each cited token to stay unresolved
ts_shape_case() {
  ROW=ts-react; use_row ts-react
  begin "Q2 $1"
  mk_conformant; ts_write_shapes
  mk_doc "$2" "$3" "$5"
  append_index "- [$2.md]($2.md) — $3"
  run_gate
  if (( $4 == 0 )); then
    expect_exit 0 && expect_not "does not resolve" && ok
  else
    expect_exit 1 && expect_has "\`Doc.example\` does not resolve" \
      && expect_has "\`shapes.hidden\` does not resolve" \
      && expect_has "\`shapes.maxRetries\` does not resolve" && ok
  fi
  finish
}

ts_write_shapes() {
  cat > "$REPO/retry/shapes.ts" <<'TS'
export class Feed {
  *entries() {
    yield 1
  }

  latest = 1
}

export class Bag {
  *[Symbol.iterator]() {
    yield 1
  }

  size = 0
}

export class Doc {
  /**
   *example(opts) {
   */
  real() {
    return 1
  }
}

export const { opts: {
    deep,
  },
  tailName,
} = loadSettings()

export const {
  one,
} = configure({
  hidden,
})

export {
  Feed as RenamedFeed,
}

export const { annA, annB }: Props = useProps()

export const {
  outerOpt: {
    deepOpt,
  },
  retryOpt = { count: maxRetries },
  tailOpt,
} = cfg

const glob = "src/*"

export class AfterGlob {
  *items() {
    yield 1
  }

  globKept = 1
}
TS
  cat > "$REPO/retry/regex.ts" <<'TS'
export const {
  pattern = /\[/,
  afterRe,
} = loadSettings()
TS
}
