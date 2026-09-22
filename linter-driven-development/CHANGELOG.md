# Changelog

All notable changes to the `linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **The Agent tool has one use in the workflow.** The linter-driven-development
  skill, the quickfix command and the refactoring skill state that refactoring runs in
  the main thread and is never delegated to a general-purpose or any other subagent,
  however many escalations there are. The lint-fixer has a budget of six lint runs and
  forty edits per spawn, twelve turns; what it did not reach returns as `ESCALATED: …
  → mechanical, budget spent` lines, and the caller spawns a fresh lint-fixer over those
  packages, at most three times and never after one reports nothing fixed; a `no
  progress` leftover is never respawned. (Token budget stage S3.)
- **Two skills on a diet.** The pre-commit-review and refactoring skills keep their
  protocols and contracts and move the long form — bundle recipe, agent output shapes,
  verdict rules, cluster pass and report example; pattern index, file and package
  routing, preparatory mode, the suppression scan, stopping criteria in full,
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
