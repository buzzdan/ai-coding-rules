# Changelog

All notable changes to the `linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
