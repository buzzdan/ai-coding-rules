---
type: architecture
description: the linter as the authority — the recommended lint setup per binding, the gap linter for the thresholds no linter holds, the Detect-script seam, the implementer digest, three review-precision fixes, and the pull requests that ship them in order, each with its scope, files, gate and dependencies
status: draft
---
# Linter Authority

## The claim, and the half that is adopted

The claim under test: coding standards should be hidden from the agent that writes
the code and enforced in review. The whole claim is a hypothesis, and experiment 7
of [eval-return-experiments.md](eval-return-experiments.md) is where it is tested,
not adopted. The half this page builds on is narrower and already true of the
plugin's design: a rule a linter can hold is hidden from the implementer because the
gate holds it. Function size, nesting, globals, exhaustive matches and file length are
thresholds, and a threshold belongs to the linter, which runs at zero model cost and
never paraphrases. What the plugin's reviewers are for is the judgment the linter
cannot make: primitive obsession (R1), self-validating types (R2), earned interfaces
(R6), the repo brain (R9), concurrency (R10) and mutation discipline (R12).

Two consequences. First, linter-driven development works best when the linter is well
defined, so the plugin ships a recommended setup per binding and treats the
repository's linter as the authority for every threshold it owns; the plugin fills
only the gaps, with a script, never with prose. Second, the implementer needs the
rules the linter cannot hold, not the whole handbook: a digest, generated from the
same sources, under about 2k tokens.

House rule A1 of the generic handbook binds every part of this: the repository's
tooling is the tooling. Everything below that says *recommend* means propose, print
the snippet, and write nothing unless the user passes a flag.

## Where things stand

Measured on the checkout this page was written against; the numbers are the ones a
pull request below changes.

- **Handbooks** (`coding-rules/*.md`): go about 4.6k words, python 5.2k, generic
  4.9k, ts-react 6.4k; roughly 7k to 10k tokens each. Two thirds is the twelve-rules
  section with its before-and-after examples. A handbook imported from `CLAUDE.md`
  sits in the fixed context billed on every call; S8 of
  [token-budget.md](token-budget.md) measured a 10k-token block re-billed per call at
  10 to 15 percent of a scoped review's bill.
- **Detect lines**: the rendered Go plugin carries 39 grep, 2 path, 4 gate and 27
  judgment questions; `scripts/ldd-detect.sh` runs them into `hits.tsv` and
  `counts.tsv`. S6 reserved the seam for a program that writes the same table. No
  falsifying question asks whether a file is over a length limit.
- **File length** is routed on the fix side only, to R5, with three thresholds that
  drift: Go prose says over 450 lines for revive `file-length-limit`, ts-react says
  600 for `sonarjs/max-lines` or about 450 where the repository sets no limit, Python
  says about 450 and counts by hand because ruff has no file-length rule. A
  consuming repository's own revive config says 400.
- **Package size**: `hooks/check-package-sizes.sh` exists in the Go plugin only,
  hard-codes 8 and 13 files and the roots `internal/`, `cmd/`, `pkg/`, and is not
  registered: `hooks/hooks.json` is empty. No linter in any of the four ecosystems
  counts files per package.
- **Linters per design trigger**, verified: lines per file is revive
  `file-length-limit` (arguments `max`, `skip-comments`, `skip-blank-lines`, all off
  by default), `sonarjs/max-lines`, pylint `too-many-lines` (C0302, default 1000);
  ruff has no such rule. Public types per file is revive `max-public-structs`
  (default 5 per file) and, for components, `react/no-multi-comp`; Python has none.
  Files per package: none anywhere. Function size and complexity: funlen, gocognit,
  gocyclo, nestif; `sonarjs/max-lines-per-function` and
  `sonarjs/cognitive-complexity`; ruff C901, PLR0912, PLR0915, PLR1702.
- **The generator's own lint config**, `tools/ldd-gen/.golangci.yaml`, already
  enables almost every linter the Go routing table reacts to (funlen 50, gocognit 15,
  gocyclo 10, nestif 2, exhaustive, gochecknoglobals, gochecknoinits, revive
  argument-limit 4 and function-result-limit 3) but not `file-length-limit` or
  `max-public-structs`. The Go README promises "Zero configuration required".
