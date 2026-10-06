- **Mutation mechanics**: `npx stryker run` with a `stryker.config.mjs` (or
  `stryker.conf.json`) whose `mutate` lists the leaf modules — never the whole `src/`
  tree, never components — after the leaf's tests are green there and after each
  fix; the console reporter's `Survived` lines are the survivors to triage, and the
  HTML report under `reports/mutation/` shows one mutant's diff. Mutation runs reuse
  the repository's test runner through `@stryker-mutator/vitest-runner` (or
  `@stryker-mutator/jest-runner` where the repository uses Jest), never a second
  runner; `--incremental` keeps a rerun to the files that changed. When Stryker is
  not installed, propose adding `@stryker-mutator/core` and the matching runner to
  `devDependencies` with the repository's package manager (`yarn add -D`,
  `pnpm add -D`, `npm i -D`, `bun add -d`) and a `mutate` script beside `test` and
  `lint` in `package.json` that runs `stryker run`; with no `package.json` scripts,
  propose the `npx stryker run` line for the developer to run. Ask first, never
  install silently, and never read a run that did not execute as a clean one.
