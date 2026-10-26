# Changelog

All notable changes to the `ts-react-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **A recommended linter setup.** `setup/golangci.yaml`, `setup/ruff.toml` and
  `setup/eslint.config.ldd.mjs` enable every linter rule the routing table routes to
  a design rule, at the limits the rules name, with a way to adopt each on an
  existing codebase: golangci-lint's merge-base ratchet, ESLint's bulk
  suppressions, and ruff on changed files. `/tsr-ldd-setup` proposes them,
  and writes them only after the user agrees. The gap linter's threshold line names
  the file and rule that would hold a file-length limit; for Python, where ruff has
  no file-length rule, it says that the gap linter holds it.

- **`/tsr-ldd-setup` and the `lint-setup` skill agree a linter setup per rule.** The
  command loads the skill. The skill compares the linter setup of each project with
  the recommended setup. It finds the lint task, the CI steps and the hooks by the
  commands they run, and counts the findings at the recommended values and at the
  project's own values. It shows one table per project: for each rule that needs a
  decision, the project's value, the recommended value and the finding count at
  each. You decide per rule: `recommended`, `keep`, another value, `off` or `org`
  (the organization owns the value). The skill proposes a step for the old
  findings: tighten the config, tighten it and check new issues only, or a strict
  file that only the plugin uses. It shows the whole edit plan as one diff per file,
  and the hooks that change for each teammate's commit. It edits only after you
  agree to the plan. No step before it changes a file. You agree once, to the whole
  plan: after that yes, the skill applies every edit in one pass with no further
  prompt, writes the agreement into `.ldd-lint.yaml` from the lines that `agree`
  prints, and runs the doctor again. When `agree` fails, it stops and writes no
  record. A headless run prints the tables and the plan and stops.

- **`ldd-lint.sh doctor` compares the repository's linter with the recommended
  setup.** For each language of the repository, it lists each rule of the
  recommended config with a state: runs, missing, limit looser or limit stricter
  (the repository's setting lets more code pass, or less), options differ (the
  settings differ in a way that is not one limit), named (found by
  name in the config; the linter was not asked) or cannot verify, with the reason.
  Each row shows the recommended setting and the repository's own. The doctor asks
  the installed linter: ruff and the project's own ESLint (`eslint --print-config`,
  shared configs included) report every rule and limit, golangci-lint reports
  which linters run. The doctor runs ruff from PATH only: when ruff is not on
  PATH, the row says to put the project's ruff on PATH (for example, to
  activate the project's virtual environment). Its note names the
  golangci-lint binary on PATH and its version, so a reader can compare it with
  the version that the project pins. Where the linter cannot report a setting, the row names the
  file and key to read. An ESLint that is not installed in the project, or that
  cannot load its config, is "cannot verify": install the packages, then run the
  doctor again. `--tsv` writes the rows as seven fields; the last says whether the
  linter or a search by name gave the state. A linter output the doctor cannot
  read is "cannot verify". A golangci-lint config that fails the linter's own
  `config verify` is "cannot verify", with the linter's message. When
  `config verify` cannot run (for example, with no network for its schema), a note
  says that golangci-lint did not check the config, and why. A rule whose setting
  the installed linter does not report is "cannot verify" for that rule only: the
  other rules of that linter keep their rows. The doctor resolves the ruff
  settings for a source file with no ruff config nearer than the project root (a
  `pyproject.toml` counts only with a `[tool.ruff` section); when each file has
  one, a note names it. When the linter reads a config outside the
  git work tree (for example, in the home directory), a note names that file.
  `--root <dir>`
  points the doctor at one project of a monorepo, such as a front end with its own
  ESLint config. golangci-lint's cyclop counts as gocyclo. The doctor never edits
  a file. The doctor also reads the agreement record in `.ldd-lint.yaml`: a row
  whose rule the team agreed to keep gets the state agreed, and a row whose value
  differs from the agreed one shows the agreed value beside its own. A missing
  rule is agreed only when the team agreed it off, or the organization owns it. The
  record reads items in double quotes, in single quotes and plain, skips blank
  lines and comment lines in a list, and warns once about each other line under a
  key. The doctor
  names an agreed rule that has no row in a warning on stderr. `ldd-lint.sh agree`
  prints the record lines for `.ldd-lint.yaml`, escaped and ready to copy: a rule
  with the doctor's current value, `off` or `org`; a fingerprint of each
  golangci-lint config file the doctor compared (`--fingerprint`); the line that
  names a config file (`--lint-config`); and one line for each linter the run
  checked (`--linters`). `agree` refuses a rule whose row cannot verify, with the
  advice to upgrade the linter, and refuses a rule line of a linter that reads a
  config outside the repository; `--linters` and `--fingerprint` leave that linter
  out with a note. `--lint-config` takes only a linter of the plugin
  and a file inside the repository. The record key `linters` holds those lines, so the status
  line counts the rows of a setup that took every recommended value.
  golangci-lint reports no setting, so its drift shows through the fingerprint;
  ruff and ESLint get no fingerprint, because their rows show a changed value.
  A path in a record line is relative to the project root, also for a config above
  it (`../`). A `lint_config` item of the record, or `--config <file>`, makes the
  doctor compare another config file for one linter, and the linter's own config
  check reads that file too. In a run with two or more linters, `--linter <name>`
  names the linter of `--config`.
  `agree --fingerprint` then prints a line for that file and one for the
  repository's own config. A golangci-lint `lint_fingerprint` item whose file
  changed, or is gone, makes the doctor print
  `doctor: <path> changed since the setup was agreed` on stderr.
  `ldd-lint.sh doctor --brief` finds the projects with a record (the root and each
  directory with a tracked `.ldd-lint.yaml`) and prints one line for each project
  whose agreed setup differs from what the linter does, or whose linter cannot
  check it for a cause that is the same in every clone (the linter rejects the
  config, or the agreed config is gone). A linter that is not installed on this
  machine gives no line. It counts only the linters that the record names, so a
  plugin whose setup did not run gives no line. It prints nothing for a project
  with no `agreed` key. For each project, it lists the files of each language with
  a recommended config by extension, without a language lookup per file.
  The generic plugin's doctor skips a language when the plugin written for it is
  installed. It prints `doctor: <language> — <plugin> is installed and checks this
  language; run /<prefix>-setup`, gives that language no row, and exits 3 when
  every language in scope is skipped this way. Exit 2 stays for a run that has a
  language with no recommended config.

- **`/tsr-ldd-status` shows the lint setup line, and the lint-fixer runs the agreed
  lint task.** The status command runs `ldd-lint.sh doctor --brief`. It shows a
  "Lint setup" part only when a project with an agreed setup needs attention. The
  lint-fixer reads the project's task file, finds the lint-fix task by the command it
  runs, and uses the task that runs the `lint_config` file when the record names one
  for the linter it runs. The record is the `.ldd-lint.yaml` nearest to the scope,
  up to the repository root. It passes a package scope to the task only when the
  task accepts one. Else, with no `lint_config` item, it runs the plugin's default
  command for a package scope. With a `lint_config` item, it never runs the part of
  the default command that runs that linter: when no task runs
  that file, it stops and names `/tsr-ldd-setup`.

- **A gap linter for the design triggers no linter holds.** `scripts/ldd-lint.sh`
  measures lines per source file (`file-length`) and source files per directory
  (`package-size`). Where the repository's linter config names a file-length rule,
  the linter holds file length and the script measures none. Otherwise a
  `.ldd-lint.yaml` at the repository root sets the limits, and otherwise the
  plugin's defaults apply: 450 code lines per file, a warning at 8 source files per
  directory and the limit at 13. The first line of the output names the source of
  the limit; with the defaults it also prints a linter setting to propose to the
  repository's owners. `--tsv` writes findings as rows. The script never edits a
  file.

### Changed

- **A failed documentation gate no longer stops the review.** When
  `check-repo-brain.sh` fails — an exit other than 0 or 1, or an exit 1 with no
  violation summary — the detection pass marks the gate's questions
  `inconclusive`, prints the gate's own error line on its `R9 gate:` line, and
  runs the rest of the pass. The documentation hunter then answers those
  questions from R9's prose, and the report names the failed gate. A gate stopped
  by a signal or by an unbound variable is also a failure; before, such a run
  read as clean. Run alone, the gate still exits 2 on an internal failure.
  `CHECK_REPO_BRAIN_FAULT=<reason>` makes the gate fail on purpose, for tests
  and evals of this fallback.
- **Gate verdicts are evidence to check.** Before the documentation hunter
  reports a "does not resolve" line as a finding, it searches the whole
  repository for the symbol. A verdict the search disproves becomes a
  `gate disproved:` line in the report, not a finding. The documentation skill
  checks the gate's lines the same way, and when the gate fails during its
  self-check, it does the R9 checks by reading and says so in its report.
- **One set of thresholds.** The skills and routing tables name the same limits the
  gap linter applies: the repository linter's rule where it has one, else 450
  code lines per file and 8 and 13 files per directory. The package-size
  procedure runs the gap linter in place of a hand-written `find` command.
- **A scoped review runs the documentation gate on its scope only.** The gate
  checks the docs the diff touches in full. In a doc that names a scope file or
  cites a symbol the diff removes, it reports only those links and symbols. A
  code-only diff that no doc cites skips the doc checks. On a 6-file diff in a
  large monorepo, the detection pass took 46 seconds, down from about 90 minutes.
- **Doc symbols resolve in one pass over the repository.** In a git work tree the
  gate reads the tracked files, submodule files and untracked files that git does
  not ignore. Outside git it skips `bazel-*`, `node_modules` and other build
  output directories.
- **`ldd-detect.sh --gate-budget <seconds>`** stops a gate that runs too long and
  counts its questions `inconclusive`, never 0.
- **The two review scripts cannot disagree.** `ldd-detect.sh` reads the
  `--test-re` that `ldd-scope.sh` used. A `--glob` or `--test-re` that differs
  from the bundle is a usage error. A scope whose files are not source files of
  its language is an error, not a table of zeros.
- **`comments.txt` skips string literals.** A `#` or `//` inside a string literal
  is not a comment line.

### Fixed

- **The TypeScript declaration scan finds more declarations.** The repo-brain
  gate no longer reports these correct citations as "does not resolve":
  - a generator method such as `*entries() {`, and the class members after a
    generator method, also after `*[Symbol.iterator]() {` and `*#walk() {`
  - a name after a nested destructuring pattern that spans lines, also when a
    default value holds an object or a regex
  - every name of a one-line destructuring pattern with a type annotation, such
    as `const { a, b }: Props = useProps()`

  The scan no longer prints some words that are not declarations: a local
  variable in the body of a generator method, and a word after the `:` of an
  annotation or a default value. A doc that cites such a word as a declaration
  now fails.

- **A path that holds a newline does not stop the repo-brain gate.** The gate
  reads its file lists one path per line. A doc named `docs/release` + newline +
  `notes.md` split into two paths: the doc scan failed with "internal scanner
  error", the gate exited 2, and Q1 reported two false orphans. The gate now
  skips each doc, code file and project marker whose path holds a newline, and
  prints one advisory line for each, with the newline shown as `\n`. No markdown
  link can reach such a doc, so the gate cannot check it.

- **The repo-brain gate does not read installed dependencies.** The symbol
  fallback looked for a backticked token in every untracked file that git does not
  ignore. A token found only in a local `node_modules/` passed on a developer's
  machine and failed in CI. The gate now skips untracked files under the
  language's dependency and build-output directories. Each language adapter names
  them in `LANG_PRUNE_DIRS`. Tracked files still count, because every checkout
  has them.

- **A docs path inside a URL in code is not a code edge.** A comment such as
  `// https://github.com/x/y/blob/main/docs/guide.md` made the repo-brain gate
  report a missing local `docs/guide.md`. The gate now removes URL spans from the
  cited line before it reports a code edge, as the doc scan does. A line that
  cites the same missing path two times gives one report.

- **A quoted `description` matches its index line.** The repo-brain gate compared
  the raw text after `description:`, so `description: "how to …"` never matched
  the unquoted index line, and `--fix` copied the quotes into the index. The gate
  now decodes single-quoted and double-quoted values before the drift check and
  before `--fix` writes. A block scalar (`|` or `>`) or an escape other than `\"`
  and `\\` is a Q7 violation that says so. The gate reports `description: ""` as
  empty.

- **The repo-brain gate checks UPPER_SNAKE constants.** The gate skipped every
  backticked token with no lowercase letter, so a doc could cite a deleted
  constant such as `MISSING_METRIC_BASE`. A token with an uppercase letter and an
  underscore now resolves like any other symbol, where the language's symbol shape
  accepts it. Initialisms such as `API` and `JSON` stay skipped. A backticked
  environment variable such as `NODE_ENV` now needs a whole-word match in a
  non-markdown file of the repository.

- **The gap linter runs under bash 3.2.** macOS's `/bin/bash` stopped
  `ldd-lint.sh` with a syntax error: bash 3.2 misreads a `case` pattern inside a
  process substitution. The script now runs under bash 3.2 and bash 5.

- **A value-taking option given last no longer hangs the review scripts.** When
  `ldd-detect.sh` or `ldd-scope.sh` got an option such as `--root` or `--base` as
  its last argument, the script looped forever. It now stops with "<option> needs
  a value" and exit 2, the documented usage error.

## [2.1.0] - 2026-10-18

### Changed

- **A whole-repository review leaves the mutant question to scoped reviews.** On
  `--all`, the hunter does not judge the question "does a mutant survive a leaf's
  tests?". Its receipt reads `per-leaf, not judged`, and its `not reached:` line names
  the three leaf directories with the most hits, each as the scoped review that
  judges it (`/tsr-ldd-review <dir>`). A scoped review judges the question in full. The lead for
  the mutant question also skips `.tsx` files, `components/`, `hooks/` and `context/`.
- **The god file has a mechanical lead.** The question "is one feature's code spread
  across layer directories?" lists the longest files in scope with `wc -l` and checks
  each against `sonarjs/max-lines` (600). A file over the limit, or with
  a `max-lines` directive that silences the rule, is a violation when it stands in for the
  whole slice.
- **The review command says how to cover a large repository.** On a repository
  larger than a few dozen source files, `--all` reports `PARTIAL coverage`. The
  command names the form that covers everything: one review per directory
  (`/tsr-ldd-review <dir>`).

### Fixed

- **A claim that something is missing needs a listing.** A rule hunter that reports
  a missing test file, doc, case or cleanup now carries the `ls`, `find` or `grep`
  command that looked for it, run over the repository and not only the review's
  bundle, and that command's output. Without the listing there is no finding. A
  hunter once reported a test file as missing when it existed outside the scope.
  When the hunter's budget leaves no call for the listing, the claim appears in the
  hunter's `not reached:` line as `unverified`; the report never drops it.
- **A cluster title carries its rule ids.** The review reference shows every cluster
  title as `🔗 CLUSTER: <anchor> — <rules>`, the same form as the skill. Agents
  followed the reference, so the rule ids were on the lines below the title, and the
  report graders missed correct clusters.
- **The mutant hand check reads the error assertions.** The hand check opens the
  leaf's test file, also when the file is outside the review's scope, and reads each
  error assertion. An assertion that matches only a word all the leaf's errors share
  (`toThrow('tenant')`) lets a removed check or a changed message survive, and it is a
  violation.

## [2.0.1] - 2026-10-15

### Added

- **The review routes files of another language to the plugin installed for it.**
  The scope script tells each file's language by its extension and writes one bundle
  per language group: TypeScript and JavaScript are reviewed here; Go goes to
  `go-linter-driven-development` and Python to `python-linter-driven-development`
  when installed; any other language goes to `linter-driven-development` when
  installed; a group no installed plugin reviews is named file by file with the
  reason, never dropped. The detection pass runs once per group with the reviewing
  plugin's rules, and the report is one report with a section per language. A
  TypeScript-only diff writes the same flat bundle as before. `--lang` reviews one
  group only, the flag a plugin passes when it routes a group here.
  `scripts/ldd-scope_test.sh` is the scope script's own fixture matrix.

### Changed

- **`/tsr-ldd-autopilot` takes the request as its argument.**
  `/tsr-ldd-autopilot fix the retry bug in the API client` hands the words after the
  command to the workflow as the change to deliver. Without an argument the command
  uses the request already in the conversation, and asks what to build when there
  is none; it never starts the workflow over an empty request.

## [2.0.0] - 2026-10-06

### Changed

- **Generated from the shared core.** The plugin is rendered from the same core as
  `go-linter-driven-development` and `python-linter-driven-development` — twelve
  rules, the maxims, the design, TDD, refactoring, testing, review and documentation
  skills, the hunter/skeptic/critic review and the repo-brain gate — with TypeScript
  and React knowledge. Every canonical example is TypeScript in a React repository;
  every falsifying question carries a detect line over `.ts` and `.tsx` files.
- **`@component-designing` is `@code-designing`.** The design skill carries the
  core's name; the other five skill names are unchanged.
- **No `CLAUDE.md` in the plugin directory.** The 1.x file that instructed Claude to
  invoke the orchestrator for every change is gone; the orchestrator skill
  auto-triggers in a React project instead.
- **Commands carry the `tsr-ldd` prefix.** `/tsr-ldd-autopilot`, `/tsr-ldd-quickfix`,
  `/tsr-ldd-prepare`, `/tsr-ldd-analyze`, `/tsr-ldd-review`, `/tsr-ldd-status`;
  `/wire-repo-brain` stays unprefixed, as in the Go and Python plugins.

### Added

- **The twelve rules** under `rules/`, R1-primitive-obsession through
  R12-mutation-discipline, each a self-contained hunter rulebook with a TypeScript
  canonical example and a detect line on every falsifying question.
- **The review's detection pass and scope bundle are scripts.** `scripts/ldd-scope.sh`
  writes the bundle from the review's scope rung — a file list, the working tree, the
  branch against its base, or the whole repository — with the added comment lines
  the critic judges in `comments.txt`, and prints one summary line.
  `scripts/ldd-detect.sh` runs every detect line over the bundle and writes
  `hits.tsv`, `hits-all.tsv` and `counts.tsv`, with the suppression scan as a row;
  two runs over one tree write identical counts. Every falsifying question in
  `rules/R1` to `R12` carries a detect line beside its prose — a `grep` pattern over
  `.ts` and `.tsx` files, a `path` pattern over their paths, a reference to one of
  the R9 gate's questions, or the word `judgment` for a question the hunter can only
  read. The pre-commit review's first step runs both scripts and reads the counts
  table they print; a rule family with a hit gets one hunter carrying its rule files
  by path and its family's rows of the hits table, and the comment critic reads the
  bundle's comment lines as its inventory. What each question asks is unchanged.
- **R1 catches containers of primitives.** Two falsifying questions: Q7, a nested
  container in a signature or a field (`Map<string, string[]>`,
  `Record<string, Record<string, number>>`), always a finding; Q8, a flat
  `string[]`, `Record<string, string>` or tuple crossing a function boundary, judged
  by what its receivers do with it — a lookup, a membership test, a loop that
  filters and extracts, each one a method of a type that does not exist yet. The
  move is **Name the Container**; the lint-fixer's routing table, the refactoring
  routing table and the design skill's linter triggers carry it as a review-only
  row, because ESLint has no rule for it.
- **R7's mutation question.** Q7 asks whether a mutant survives a leaf type's
  tests: coverage is the floor, the mutation score the claim, and the move is Kill
  the surviving mutant. The TypeScript mechanics name Stryker — `npx stryker run`
  with `mutate` naming leaf modules only, never pages, hooks or the whole `src/`
  tree — and every survivor is triaged as a missing `it.each` row, dead logic or a
  recorded equivalent mutant. The workflow's pre-flight discovers a `mutate` or
  `stryker` target beside the test and lint commands, and the testing reference's
  checklist carries the row.
- **`coding-rules/ts-react.md`, the TypeScript + React coding-rules handbook.** The
  twelve rules with TypeScript examples and the binding's positions as asides, the
  house rules with their TypeScript spelling, a self-review checklist and the
  mechanics; generated from `core/handbook/` and `lang/ts-react/handbook/` in the
  same run as the plugin, and read by a team that does not develop with it.
- **Nine positions where the rules meet TypeScript and React idiom**, recorded in
  the main repository's `docs/language-residue.md`: `undefined` is the declared
  absence and `null` stops at the boundary; an optional collaborator is a module
  constant supplied by a destructuring default; a self-validating type is the one
  function that builds the value, `parseX(raw: unknown)` at the boundary and
  `readonly` fields after; the JSDoc summary line is the contract; the kept switch
  is over a discriminated union closed by `assertNever`; effects, timers and queries
  have owners and cleanups, and the race is the stale closure and the out-of-order
  response; module state is silent for constants and types, silent in `main.tsx`
  for configuration and wiring, and reported everywhere else; a component is an
  orchestrator whose logic lives in hooks and pure functions placed by R4's ladder;
  MSW is the real layer for HTTP and `vi.mock` of an internal module is R6's seam.
- **Linter routing keyed by ESLint rule ids.** The SonarJS complexity family and
  `react/no-unstable-nested-components` route to R3, `max-params` to R1,
  `sonarjs/max-lines` and `react/no-multi-comp` to R5, the typescript-eslint
  `no-unsafe-*` family at a boundary to R2, exhaustiveness and nested switches to
  R11, `react-hooks/*` and the floating-promise rules to R10,
  `import/no-mutable-exports` to R8, `no-param-reassign` and
  `sonarjs/prefer-read-only-props` to R12. Every suppression form —
  `eslint-disable` in all its spellings, `@ts-expect-error`, `@ts-ignore`,
  `@ts-nocheck`, `prettier-ignore` — is one the lint-fixer never adds.
- **The agents**: `rule-hunter`, `overabstraction-skeptic`, `comment-critic` and
  `lint-fixer`, each spawned in an isolated context and pointed by path at its rule
  files — a hunter gets its rule family's, four hunters at most, with its family's
  rows of the detection pass's hits table; the critic gets the bundle's comment
  lines.
- **Seven slash commands**: `/tsr-ldd-autopilot`, `/tsr-ldd-quickfix`,
  `/tsr-ldd-prepare`, `/tsr-ldd-analyze`, `/tsr-ldd-review`, `/tsr-ldd-status` and
  `/wire-repo-brain`.
- **Repo-brain gate with the TypeScript adapter.** `scripts/check-repo-brain.sh`
  resolves backticked symbols against functions, variables, classes and their
  members, interfaces, types and enums, owned by their module and their directory;
  a `package.json` directory outside `node_modules` marks a sub-project.
- **The six case studies under `examples/`, in TypeScript.** The over-abstraction
  rejection is a `readonly` config against a `CIDRPresence` wrapper; the storify
  case extracts an `IPConfig` leaf from a settings hook; the anti-if case dispatches
  through a `Record<Channel, …>` and a `switch` closed by `assertNever`; the
  switch-to-polymorphism case moves `fillUpdate` onto the patch kinds; dependency
  rejection replaces `import.meta.env` reads with one `AppConfig` built in
  `main.tsx`; the comment-noise verdicts fall on non-exported JSDoc.

### Removed

- **The hand-written six-skill text.** The 1.x `SKILL.md`, `reference.md` and
  `examples.md` files are replaced by the rendered core; nothing from them is
  carried over verbatim.
- **Storybook generation as a documentation step.** A story is the runnable example
  only where the repository has Storybook; the documentation skill no longer
  writes `.stories.tsx` files on its own.
- **The accessibility review checklist.** Accessibility is enforced in the linter
  phase through the repository's `jsx-a11y` configuration, where a failing rule is
  a mechanical fix, not a review hunter's finding.

### Measured against 1.x

Both plugins reviewed the `ts-react-mini` eval fixture (164 planted violations and
controls, in [buzzdan/ldd-evals](https://github.com/buzzdan/ldd-evals)) under the
same prompt and model (`claude-sonnet-5`): eight review cases whose prompt names no
slash command and whose graders carry no rule ids, then refereed finding by finding
against the manifest, by substance.

- **Whole repository.** 1.x found 53 of the 129 planted diseases a review must find,
  2.0 found 89: 42 by both, 11 by 1.x alone, 47 by 2.0 alone, 29 by neither. False
  positives on the 30 controls: 3 against 1. Cost $3.22 against $6.30.
- **Scoped cases.** 2.0 found as many or more in six of seven (retention 4/3,
  endpoint 4/2, ceremony 4/2, optional collaborators 6/4, globals 4/4, the
  798-line centerpiece 34/11 of 45); 1.x was ahead on the placement picker (3/2).
- **What 2.0 sees that 1.x never names:** tests (fused success/error tables, call
  counts on doubles, sleep-then-assert, `vi.mock` of an internal hook beside MSW
  handlers), test seams (an interface with one production implementer, hand
  doubles, a false "avoids an import cycle"), documentation (the orphan doc, its
  `file:line` citation and phantom symbol, the unwired `CLAUDE.md`), suppressions
  as findings, the comment critic's verdicts, role-named directories and the
  layer-versus-slice split, and three concurrency plants (an interval started in a
  constructor and never cleared, a check-then-await race, bare sleeps in retries).
- **What 1.x sees that 2.0 does not:** accessibility (no hunter owns it; 2.0 relies
  on the repository's `jsx-a11y` rules, which the fixture disables as the house
  style does), and the React tree in the whole-repository run, where 2.0's types
  hunter declared partial coverage and did not reach `components/`, `hooks/` or
  `pages/DeviceView/`, so the nested-component, prop-drilling and sort-in-render
  plants went unseen rather than misjudged. 1.x also raised several real bugs
  outside the manifest (a cross-tenant `lastSeen` key, a score recomputed by hand
  and drifting, `NaN` passing a port check).
- **2.0 weaknesses the run exposed:** it asserted a test file was missing that exists
  (picker), it rewrote the one WHY comment the ceremony case protects, and its
  whole-repository coverage is partial at 167 files.

## [1.2.0]

- The hand-written plugin: six skills (`@linter-driven-development`,
  `@component-designing`, `@testing`, `@refactoring`, `@pre-commit-review`,
  `@documentation`), a `CLAUDE.md` enforcing the workflow, Jest or Vitest with
  React Testing Library, Storybook stories as documentation and an accessibility
  checklist inside the review.

## [1.1.0]

- Earlier hand-written release of the six-skill plugin; no changelog was kept
  before 2.0.0.

## [1.0.0]

- Initial hand-written release of the six-skill plugin.