- **Hunters**: four rule-family hunters, first turn about 30k tokens, a `not
  reached:` line and a `PARTIAL coverage` header when the budget ends the hunt. Six
  hunters were tried and rejected (same recall, 26 percent more tokens). The evidence
  protocol in `core/agents/rule-hunter.md` requires `file:line` plus an excerpt or
  command output for every finding and says nothing about what evidence a claim of
  absence needs.
- **Comment critic**: eager by design ("when uncertain, it fails"); its graders passed
  in every eval run.
- **R7 Q7**, the mutation survivor, has a grep lead for boundary comparisons in
  every binding and prose that says "for each new or changed leaf type"; on `--all`
  that is every leaf, and the mutation tool run it asks for is not a hunter's work.
- **Experiment 7** has five referee rows, every one of which gives the implementer
  the handbook. No row hides the rules from the implementer. Gate 1 is two Sonnet
  cells, about $80. Nothing in experiments 7 or 8 has run.

## Design

### Thresholds are profile scalars

Three new scalars in every `profile.yaml`, substituted wherever a number appears
today, so prose, generated config and script cannot disagree *(planned)*:

| Scalar | Value | Why this value |
|---|---|---|
| file_max_lines | 450 | the number the Go and Python prose already use, and the number the ts-react prose falls back to when the repository sets none; 600 was SonarJS's own figure carried in, not a design choice, and 400 is one repository's setting, which the authority rule honours anyway: the repository's linter wins |
| package_warn_files | 8 | the Go hook's yellow zone, unchanged |
| package_max_files | 13 | the Go hook's red zone, unchanged |

The count behind file_max_lines is lines of code: blank lines and comment-only lines
are skipped, which is revive's `skip-comments` and `skip-blank-lines` both on, so the
recommended Go config and the gap linter agree on one file. Whether
`sonarjs/max-lines` counts the same way is confirmed in the fixture matrix of the pull
request that ships the script, and the ts-react config carries the answer as a
comment. Package size counts the language's non-test source files in one directory,
minus the files the language block excludes: generated files for Go, `__init__.py`
and `conftest.py` for Python, `index.ts`, declaration files and stories for
TypeScript. All four bindings carry the same three values; the generic binding too,
since every core template scalar must render.

Every literal 400, 450, 600, 8 or 13 under `core/` and `lang/` that means one of
these becomes its scalar: the Go and Python and ts-react file-and-package routing
includes, the Go README's routing line, the lint-fixer routing tables and the Go
hook's two constants. The check is one grep for those numbers over `core/` and
`lang/` after the change, with the remaining hits read and justified in the pull
request.

### The gap linter

`scripts/ldd-lint.sh` *(planned)* is a core template rendered into every plugin,
beside `ldd-detect.sh`, reading the same `scripts/ldd-lang.sh` include for everything
the language decides. It is not a manual linter: it runs unattended, as a hook, in a
detect line and from the setup command, wherever the real linter has a gap.

Subcommands:

| Subcommand | What it measures | Threshold |
|---|---|---|
| `file-length` | lines of code per source file in scope | file_max_lines |
| `package-size` | non-test source files per directory in scope | package_warn_files, package_max_files |
| `doctor` | which recommended rules the repository's linter config enables, at which thresholds, and which the gap linter is covering | the expectation table the setup renders (below) |
| `public-types` | public type declarations per file | later; see "Not in this round" |

Threshold resolution, in order, printed once per run as a `threshold:` line so the
caller always sees where a number came from:

1. **The repository's linter config enables the rule.** Go: revive `file-length-limit`
   in `.golangci.yaml` or `.golangci.yml` and its `max`; ts-react: `max-lines` or
   `sonarjs/max-lines` with a number in an eslint config; Python: pylint
   `max-module-lines` in `pyproject.toml` or `.pylintrc`. The line reads `covered by
   revive file-length-limit (max 400)` and the script runs with that number, so the
   review sees the findings the linter would report. A config file that exists but
   the script cannot read prints `unreadable, using the profile default`; it never
   falls back silently.
2. **A repository override**, `.ldd-lint.yaml` *(planned)* at the repository root,
   flat keys named like the scalars. Read only; nothing in the plugin writes it
   except the setup command under `--write`. This is what a repository uses for
   package size, which no linter holds.
3. **The binding's profile default**, with one warning row that prints the exact
   snippet to add to the repository's linter config, taken from the rendered
   recommended setup.

Output contract, shared with the detect line and the hook:

