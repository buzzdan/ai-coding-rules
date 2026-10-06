# TypeScript + React Linter-Driven Development

**The same engineering rules as the Go plugin, written the way a TypeScript
developer would write them for a React application.**

This Claude Code plugin is built from the same core as
[`go-linter-driven-development`](../go-linter-driven-development/README.md): twelve
design rules stated once as data, thin skills that sequence design, TDD, refactoring,
testing, review and documentation, and an evidence-based review run by fresh-context
agents. What differs is the language-shaped part: every canonical example is
TypeScript in a React repository, every detect line runs over `.ts` and `.tsx`
files, the linter routing is keyed by ESLint rule ids — typescript-eslint, SonarJS,
react-hooks — with `tsc` and Prettier beside them, and the testing skill speaks
Vitest, React Testing Library and MSW. The same rules are rendered once more as
`coding-rules/ts-react.md`, the handbook a team reads without the plugin.

Install it for a React repository: a TypeScript single-page application whose
`package.json` depends on `react`. A repository in a language without a binding
takes [`linter-driven-development`](../linter-driven-development/README.md), which
detects the language at run time; a Go repository takes the Go plugin and a Python
repository the [Python plugin](../python-linter-driven-development/README.md).

## What the plugin knows about TypeScript and React

The rules are language-neutral. Where a Go idiom in a rule has no TypeScript twin,
this plugin takes a position, and the review hunts for the TypeScript or React
disease rather than the Go one:

- **`undefined` is the declared absence; `null` is the wire's and stops at the
  boundary.** An optional property, `Map.get`, `Array.prototype.find` and a
  `T | undefined` return every caller narrows are fine under `strict`; the parser
  maps `null` to `undefined` or to a domain value. The findings are a value asserted
  into existence (`as T`, `!`, `@ts-expect-error`) where the type promises `T`,
  `null` or `undefined` returned for a failure (throw instead), callers stacking
  `?.`/`??`/`if (!x)` because the absence should have been an exception, and a prop
  typed `Cluster | null | undefined` on a component that cannot render without it.
  Never `[T, boolean]` tuples, never `-1`/`''`/`0` sentinels.
- **An optional collaborator is a module constant** (`NULL_SINK`, `SYSTEM_CLOCK`),
  the parameter typed as the collaborator and never `| undefined`, supplied by a
  destructuring default. An optional callback prop is legitimate when the component
  has a meaning without it, and the finding when every render path guards it. A
  context hook that returns `T | undefined` to every consumer is the same disease:
  `useX()` throws outside its provider and returns `T`.
- **A self-validating type is the one function that builds the value.** Types are
  erased, so the invariant lives in `parseDevice(raw: unknown): Device` at the API
  boundary, in a `parsePort`-style factory inside the domain, and in `readonly`
  fields after. A branded type with a validating constructor earns R1's invariant
  point; a bare brand or `type Alias = string` scores zero. The findings are
  `data as DeviceApiResponse` taken on faith at the boundary, `as unknown as`, and
  an object literal that bypasses the factory. A schema library is the boundary form
  where the repository already uses one; the plugin never proposes adding one.
- **The JSDoc summary line is the contract**, exempt from the comment critic's
  restatement verdict when it states it. The type system carries the WHAT, so
  `/** The cluster id */` on `clusterId: string` and `@param`/`@returns` tags that
  restate types are deleted; non-exported symbols get no comment by default. Where
  the repository's `jsdoc/require-jsdoc` demands one, a WHAT-comment is rewritten,
  never deleted.
- **The kept switch is over a discriminated union closed by `assertNever`.** That
  arm is the completeness proof the compiler checks, not an unknown-kind default; a
  `default: return null` in a render switch is the finding. A `Record<Kind, …>` of
  handlers or components comes first, a strategy object second, a class hierarchy
  last. `isLoading`/`isError`/`isEmpty` triplets become a status union; three or
  more boolean props on one component are Split Flag Argument's candidate.
- **One thread, no locks: the units are promises, effects, timers, subscriptions and
  queries.** The effect that starts one returns the cleanup that stops it; a fetch
  effect owns an `AbortController`; TanStack Query owns a fetch's lifecycle, so a
  raw fetch in `useEffect` beside a query layer is the finding. The race is the
  stale closure and the out-of-order response, guarded by abort or an `ignore` flag
  set in cleanup. Sleep is `setTimeout` polling that nothing cancels;
  `refetchInterval`, or an interval cleared in the cleanup, is the cancellable wait.
  A disabled `react-hooks/exhaustive-deps` is a suppression of this rule.
