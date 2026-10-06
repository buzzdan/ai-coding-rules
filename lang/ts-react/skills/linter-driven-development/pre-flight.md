1. **Verify TypeScript + React project**: `package.json` with `typescript` and `react`
   in its dependencies, plus `tsconfig.json`, in root or parent directories; note the
   TypeScript major and whether `strict` is on, and the React major — 18 and 19
   differ on `forwardRef` and `use`.
2. **Discover commands** (README.md, CLAUDE.md, the `package.json` scripts by name —
   `typecheck`/`type-check`/`tsc`, `lint`/`lintcheck`/`lint:check`, `lint:fix`,
   `format`/`formatcheck`/`format:check`, `test`/`test:run`/`vitest`/`jest`,
   `check`/`checkall` — Makefile, Taskfile.yaml, `eslint.config.*`, `tsconfig.json`
   (`references` present → `tsc -b`, else `tsc --noEmit`), `vitest.config.*`/
   `jest.config.*`, the CI workflow, in that order): test + lint commands, the
   mutation target when one exists (`mutate`, `stryker`), and which checkers the
   repository runs — `tsc`, ESLint, Prettier, Stylelint where configured. Detect the
   package manager from the lockfile (`yarn.lock` → `yarn`,
   `pnpm-lock.yaml` → `pnpm`, `package-lock.json` → `npm`, `bun.lockb` → `bun`) and
   run every script through it. Fallbacks: `npx vitest run`,
   `npx tsc --noEmit && npx eslint . --fix && npx prettier --write .`. Never bring a
   checker the repository does not configure.
