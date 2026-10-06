| Type check | `tsc -b` where `tsconfig.json` has `references`, else `tsc --noEmit`; the lint command runs it first, so ESLint's `--fix` and Prettier never see a type error |
| Type suppression | `@ts-expect-error` over `@ts-ignore` — the same rule as `eslint-disable`, see H1 |
| TypeScript / React | the examples assume TypeScript 5 under `strict` and React 18; `satisfies` needs 4.9+, `toSorted` the ES2023 lib (else `[...xs].sort()`) |
| Tests | Vitest collects `*.test.ts` and `*.test.tsx` colocated with the module; `renderWithProviders` in `src/test-utils/`; MSW started once in the setup file |
| Package manager | read from the lockfile (`yarn.lock`, `pnpm-lock.yaml`, `package-lock.json`, `bun.lockb`); every script runs through it |
| Mutation | Stryker over leaf modules only, where the repository configures it |