- **Mutation mechanics**: `npx stryker run` (StrykerJS) with a `stryker.config.mjs`
  whose `mutate` lists the leaf modules only — `src/**/parse*.ts`, reducers, a pure
  hook's helpers; `.ts`, never `.tsx` components, whose mutants are killed only
  through slow render tests, and never the whole `src/` tree — after the leaf's tests
  are green there and after each fix. `testRunner: 'vitest'` through
  `@stryker-mutator/vitest-runner` (the Jest runner where the repository tests with
  Jest) so the run reuses the repository's tests, never a second runner;
  `coverageAnalysis: 'perTest'` so only the tests covering a mutant run;
  `--incremental` between fixes; `@stryker-mutator/typescript-checker` enabled, so
  a mutant that breaks the types is reported `CompileError` and never counted as
  killed. Each mutant runs in a sandbox copy under `.stryker-tmp/`, never in the
  checkout (`inPlace` stays at its default, `false`). The `clear-text` reporter's
  `Survived` lines carry the file, the line and the replacement — that is the row to
  write. When Stryker is not installed, propose adding it with the repository's
  package manager (`yarn add -D`, `pnpm add -D`, `npm i -D` or `bun add -d`
  `@stryker-mutator/core @stryker-mutator/vitest-runner
  @stryker-mutator/typescript-checker`) and a `mutate` script beside `test` and
  `lint` in `package.json` that runs `stryker run`; check the runner's supported
  Vitest major against the repository's before proposing it. Ask first, never
  install silently, and never read a run that did not execute as a clean one.
  Stryker mutates equality, relational and logical operators, literals and optional
  chaining, so the hand check's boundary rows mostly confirm its report rather than
  cover a blind spot.