- `--files <list> --root <dir>`: the scope, in the shape `ldd-detect.sh` already
  passes; without `--files`, every source file under `--root`.
- `--tsv`: one row per finding, `path TAB line TAB message`, where line is 0 for a
  whole-file or whole-directory finding and the message carries the measured value,
  the limit and its source: `612 code lines (limit 450, profile default)`.
- Without `--tsv`: the same findings as report lines for a human or a hook.
- Exit 0 with or without findings; exit 2 when it could not measure (no scope, a
  config it was told to read and could not), so a caller treats 2 as inconclusive,
  as `ldd-detect.sh` treats the R9 gate.
- `--changed <path>`, for the hook: measure only the file named and its directory.

The hook: `hooks/hooks.json` moves from the Go binding's passthrough into `core/`,
registered this time, and runs `ldd-lint.sh package-size --changed` after `Write`,
`Edit` and `MultiEdit`, reading the edited path from the hook's JSON on stdin with
`sed`, no `jq`. A red zone exits 2 with the three design questions on stderr, as the
Go hook does today; a yellow zone prints an advisory; a path that is not a source
file of the language returns at once. `check-package-sizes.sh` and its roots list are
deleted. The hook is the one place the gap linter blocks; everywhere else it reports.

### The recommended setup

One source per binding, `lang/<binding>/setup/lint-rules.yaml` *(planned)*: one
entry per linter rule the plugin wants on, with the linter, the rule id, the setting
key, the threshold as a scalar reference or a literal, the plugin rule it feeds
(R3, R5, R8, R11) and a one-line reason a reader sees as a comment. The generator
reads it and writes two things into the plugin directory *(planned)*:

| Output | Go | ts-react | Python | generic |
|---|---|---|---|---|
| the commented config | `setup/golangci.yaml`, a complete v2 file with `new-from-merge-base` as the ratchet and test files excluded from the size linters | `setup/eslint.config.ldd.mjs`, a flat-config fragment to spread into the repository's config | `setup/ruff-pylint.toml`, a `[tool.ruff.lint]` block and a pylint block | none; the generic profile names no setup |
| the expectation table | `setup/expectations.tsv`: linter, rule, setting, threshold, feeds, reason, one row per entry; what `doctor` compares the repository against | same | same | none |

The shapes are three small Go functions in the generator, one per config dialect,
with a unit test each that renders a fixed yaml and compares bytes; a fourth dialect
is a fourth function. The yaml is itself a template, so a threshold is written as
the scalar and rendered before parsing. A Taskfile fragment, `setup/Taskfile.ldd.yaml`
*(planned)*, is a core template with three tasks: `lint` over the files changed
against the merge base, `lintwithfix`, and `ldd-lint`, which runs the gap linter's
`doctor`; the generic binding renders it with its instruction phrases, as it renders
everything else. Go's `max-public-structs` is enabled at its default of 5 in the Go
config, because the linter holds it; the gap linter has no `public-types` subcommand
for Go.

The routing tables keep their rows as prose, because a row carries judgment (which
rule owns the repair, what to do when two apply) and not only a threshold. What the
yaml adds is a check in `task lint-core`: every rule id in a binding's yaml appears in
that binding's routing-table include, and no routing-table row names a threshold
number; the number is the scalar. This departs from the decision to render the
routing rows from the yaml, for one reason: the rows that matter most (`dupl`,
`exhaustive`, `go test -race`) are not threshold rules and have no place in the yaml.

The Go README's "Zero configuration required" becomes: zero configuration to run; the
recommended setup makes the design triggers fire. The same sentence lands in the
other three READMEs with their file names.

### The Detect-script kind and the scope flag

The detect-line contract of S8 gains one kind and one flag *(planned)*:

| Detect line | What the script does |
|---|---|
| `Detect-script: <name> <args>` | runs `scripts/<name>.sh <args> --files <scope> --root <root> --tsv` beside itself and records the rows as hits, through the same capped `record` path grep hits take; the script's exit 2 ends the detection pass as inconclusive, as a failed gate run does |
| `scope=diff`, a flag on any kind | the question runs only on a scoped rung, where the bundle holds `diff.patch`; on `--all` its counts row carries `skipped` in the hits column, and the hunter's receipt for it reads `R<N> Q<n>: skipped on --all` |