- **Module state has three lists.** Silent everywhere: constants, `as const` enums,
  types, pure functions, the `createContext` object, styles. Silent in the
  composition root (`main.tsx` / `App.tsx`): `new QueryClient()`, the router, the
  provider tree, `import.meta.env` and `window.__RUNTIME_ENV__` read once into an
  `AppConfig`. Reported everywhere else: a module-level `let`, `new ApiClient()` at
  import, a `QueryClient` stashed in a module, `import.meta.env` inside a hook or
  service, `localStorage` read at module scope, a lazily built singleton behind a
  getter. A test that `vi.stubEnv`s or `vi.mock`s a config module is evidence
  against the production code.
- **A component is an orchestrator.** Its render tree reads as the story; logic
  lives in hooks and pure functions. `react/no-unstable-nested-components` is R3's
  lint neighbor; a component past `max-lines-per-function` is the fat function.
  Extract Function (here, a custom hook) lands where R4's ladder decides:
  beside its only caller, then the page's own `hooks/`, then `src/hooks/` only when
  two pages share it. The page folder is the vertical slice; top-level
  `components/`, `hooks/`, `services/` and `types/` hold only what two pages share.
- **MSW is the real layer for HTTP.** `vi.mock` of an internal hook or service is
  R6's single-implementer seam; mocking the true boundary — the router, the auth
  SDK, `vi.useFakeTimers`, `matchMedia` — is fine. Queries by role and label first,
  `getByText` next, test ids last; `findBy*`/`waitFor` instead of a timeout; no
  `toHaveBeenCalledTimes` on an internal mock; success and error as separate `it`s,
  `it.each` rows with names.

## Opinionated

Some of what the plugin enforces is a stance, not a React community norm. It holds
them because the rules hold them in every language:

- **No `utils.ts`, no `common.ts`, no `helpers.ts`.** A module is named for the
  domain vocabulary it holds, never for its role (R4, R5).
- **No testing of non-exported functions.** The urge is a placement signal: the
  helper wants its own module, where its public API is testable (R4, R7).
- **No `vi.mock` of internal hooks and services.** MSW is the boundary. A mock of a
  module you own is a seam that exists only so a test can substitute a double — the
  same smell as a single-implementer interface. Mocking the true external boundary —
  the clock, the router, the auth SDK — is fine (R6).
- **No module singletons** outside `main.tsx`. A provider at the root and `useX()`
  below is the composition mechanism (R8).
- **`getByTestId` last.** Role and label first, text next; a test id is the query of
  last resort (R7).
- **A `renderWithProviders` helper is infrastructure; a fixture that hides the input
  is not.** A small literal in the test body beats a factory in `test-utils/` (R7).

## The linter phase

The plugin runs the checkers the repository already configures — `tsc`, ESLint and
Prettier — through the `package.json` scripts and the package manager the lockfile
names; Stylelint, where it exists, is discovered and run, never routed. It never
adds a checker the repository does not use.

- **Findings route by ESLint rule id.** `sonarjs/cognitive-complexity`,
  `sonarjs/cyclomatic-complexity`, `sonarjs/nested-control-flow`,
  `sonarjs/max-lines-per-function` and `react/no-unstable-nested-components` go to
  R3; `max-params`, `sonarjs/no-duplicate-string` on an enum-shaped literal and
  `sonarjs/max-union-size` to R1; `sonarjs/max-lines` and `react/no-multi-comp` to
  R5; `@typescript-eslint/no-explicit-any`, `no-unsafe-*` and
  `no-non-null-assertion` at a boundary to R2; `switch-exhaustiveness-check` and
  `sonarjs/no-nested-switch` to R11; `react-hooks/exhaustive-deps`,
  `react-hooks/set-state-in-effect`, `@typescript-eslint/no-floating-promises` and
  `promise/catch-or-return` to R10; `import/no-mutable-exports` to R8;
  `no-param-reassign` and `sonarjs/prefer-read-only-props` to R12. The mechanical
  row — `unused-imports/*`, `simple-import-sort/*`, `consistent-type-imports`,
  `curly`, `eqeqeq`, `jsx-a11y/*`, leaked renders, Prettier — is fixed by the
  lint-fixer in an isolated context.
