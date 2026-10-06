1. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `package.json` `scripts` (typecheck `typecheck`/`type-check`/`tsc`; lint
     `lintcheck`/`lint:check`/`lint`; format `formatcheck`/`format:check`; tests
     `test:run`/`test`/`vitest`/`jest`; combined `check`/`checkall`) and the lockfile for
     the package manager (`yarn.lock` → `yarn`, `pnpm-lock.yaml` → `pnpm`,
     `package-lock.json` → `npm`, `bun.lock` or the older `bun.lockb` → `bun`)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lint:` tasks)
   - `eslint.config.*`/`.eslintrc*`, `tsconfig.json` (`references` → `tsc -b`, else
     `tsc --noEmit`), `vitest.config.*`/`jest.config.*`, `.stylelintrc*`,
     `.github/workflows/*` (which checkers CI runs)

2. **Extract commands**:
   - **Test command**: `<pm> run test:run`, `<pm> test`, `npx vitest run`, `make test`, `task test`
   - **Lint command (report-only)**: this command must NOT fix. Strip any `--fix`
     flag and run the checkers in report mode: `<pm> run lintcheck` where the script
     exists, else `npx tsc --noEmit && npx eslint . && npx prettier --check .`, plus
     `npx stylelint '**/*.scss'` where the repository configures it (or the project's
     lint command with `--fix` removed and `prettier --write` turned into `--check`).

3. **Fallback to defaults** if not found (the npm spelling; under another package
   manager replace `npx` with its executor — `yarn`, `pnpm exec`, `bunx` — because
   `npx` cannot resolve a Plug'n'Play repository's binaries):
   - Test: `{{.DefaultTest}}`
   - Lint: `{{.DefaultLint}}` (no `--fix`); `npx prettier --check .` only when a
     Prettier config or dependency exists