The grammar settled: the detection script invokes the gap linter and owns the tables.
The gap linter stays a plain linter that prints rows and knows nothing about bundles,
so the hook, the doctor and a CI job call the same binary with the same output.
`ldd-detect.sh --plan` prints script kinds like the others, and the generator's
`lint-core` accepts the kind, requires the named script to exist under
`core/scripts/`, and accepts `scope=diff` on every kind.

Two questions change with the contract. R5 gains a sixth falsifying question, in the
core default and every binding: is any file over the file-length limit, with
`Detect-script: ldd-lint file-length` and Violation text that routes to R5's
file-per-type move; the handbook's self-review list gains that headline. R7 Q7 is
marked `scope=diff`, so a whole-repository review never asks a hunter to run a
mutation tool over every leaf; the tool run belongs to the analyze command's gates,
where the mechanics bullet already names the tool.

### The implementer digest

A second generated document per binding, from a second template beside
`core/handbook/coding-rules.md`, at the path the profile's `digest:` key names
*(planned)*, `coding-rules/<binding>-digest.md`. It is what a `CLAUDE.md` imports
for sessions that write code; the handbook stays the document for humans and for
teams without the plugin. Experiments 7 and 8 keep running on the handbook as
generated, never on the digest.

What it carries, using only the extraction functions the handbook template already
has: the nine mindset Asks; per rule, the heading and the move names, with the
falsifying-question headlines only for the judgment-heavy rules R1, R2, R6, R9, R10
and R12; the house rules' review lines; the mechanics table. No principle paragraphs,
no examples. One sentence at the top says what is missing on purpose: the rules a
linter holds appear only as move names, because the gate holds them.

Two gates in the generator: the residue gate the handbook already passes, and a size
gate that fails the render above 1,500 words, about 2k tokens, so the digest cannot
grow back into a handbook. The marker comment and the refuse-to-overwrite rule are
the handbook's.

### The setup command

`/<prefix>-setup` *(planned)* is a thin command over `ldd-lint.sh doctor`. It
discovers the repository's Taskfile or Makefile, CI workflow, hooks and linter version;
reads the doctor's table and reports every threshold the repository already sets
without touching it; measures blast radius by running the repository's linter once
with the recommended config beside the repository's own (`golangci-lint run -c`,
`eslint -c`, `ruff check --config`) and counting findings per rule; and proposes the
patch in its message: the config to add, the Taskfile tasks, the hook. It writes only
under `--write`, and then only the files it proposed. It is run once after install;
the status command gains one line, from the doctor's brief mode, when the recommended
setup is not detected.

### Three precision fixes

**Absence claims need a listing.** One sentence in the hunter's evidence protocol: a
finding that something is missing, a test file, a doc, a cleanup, a case, carries the
listing command that would have found it and that command's output in place of the
excerpt; an absence claimed without a listing is not a finding. Source: an R7 hunter
reported a test file missing that exists.

**Whole-repository coverage.** Now: the `PARTIAL coverage` header names what was
skipped with its size, `not reached: pages/ (41 files)`, the count read from
`dirs.txt`; and every README says that on a large repository the review is run by
scope, a directory at a time, because a whole-repository review covers what fits each
hunter's first turn and names the rest. Later, as a token-budget stage gated on the
whole-repository recall band: the parent shards a family hunter per directory chunk
from `dirs.txt` when the scope exceeds the first-turn ceiling. Source: a types hunter
stopped at 167 files, before the directory where every old-only find lived.

**The comment critic rewrote a protected WHY comment.** The rule does not change from
one sample. The comment, anonymised, is planted as a control in the fixture with
`control: true` under R9, so the precision grader fails when the critic touches it;
the critic changes only if it fails reproducibly, two of three runs.

## The pull requests

Each is one pull request from `main`, in the order below unless a dependency says
otherwise. Every one runs the repository's checks: `task generate` for all four
bindings, `task check`, `task lint-core`, `task test-gate`, `task test-gen`,
`task docs:check`. The eval gate named per pull request is from
[eval-baseline.md](eval-baseline.md) and the "Proving it" section of
[token-budget.md](token-budget.md): gate 1, no grader moves beyond one flip; gate 2,
billed tokens, the worst new run under the best old run. A change that does not alter
what the review reads needs no eval run. Paid runs happen from the evals repository,
in the owner's cloud session, with the plugin pinned to the pull request's head; the
pull request carries both tables. No feature pull request bumps a plugin version; a
release pull request follows PR 3 and PR 7.