- **Some findings have no ESLint rule.** Duplicated code, an import-time side
  effect, a `vi.mock` of an internal module, an interface with one implementation,
  an in-place `.sort()` on query data and the out-of-order response are review
  findings: the hunters own them alone.
- **Every suppression form is a suppression.** `// eslint-disable-next-line`,
  `// eslint-disable-line`, the block form `/* eslint-disable */`,
  `@ts-expect-error`, `@ts-ignore`, `@ts-nocheck` and `// prettier-ignore`. The
  lint-fixer never adds one and never edits `eslint.config.*`, `tsconfig*.json` or
  `.prettierrc*`; a new one in a diff is itself a review finding.
- **What it does not review.** Accessibility beyond what `jsx-a11y` flags —
  contrast, heading order, focus management, live regions — is the repository's
  axe run, which this plugin does not replace. Error-boundary placement and
  memoization (`memo`, `useMemo`, `useCallback`) are no rule's territory and are
  not reviewed.

## Architecture: Rules as Data

```
ts-react-linter-driven-development/
├── maxims.md     the uncompiled layer — named design questions above the rules
├── rules/        R1-primitive-obsession … R12-mutation-discipline   (single source of truth)
├── skills/       linter-driven-development · code-designing · refactoring ·
│                 pre-commit-review · testing · documentation   (thin directional views)
├── agents/       rule-hunter · overabstraction-skeptic · comment-critic · lint-fixer
├── commands/     tsr-ldd-analyze · autopilot · quickfix · prepare · review · status · wire-repo-brain
├── examples/     storify-leaf-type · overabstraction-cidr · dependency-rejection ·
│                 anti-if-dispatch · switch-to-polymorphism · private-comment-noise   (case law, in TypeScript)
└── scripts/      check-repo-brain.sh — repo-brain conformance gate with the TypeScript adapter
                  ldd-scope.sh · ldd-detect.sh — the review's scope bundle and detection pass
coding-rules/ts-react.md   the handbook — the same rules as one document, outside the plugin
```

- **[`rules/`](rules/)** — R1–R12, each a self-contained hunter rulebook: Principle,
  Why, a canonical before/after in TypeScript, Design guidance, a Fix pattern, and
  Falsifying questions, each with a detect line the detection script runs over
  `.ts`/`.tsx` files — a grep or path pattern, an R9 gate question, or `judgment`.
- **[`skills/`](skills/)** — thin directional views that sequence and route into the
  rules. They never restate rule content. The testing skill's
  [reference](skills/testing/reference.md) is a short Vitest, Testing Library and
  MSW harness catalogue.
- **[`agents/`](agents/)** — read-only or mechanical workers spawned in isolated
  contexts, pointed by path at the relevant rule files — a hunter gets its rule
  family's, four hunters at most — and, for hunters and the critic, at the scope
  bundle the review scripts wrote — a hunter gets its family's rows of the detection
  pass's hits table, the critic the bundle's comment lines — which they read in their
  first turn.
- **[`scripts/check-repo-brain.sh`](scripts/check-repo-brain.sh)** — the repo-brain
  gate. Its TypeScript adapter resolves backticked symbols against functions,
  variables, classes and their members, interfaces, types and enums in `.ts` and
  `.tsx` files, and treats a `package.json` directory outside `node_modules` as a
  sub-project with its own doc root.
- **[`examples/`](examples/)** — the worked case studies the rules cite, in
  TypeScript: the `readonly` config that beat a `CIDRPresence` wrapper, the
  `IPConfig` leaf a 48-line settings hook became, the alert channels dispatched
  through a `Record<Channel, …>` and a `switch` closed by `assertNever`, the export
  patches that fill their own request, `import.meta.env` pushed up to `main.tsx` as
  one `AppConfig`, and the nine non-exported JSDoc comments of a reply decoder
  judged one by one. The verdicts and decision questions are the same as the Go
  plugin's; the code is this plugin's.
- **`coding-rules/ts-react.md`** — at the repository root, outside the plugin: the
  TypeScript + React coding-rules handbook, the twelve rules with TypeScript
  examples and the binding's positions as asides, the house rules with their
  TypeScript spelling, a self-review checklist and the mechanics. Generated from
  `core/handbook/` and `lang/ts-react/handbook/` in the same run as this plugin,
  so it cannot drift from the rules; it stands alone, with no agents and no
  detect lines.

