1. **Verify TypeScript + React project**: `package.json` naming `typescript` and `react`
   in any dependency section (`dependencies`, `devDependencies` or `peerDependencies` —
   TypeScript is usually a dev dependency, React a peer dependency in a component
   package), plus `tsconfig.json`, in root or parent directories; note the
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
   `pnpm-lock.yaml` → `pnpm`, `package-lock.json` → `npm`, `bun.lock` or the older `bun.lockb` → `bun`) and
   run every script through it. Fallbacks, in their npm spelling: `npx vitest run`,
   `npx tsc --noEmit && npx eslint . --fix && npx prettier --write .`; under another
   package manager replace `npx` with its executor (`yarn`, `pnpm exec`, `bunx`), since
   `npx` cannot see a Plug'n'Play repository's binaries. Never bring a checker the
   repository does not configure.