### PR 1 — absence claims carry a listing

- **Scope**: the one sentence above, in the evidence protocol of the hunter.
- **Files**: `core/agents/rule-hunter.md`; the four rendered agents.
- **Gate**: the case whose hunter claimed a missing test file, re-run at its baseline
  run count; its grader is in the evals repository and must pass; no other case is
  expected to move.
- **Depends on**: nothing.

### PR 2a — the gap linter, the scalars and the hook

- **Scope**: `file-length` and `package-size`, the three profile scalars, the
  deduplicated thresholds, the registered language-neutral hook replacing the Go one.
- **Files**: `core/scripts/ldd-lint.sh` and `core/scripts/ldd-lint_test.sh` *(planned)*,
  a fixture matrix in the shape of `ldd-detect_test.sh`: a file at the limit, one line
  over, one over only by comments, a directory at 7, 8 and 13 files, a config that
  covers the rule, a config that cannot be read, an override file, the `--changed` and
  `--tsv` paths, two runs with identical output; `core/hooks/hooks.json`;
  `lang/*/scripts/ldd-lang.sh` (the package-size exclusion pattern joins the language
  block's contract); `lang/*/profile.yaml`, the generator's profile struct and the
  scalar list in `core/README.md`; the routing includes and READMEs that carried the
  literals; `Taskfile.yaml` (`test-gate` runs the new matrix); `lang/go/passthrough/hooks/`
  deleted.
- **Gate**: script-only, no eval run. The matrix passes for all four bindings; the
  grep for the old literals comes back clean or explained.
- **Depends on**: nothing.

### PR 2b — the recommended setup and the doctor

- **Scope**: the yaml source per binding, the generated configs and expectation
  tables, the Taskfile fragment, `doctor`, the lint-core routing check, the README
  sentence.
- **Files**: `lang/{go,python,ts-react}/setup/lint-rules.yaml` *(planned)*; the
  generator's setup package with its three dialect functions and tests, and the
  `setup:` profile key; `core/scripts/ldd-lint.sh` (the `doctor` subcommand and its
  matrix rows); `core/setup/Taskfile.ldd.yaml` *(planned)*; the four READMEs;
  `docs/generator.md` and `docs/handbook.md` lines that list what a binding writes.
- **Gate**: script and generator only, no eval run. Running `doctor` over this
  repository's own `tools/ldd-gen` reports `file-length-limit` and
  `max-public-structs` as gaps, which is the first use of the output.
- **Depends on**: PR 2a.

### PR 3 — the Detect-script kind, R5's file-length question, R7 Q7 scoped

- **Scope**: the contract bump and the two question changes, in one pull request,
  because the kind without a question is untestable and the question without the
  kind has no lead.
- **Files**: `core/scripts/ldd-detect.sh` and `ldd-detect_test.sh` (a `Detect-script`
  question that fires, one whose script exits 2, a `scope=diff` question on `--all`
  and on a scoped rung, `--plan` output); the generator's detect lint and its tests;
  `core/includes/rules/R5/falsifying-questions.md` and the three bindings' copies;
  `core/includes/rules/R7/falsifying-questions.md` and the bindings' copies;
  `core/agents/rule-hunter.md` and `core/skills/pre-commit-review/SKILL.md` for the
  `skipped on --all` receipt and its reconciliation; the token-budget page's detect
  table and S6 paragraph.
- **Gate**: review tier. The fixture gains one plant, a file over the limit, and one
  control, a long file of tests, with manifest entries, in the evals repository; the
  whole-repository review three times and the scoped cases at baseline counts; gate 1
  with the new plant expected to flip to found and R7 Q7's receipt to `skipped`,
  nothing else moving; gate 2 on the whole-repository review, whose hunters no longer
  judge R7 Q7 leads.
- **Depends on**: PR 2a.

### PR 4 — whole-repository coverage, the now half

- **Scope**: the sized `not reached:` line and the README sentence. The sharding
  stage is written into the token-budget page as a later stage with its gate, not
  built.
- **Files**: `core/agents/rule-hunter.md` (the `not reached:` line carries each
  directory's file count from `dirs.txt`); `core/skills/pre-commit-review/SKILL.md`
  (the header renders it); the four READMEs; `docs/token-budget.md`.
- **Gate**: the whole-repository review twice; the header grader passes; the recall
  count stays in band. Small enough to ride with PR 3's run if both are ready.
- **Depends on**: nothing.

### PR 5 — the WHY-comment control

- **Scope**: evals repository only, unless the critic fails reproducibly.
- **Files**: the fixture's control comment and its manifest entry; the review case
  that reads it, three runs. The comment text is the one from the review that
  misjudged it, which the owner supplies anonymised.
- **Gate**: two of three runs leave the comment alone, and nothing changes here. Two
  of three rewrite it, and a follow-up pull request changes the critic's bias
  paragraph in `core/agents/comment-critic.md`, gated on the critic's graders across
  the review tier.
- **Depends on**: nothing.

### PR 6 — the implementer digest

- **Scope**: the second template, the `digest:` profile key, the size gate, the
  README and handbook-page lines that say which document to import where.
- **Files**: `core/handbook/digest.md` *(planned)*; the generator's handbook renderer
  generalised to a list of documents, with the size gate and tests; the four
  profiles; `coding-rules/*-digest.md` as generated; `docs/handbook.md`; the READMEs.
- **Gate**: generator only, no eval run; the rendered digests under 1,500 words
  each, residue clean. Experiment 7 keeps the handbook arm as it is.
- **Depends on**: nothing; it reads the same sources PR 2a does not change.

### PR 7 — the setup command

- **Scope**: the command and the status nudge.
- **Files**: `core/commands/{{.CmdPrefix}}-setup.md` *(planned)*; the status command;
  the READMEs' command tables; `core/scripts/ldd-lint.sh` for `doctor --brief` and
  the blast-radius run.
- **Gate**: no grader covers commands; the gate is the doctor's output shape holding
  through one release after PR 2b, exercised on the owner's own repositories.
- **Depends on**: PR 2b.

### PR 8 — experiment 7's missing row

- **Scope**: documentation. A sixth referee row, no rules in the implementer's
  context with the rule-check referee loop, so the rule-check row has its control:
  the same loop with and without the handbook. Gate 1 becomes four Sonnet cells,
  plain, slim plugin, handbook plus rule-check loop, no-rules plus rule-check loop,
  about $125. The readings are pre-registered in the page before any cell runs: the
  no-rules loop matching the handbook loop on the scorecard means the claim holds for
  the rules the checks can see; a gap on R1, R2, R6, R9, R10 and R12 is the handbook's
  value, and the digest's reason to exist.
- **Files**: `docs/eval-return-experiments.md`, the arm table, the referee table, the
  gate table and the cost line.
- **Gate**: documentation check only. Running the cells is the evals repository's
  work, in the owner's cloud session, after PR 3 so the rule checks the referee runs
  include the file-length question.
- **Depends on**: nothing to write; PR 3 to run.

## Order and tracks

Four tracks run in parallel; inside a track the order is fixed.

| Track | Pull requests | Why together |
|---|---|---|
| precision | 1, 4, 5 | one-sentence fixes to the hunter and the header, each with its own eval case, cheapest first |
| authority | 2a, 2b, 3, 7 | each needs the one before it: scalars and script, then the setup that reads the script, then the detect kind that calls the script, then the command over the doctor |
| digest | 6 | generator only, touches nothing the others touch |
| experiments | 8 | a page edit; its runs wait for PR 3 |

The evals repository is touched by PR 1 (a re-run), PR 3 (a plant, a control, a
review-tier run), PR 5 (a control and three runs) and PR 8 (the cells). PR 2a, 2b, 6
and 7 never touch it.

## Not in this round

- **The refactor tier** is not rebuilt: S10 did not ship, and gate 1 decides whether
  the implementer side matters before more is spent there.
- **A hand-condensed handbook** for the experiments: the arm is the handbook as
  generated, and the digest is for implementers, never for a cell.
- **Fewer than four hunter families**: six were rejected on cost and four is the
  floor the whole-repository recall band was recorded at.
- **`public-types`**: Go's authority is confirmed (`max-public-structs`, enabled in
  the recommended config), React's is `react/no-multi-comp`, Python has none, and the
  plugin's prose carries no number for it yet. The subcommand ships when a falsifying
  question wants it, with its own scalar, after PR 3 proves the kind.
- **Sharded hunters**: written as a later stage in PR 4, built when a whole-repository
  recall run shows the first-turn ceiling is what the recall band is paying for.
