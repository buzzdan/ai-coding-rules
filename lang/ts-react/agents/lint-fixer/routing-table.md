| Linter failure | Route |
|---|---|
| `sonarjs/cognitive-complexity` / `sonarjs/cyclomatic-complexity` / `sonarjs/max-lines-per-function` | rules/R3-storifying.md (via @refactoring) |
| `sonarjs/nested-control-flow` / `sonarjs/no-nested-conditional` / `sonarjs/no-nested-functions` / `sonarjs/expression-complexity` / `sonarjs/elseif-without-else` | rules/R3-storifying.md (via @refactoring) |
| `react/no-unstable-nested-components` | rules/R3-storifying.md (via @refactoring); the extracted component is placed per rules/R4-helper-placement.md |
| `max-params` | rules/R1-primitive-obsession.md (Introduce Parameter Object — a `readonly` props/options type) |
| `sonarjs/no-duplicate-string` on an enum-shaped literal / `no-magic-numbers` on a domain value / `sonarjs/max-union-size` | rules/R1-primitive-obsession.md ("Name enum strings" move, or a named type) |
| `sonarjs/no-identical-functions` | rules/R1-primitive-obsession.md (extract shared type/logic); duplicated `switch`/if-chains on one discriminant → rules/R11-conditional-dispatch.md |
| `sonarjs/max-lines` (600) | rules/R5-vertical-slice.md |
| `react/no-multi-comp` | rules/R5-vertical-slice.md (one component per file; the page folder decides where the second goes) |
| `@typescript-eslint/no-explicit-any` / `no-unsafe-*` / `no-non-null-assertion` / `no-unnecessary-condition` at a boundary | rules/R2-self-validating-types.md (parse at the boundary — a guard, not an assertion) |
| `@typescript-eslint/switch-exhaustiveness-check` / `sonarjs/no-nested-switch` / `sonarjs/max-switch-cases` / `sonarjs/no-small-switch` | rules/R11-conditional-dispatch.md (via @refactoring) |
| `react-hooks/exhaustive-deps` / `react-hooks/set-state-in-effect` / `@typescript-eslint/no-floating-promises` (not fire-and-forget) / `@typescript-eslint/no-misused-promises` / `promise/catch-or-return` | rules/R10-concurrency-safety.md (via @refactoring) |
| `import/no-mutable-exports` / `no-restricted-syntax` on `import.meta.env` outside the config module | rules/R8-no-globals.md |
| `no-param-reassign` / `sonarjs/prefer-read-only-props` / `react/no-direct-mutation-state` | rules/R12-mutation-discipline.md |
| a `vi.mock` of an internal module (review-only) | rules/R6-test-only-interfaces.md |