## The Five-Phase Flow

The [`@linter-driven-development`](skills/linter-driven-development/SKILL.md) skill
is the meta-orchestrator:

```
1 DESIGN     @code-designing → DESIGN PLAN → user OK
1.5 PREPARE  preparatory refactoring: survey the plan's touch points,
      four autonomous gates decide, @refactoring reshapes → prep commit(s)
2 IMPLEMENT  per behavior: RED (one failing vitest, lowest rung) → GREEN → REFACTOR
3 FULL LINT  ONE run of tsc, ESLint and Prettier via the lint-fixer agent (isolated context)
      mechanical → FIXED · design → ESCALATED → @refactoring
4 REVIEW     per completed slice: @pre-commit-review spawns hunters + skeptic + critic
5 SHIP       @documentation → commit (tests and lint green, tree dirty) → ship summary
```

## Slash Commands

| Command | Purpose | Auto-Fix |
|---------|---------|----------|
| `/tsr-ldd-autopilot` | Full workflow (Phases 1–5) | ✅ Yes |
| `/tsr-ldd-quickfix [files \| --all]` | Quality-gates loop until green over the files you are working on | ✅ Yes |
| `/tsr-ldd-prepare <change> [files]` | Preparatory refactoring ahead of a planned change | ✅ Yes |
| `/tsr-ldd-analyze [files \| --all]` | Tests + lint + review, combined report | ❌ No |
| `/tsr-ldd-review [files \| --all]` | Commit-readiness check | ❌ No |
| `/tsr-ldd-status` | Show current phase + progress | N/A |
| `/wire-repo-brain [path]` | Wire the documentation network in one pass | ✅ Wiring only |

`/wire-repo-brain` carries no prefix: the documentation network it wires is a
property of the repository, not of a language, and the Go and Python plugins offer
the same command. Installed side by side, all do the same structural work.

## Installation

```
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

Verify with `/plugin list`; it should show `ts-react-linter-driven-development (enabled)`.

## How Auto-Detection Works

When you request code work ("implement feature X", "fix the bug in the devices
page") in a React project — a `package.json` that depends on `react` — Claude detects
that the skill applies and asks for permission. Select "don't ask again for this
skill in this directory" on first use.

**Triggers auto-detection:** action verbs (`implement`, `fix`, `build`, `add`,
`refactor`, `update`, `change`, `modify`) in a React project, a mention of "ldd" or
"@ldd", or a `/tsr-ldd-*` command.

## Upgrading from 1.x

1.x was a hand-written plugin of six skills with their own text. 2.0 is generated
from the core the Go and Python plugins share, so the rules, the review and the
commands are the same body of law rendered in TypeScript. What changes for a 1.x
user:

- **`@component-designing` is now `@code-designing`.** The other skill names —
  `@linter-driven-development`, `@testing`, `@refactoring`, `@pre-commit-review`,
  `@documentation` — are unchanged.
- **No `CLAUDE.md` inside the plugin directory.** 1.x shipped one that told Claude
  to invoke the orchestrator for every change; the orchestrator skill now
  auto-triggers on its own (see How Auto-Detection Works above).
- **New:** twelve rules under `rules/` as the single source of truth, the
  hunter/skeptic/critic review, seven slash commands, the repo-brain gate with
  `/wire-repo-brain`, the two review scripts under `scripts/`, and the handbook
  `coding-rules/ts-react.md`.
- **Accessibility** is enforced through the repository's `jsx-a11y` configuration in
  the linter phase — the lint-fixer adds the `alt`, the `htmlFor`, the role — not by
  a review checklist. **Storybook** stories are no longer generated as a
  documentation step; a story is the runnable example only where the repository has
  Storybook.

## Updating and uninstalling

```
/plugin update ts-react-linter-driven-development@ai-coding-rules
```

See [CHANGELOG.md](CHANGELOG.md) for what changed between versions. To uninstall,
run `/plugin`, select "ts-react-linter-driven-development" and choose "Uninstall".

## Need Help or Want to Contribute?

Full details, the generator that renders this plugin from its core, and the Go,
Python and generic plugins it shares that core with: the
[main repository](https://github.com/buzzdan/ai-coding-rules). Found a bug or have
an idea? [Open an issue](https://github.com/buzzdan/ai-coding-rules/issues).

## License

MIT
