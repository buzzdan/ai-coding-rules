# Changelog

All notable changes to the `linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **A recommended linter setup.** `setup/golangci.yaml`, `setup/ruff.toml` and
  `setup/eslint.config.ldd.mjs` enable every linter rule the routing table routes to
  a design rule, at the limits the rules name, with a way to adopt each on an
  existing codebase: golangci-lint's merge-base ratchet, ESLint's bulk
  suppressions, and ruff on changed files. `/ldd-setup` proposes them,
  and writes them only after the user agrees. The gap linter's threshold line names
  the file and rule that would hold a file-length limit; for Python, where ruff has
  no file-length rule, it says that the gap linter holds it.

- **`/ldd-setup` and the `lint-setup` skill agree a linter setup per rule.** The
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

- **`/ldd-status` shows the lint setup line, and the lint-fixer runs the agreed
  lint task.** The status command runs `ldd-lint.sh doctor --brief`. It shows a
  "Lint setup" part only when a project with an agreed setup needs attention. The
  lint-fixer reads the project's task file, finds the lint-fix task by the command it
  runs, and uses the task that runs the `lint_config` file when the record names one
  for the linter it runs. The record is the `.ldd-lint.yaml` nearest to the scope,
  up to the repository root. It passes a package scope to the task only when the
  task accepts one. Else, with no `lint_config` item, it runs the plugin's default
  command for a package scope. With a `lint_config` item, it never runs the part of
  the default command that runs that linter: when no task runs
  that file, it stops and names `/ldd-setup`.

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

- **House rule A1 names the lint-setup skill.** The skill is the one place that
  adds a tool or a linter rule, and it adds one only after the user agrees.
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

- **The Go declaration scan finds more declarations.** The repo-brain gate no
  longer reports these correct citations as "does not resolve":
  - every name of a list such as `var ErrFirst, ErrSecond = …`, also inside a
    grouped declaration
  - a method on a type with two or more type parameters, such as `Cache.Lookup`
    for `func (c *Cache[K, V]) Lookup`
  - a declaration after an empty group such as `var ()`

- **The Python declaration scan finds single-name assignments under every mawk.**
  mawk 1.3.4 20200120 is the default awk of Debian bookworm and bullseye and of
  Ubuntu 20.04. Its regex engine did not match `NAME = 1`, `NAME: int = 1` or
  `NAME=1` in the Python declaration program, so the repo-brain gate reported a
  correct `module.NAME` citation as "does not resolve". The program now matches
  these assignments under BWK awk, gawk and every mawk.

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
- **The documentation gate checks code in a git repository.** It found no code
  in a git repository, so it skipped every check between code and docs. Such a
  repository can now report violations that it did not report before.

## [0.6.0] - 2026-10-18

### Changed

- **A whole-repository review leaves the mutant question to scoped reviews.** On
  `--all`, the hunter does not judge the question "does a mutant survive a leaf's
  tests?". Its receipt reads `per-leaf, not judged`, and its `not reached:` line names
  the three leaf directories with the most hits, each as the scoped review that
  judges it (`/ldd-review <dir>`). A scoped review judges the question in full.
- **The god file has a mechanical lead.** The question "is one feature's code spread
  across layer directories?" lists the longest files in scope with `wc -l` and checks
  each against the repository's own file-length limit, when its linter sets one. A file over the limit, or with
  a suppression directive that silences the limit, is a violation when it stands in for the
  whole slice.
- **The review command says how to cover a large repository.** On a repository
  larger than a few dozen source files, `--all` reports `PARTIAL coverage`. The
  command names the form that covers everything: one review per directory
  (`/ldd-review <dir>`).

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

## [0.5.0] - 2026-10-15

### Added

- **The review splits a mixed diff by language and routes each part to the right
  plugin.** The scope script tells each file's language by its extension, not by
  one marker file for the whole repository, and writes one bundle per language
  group. A group whose language has its own plugin installed
  (`go-linter-driven-development`, `python-linter-driven-development`,
  `ts-react-linter-driven-development`) is reviewed by that plugin with its rules
  and agents; every other language this plugin knows — D, Rust, C and C++, Java,
  Kotlin, Ruby, shell, C#, and Go, Python, TypeScript or JavaScript when their
  plugin is not installed — is reviewed here with that
  language's comment, test-file and suppression conventions. The detection pass runs
  once per group with the reviewing plugin's rules, and the report is one report
  with a section per language; a group with no hits is reported as such. A diff of
  D files in a repository with `setup.cfg` at its root is now a D review, never
  "nothing to review"; a scope every installed plugin excludes names each file and
  why, and exits non-zero. `--glob` reviews files of a language the table does not
  know as one group; `--lang` reviews one group only, the flag a plugin passes when
  it routes a group here. `scripts/ldd-scope_test.sh` is the scope script's own
  fixture matrix, with the mixed-repository cases.

### Changed

- The language block names the languages it reviews itself and a row per language;
  the marker-file detection is gone from the review scripts. `ldd-detect.sh` reads
  the bundle's `language.txt`, or tells the language from the scope list, and
  refuses a list that spans several languages.

### Changed

- **`/ldd-autopilot` takes the request as its argument.**
  `/ldd-autopilot fix the retry bug in the API client` hands the words after the
  command to the workflow as the change to deliver. Without an argument the command
  uses the request already in the conversation, and asks what to build when there
  is none; it never starts the workflow over an empty request.

## [0.4.0] - 2026-10-06

### Added

- **R1 catches containers of primitives.** A built-in container whose parameters
  are primitives is a shape, not a concept. R1's design guidance now has three
  tiers: a flat container inside one function under a telling name is fine; a flat
  container that crosses a function boundary is judged by what its receivers do with
  it (a lookup, a membership test, a loop that filters and extracts — each one a
  method of a type that does not exist yet); a nested container is always a finding.
  Two falsifying questions detect them (Q7 nested, Q8 flat across a boundary), the
  scorecard pays +3 for a nested container and +2 for a flat one that crosses, and
  the move is **Name the Container**. R3 names the filtering loop and the inline
  expression in a `return` as methods and locals without names; R4's feature-envy
  question counts index, lookup and loop accesses on a container parameter; R2 says
  a vocabulary type that names a container carries no checks; the skeptic ships a
  telling variable name as the cheaper alternative for tier one; the design skill,
  the refactoring noun check and the lint-fixer's routing table carry the move.


## [0.3.0] - 2026-10-03

### Added

- **The review's detection pass and scope bundle are scripts.** Every falsifying
  question in `rules/R1` to `R12` now carries a detect line beside its prose — a
  `grep` pattern over the scope's source files, a `path` pattern over their paths, a
  reference to one of the R9 gate's questions, or the word `judgment` for a question
  the hunter can only read. `scripts/ldd-detect.sh` runs every detect line over a
  scope bundle and writes `hits.tsv` and `counts.tsv`, with the suppression scan as a
  row; two runs over one tree write identical counts. `scripts/ldd-scope.sh` writes
  the bundle from the review's scope rung — a file list, the working tree, the branch
  against its base, or the whole repository — with the added comment lines the
  critic judges in `comments.txt`, and prints one summary line. Both scripts have
  their own fixture matrix, `scripts/ldd-detect_test.sh`. What each question asks is
  unchanged.

- **Two leads the baseline showed missing.** The R3 flag-loop lead matches the tuple
  form (`primaryFound, secondaryFound := false, false`), and R7's mutation question
  carries a lead instead of `judgment`: a boundary comparison in production code — a
  `<=`, `>=` or length check against a literal or a length — the hand check's own
  starting point, so the tests hunter is spawned and reads the leaf's table wherever
  such a comparison is in scope.

- **The review runs on the scripts.** The pre-commit review's first step is one Bash
  call that runs `ldd-scope.sh` for the caller's scope rung and `ldd-detect.sh` over
  the bundle it wrote, and reads the counts table it prints — about 300 tokens in
  place of the Falsifying-questions sections of all twelve rules and the greps the
  parent composed from them. The suppression check is the table's `SUPPRESS` row.
  A family with a hit gets one hunter carrying every rule file of the family, its
  family's rows of the hits table and its rules' rows of the counts table beside the
  bundle: it runs no pattern of its own, judges every hit the table counted against
  its question's prose, runs the `judgment` questions by reading as before, and its
  receipts carry the table's numbers, so the report header's reconciliation is
  mechanical — a receipt below the table's count, or a question without one, renders
  `PARTIAL coverage`. The detection script also writes the hits uncapped as
  `hits-all.tsv`, where a capped question's remaining hits and every suppression
  directive are read. The scope script expands a directory argument to the source
  files under it, and a committed file named on a clean tree contributes every
  comment line to `comments.txt`, so a file review on a clean tree still reaches
  the critic; the review command hands the current-PR rung as `--base
  <merge-base>`. The Go R9 rule's WHAT-comment lead also matches methods, and the Go
  R8 rule's test-mutates-a-global lead matches any assignment to a package's
  exported name in a test. On a scoped review the R9 gate's rows are limited to the
  scope's own files: an orphan doc or an unwired root is a whole-repository finding,
  not the diff's. The comment critic reads the
  bundle's `comments.txt` as its inventory — each line carrying the code line below
  the comment, the declaration it documents — and opens a scope file only for a
  comment that line does not settle; nothing sweeps the scope for comments. The
  report's first line is `📊 CODE REVIEW REPORT`, and a finding the skeptic refuted
  keeps its own line beside its cheaper alternative. The report contract is
  unchanged.

- **Mutation testing on leaf types.** R7 now says what 100% coverage on a leaf type
  proves and what it does not: coverage is the floor, the mutation score the claim.
  A new Design-guidance bullet scopes the run to leaf packages only — never
  orchestrators, the top rung or the whole module — and triages every survivor as a
  missing table row, dead logic or a recorded equivalent mutant; a new Fix-pattern
  move, Kill the surviving mutant, and a seventh falsifying question give the hunter
  and the reviewer the same test. The mechanics bullet names the repository's own
  mutation tool, as the generic plugin does for every tool, and says what to do
  when the language has none: check the table for a row at every comparison's
  boundary and on each side of every condition, and hand-flip an operator to
  confirm a survivor; the testing skill's
  coverage targets, the review skill's hunt-focus row, the refactoring routing table
  and the code-designing test-plan row carry the same rule. When the language has a
  tool but the machine lacks it, the plugin proposes a target in the repository's
  task runner that installs and runs it, or the local install where there is none,
  and asks before installing; a run that did not execute is never a pass.

### Changed

- **The critic reads the scope in chunks and reports what changes.** On a
  whole-repository sweep the comment critic reads the numbered scope files that carry
  comments several per call, in the bundle's directory order, each call sized to come
  back whole — never one dump of the scope, which the harness spills to a file that
  the critic then re-reads page by page, the same source billed twice — and takes its
  inventory from the bundle's file list, never from a recount of the scope. Its budget
  counts every tool call — the first turn, then at most four calls on a scoped diff,
  six on a sweep, then the verdicts — and the spawn prompts of the review skill's
  step 3b and the documentation skill's critique step state how many files carry
  comments and the budget in one line. Its report is one block per TRIM, REWRITE,
  DELETE or R3 route and the tally; a KEEP is counted in the tally and never written
  as a block, where a sweep had written a hundred of them for the caller to drop.
  (Token budget stage S9.)
- **The skeptic gets extractions only.** The review skill's step 3 now says inline
  what goes to the overabstraction skeptic — a finding whose fix is a new type or
  package: R1's domain type, parameter object and named enum, R4's promotion to a
  package, R10's Extract Synchronized Owner when it names the owner, R11's dispatch
  moves — and what never does: R2's construction mechanics, an R10 fix that is a lock
  taken or a write moved under one, a rename, a deletion or a test. The exclusion
  lived only in the reference, and the whole-repository proof of S7 saw the parent
  send six such findings in one run. The skeptic's verdict schema gains
  `N/A (no extraction)` beside `N/A (R2 mechanism)` for what still arrives: one line,
  never scored, the fix shipped as the hunter wrote it.
- **The skeptic's budget holds.** The overabstraction skeptic counts every tool call
  against its budget — the first turn reads its doctrine in one command, then one
  inspection call per finding, a grep with context that prints the usage count and
  the call sites together, findings sharing a file sharing a call, then the
  verdicts — and a whole-file Read is never the way to a call site. The review skill's
  spawn prompt numbers the findings, file-mates adjacent, and states the count and
  the budget in one line. The skeptic's report is verdict lines only, evidence in the
  parentheses, a cheaper alternative on one more line, about 2k tokens for a dozen
  findings; the caller carries the verdicts verbatim and keeps nothing else. A turn ceiling in the agent's definition backstops the budget; a
  report it cuts before the verdicts ships every finding as proposed under
  `PARTIAL coverage`. (Token budget stage S7.)
- **Four rule-family hunters.** The pre-commit-review skill spawns one rule-hunter per
  rule family with pre-filter hits — types (R1, R2, R11, R12), structure (R3, R4, R5),
  tests and dependencies (R6, R7, R8, R10), documentation (R9, beside the comment
  critic) — four at most, where it spawned one per rule, up to twelve. A hunter gets
  the absolute paths of its family's rule files that had hits, reads them all in its
  first turn (ceiling about 30k tokens, from 20k), runs every rule's detection commands
  in one labelled call, and returns one receipt per falsifying question per rule and
  one tally per rule, so the report reconciles per rule as before. Its report is
  capped: finding blocks, receipts, tallies and the `not reached:` line, about 3k
  tokens, nothing else. `/ldd-review` no longer runs the tests or the linter: a
  review-only command reads code, it does not verify it; `/ldd-analyze` still runs
  all three gates. (Token budget stage S5.)
- **Two report promises are back inline.** The S1–S4 proof run rendered no cluster
  entry on Case A twice and wrote the skeptic's alternative where the Fix-pattern move
  name belongs on Case B twice; both rules had shrunk to one line in the review
  skill's step 4 when their long form moved to `reference.md`. The step now carries the
  cluster-pass example and the fix-cell rule (move name first, verdict after, the
  alternative never in its place) itself, plus two rules the graders showed were
  load-bearing: a cluster's title line carries the ids of the rules that converged on
  it, and a finding line is never wrapped for width. The same run showed the
  pre-filter, now reading only each rule's falsifying questions, skips R2 on a
  "defensive re-check" that the baseline's parent found by reading the whole rule;
  R2's question 4 now names `defensive` and `re-check` in its detection.
- **The Agent tool has one use in the workflow.** The linter-driven-development
  skill, the quickfix command and the refactoring skill state that refactoring runs in
  the main thread and is never delegated to a general-purpose or any other subagent,
  however many escalations there are. The lint-fixer has a budget of six lint runs and
  forty edits per spawn, twelve turns; what it did not reach returns as `ESCALATED: …
  → mechanical, budget spent` lines, and the caller spawns a fresh lint-fixer over those
  packages, at most three times and never after one reports nothing fixed; a `no
  progress` leftover is never respawned. (Token budget stage S3.)
- **Two skills on a diet.** The pre-commit-review and refactoring skills keep their
  protocols and contracts and move the long form — hunt-focus table, agent output shapes,
  verdict rules, cluster pass and report example; pattern index, file and package
  routing, preparatory mode, stopping criteria in full,
  multi-rule procedures — into their `reference.md`, each step naming the `sed` range
  it reads when it needs it. `<file_and_package_routing>` and `<package_decomposition>`
  now live in the refactoring skill's `reference.md`; the skills that cite them say so. A range is printed inside a Bash call the step already makes, never as a call
  of its own; the bundle recipe and the suppression scan stay inline.
  (Token budget stage S4.)
- **Hunters read the scope once.** The pre-commit-review skill writes a scope
  bundle before spawning — the file list, the diff on a scoped review, and one
  numbered file per source file, with deleted, binary, generated and very long files
  listed but not bundled — and each rule-hunter and the comment critic read their
  rule and the bundled files their leads name in their first turn, in one command,
  under a stated ceiling. On `--all` each hunter gets its own reading order over the
  directories, its rule's pre-filter hits first. The hunter and the critic have a
  budget of the first turn plus four calls, six on a whole-repository review, the
  skeptic one call per finding, and each states what it returns when the budget is
  spent: receipts for the detection commands, which ran over the whole scope in one
  call, and a `not reached:` line for what was not read to judge, which the report
  header renders beside the tally with a `PARTIAL coverage` marker. The skeptic gets
  no bundle. (Token budget stage S1.)
- **Rules by reference.** The spawn prompt carries the rule file's absolute path
  and the pre-filter leads, not the rule's text; the hunter reads its rule in its
  first turn. The skeptic and the critic get their doctrine the same way, as paths
  with the `sed` range of the section to read, from every skill that spawns them; the
  parent never reads a rule or case file to build a spawn prompt, lists the resolved
  paths before spawning, and an agent whose rule or doctrine does not read returns
  that instead of hunting from memory. (Token budget stage S2.)

## [0.2.0] - 2026-09-21

### Added

- **The coding-rules handbook, `coding-rules/generic.md`.** The standalone document
  a team reads without the plugin, generated from the same rules: the twelve rules
  with pseudocode examples in the dialect of the canonical examples, each closed by
  a `Spelling` note naming the language's form of what the fence leaves abstract;
  the shared house rules H1–H2 with neutral spelling notes; two house rules that
  exist because no binding knows the repository's language (A1, the repository's
  tooling is the tooling; A2, spell the shape in the repository's idiom); a
  self-review checklist and the mechanics of discovering the commands.

### Changed

- **A non-public symbol is "internal", not "unexported".** "Unexported" is Go's
  word; the handbook's residue gate flagged it in R4's Principle. The plugin's
  rules, skills and agents now say "internal" wherever they name the visibility of
  a symbol outside the public surface, and the two sentences that opened with the
  capitalized word, the comment critic's visibility verdict and the code-comments
  checklist, say "symbols outside the public surface".
- **The move "Replace Sentinel with comma-ok" is "Replace Sentinel with Declared
  Absence".** Move names are catalogue names shared by every language rendering,
  and comma-ok is a Go spelling; the Python handbook placed it beside the aside
  that forbids that very shape. The move's body is unchanged.
- **Two more Go spellings leave the shared text.** R11's map dispatch no longer
  reads "comma-ok on lookup" or shows a Go map literal, and R5's first falsifying
  question asks about a package *or module* named after a layer or role.
- **Three Principle sentences read the same standing alone.** R1 names raw
  strings, numbers, booleans and lists instead of Go's type spellings; R8 names
  the composition root instead of `main`; R9's Open Knowledge Format sentence
  moves from the Principle to the top of Design guidance, where the bundle policy
  it points at lives; R12 says collections instead of slices and maps, and the
  "Parse, don't validate" maxim describes a parse function instead of quoting a
  Go signature. The coding-rules handbook renders each rule's Principle without
  the language example beside it, which is where the Go spellings showed.

## [0.1.0] - 2026-09-17

### Added

- **The generic plugin.** The same core as `go-linter-driven-development` — twelve
  rules, the maxims, the design, TDD, refactoring, testing, review and documentation
  skills, the hunter/skeptic/critic review and the repo-brain gate — rendered for
  repositories without a language binding. The language is detected from the
  repository's marker file at run time; canonical examples show each rule's shape in
  language-neutral pseudocode; detection commands say what to search for over the
  detected language's source files.
- **Linter phase without a binding.** The workflow runs the linter the repository
  already configures and routes its findings by what they are about (complexity,
  length, nesting, duplication, unused, shadowing, unchecked errors); a finding it
  cannot classify is escalated by its message and attributed to its linter, never
  silenced. No linter configured is a 🟠 New Practice finding, and the review
  continues on the rules alone.
- **Repo-brain gate with a detected adapter.** `scripts/check-repo-brain.sh` picks
  its language block from the marker file: `go.mod` selects Go, `pyproject.toml`
  (or `setup.cfg`/`setup.py`) selects Python; with neither, the structure checks
  run and the first output line says the code↔docs edges are unverified. The
  fixture matrix runs once per supported language.
- Commands `/ldd-autopilot`, `/ldd-quickfix`, `/ldd-prepare`, `/ldd-analyze`,
  `/ldd-review`, `/ldd-status` and `/wire-repo-brain`.
- **The worked case files** under `examples/`, shared with the Go plugin. Their code
  is Go for demonstration only, and each says so at the top; the skeptic and the
  critic read them as their payload in this plugin exactly as in the Go one.

### Not included

- No test-harness catalogue and no hooks: those are Go-specific and ship with the Go
  plugin.
