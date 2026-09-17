---
type: architecture
description: how Go idioms left in core prose are rendered per language binding — the five outcomes (rewrite, scalar, include, aside, override), the seam rules, the generic binding's instruction-with-examples shape, and the Claude Code names a second plugin must not collide on
---
# Language Residue Decisions

`core/` is rendered once per language binding. Most of its text is language-neutral,
but the Go plugin was written first, so some sentences still reason from Go: `nil`
as the missing value, goroutines, `ctx`, godoc, table tests with `wantErr`. The
generator's `task lint-core` scans `core/` for these words and writes the count per
token and per file into the Residue section of [core/README.md](../core/README.md).
That section says *where* the residue is. This document says *what happens to a
hit*: which mechanism renders it for a second language, and the rules that decide
between mechanisms. The line-by-line work list that applies these rules lives
outside the repository, in the stream's planning notes, because it is stale the day
the text moves.

## The five outcomes

Every hit gets exactly one of these.

| Outcome | When | Mechanism |
|---|---|---|
| **Rewrite** | A Go *spelling* of a universal idea sits inside a core sentence: `pkg_test` for "imported as a consumer would", `context.Background()` for "a library that manufactures its own root cancellation", `(X, error)` for "the value or an error" | The core sentence is reworded so it is true in every language; the Go spelling moves into the rule's canonical example, which the binding owns. This changes the Go plugin's text, so it ships as a content change with a version bump, never inside a byte-identical refactor |
| **Scalar** | One word or spelling that recurs in five or more lines, and substituting it keeps every sentence true in every binding | A `profile.yaml` key rendered as `{{.Name}}`. Its Go literal then becomes hard residue, so a missed site fails `task lint-core` |
| **Include** | A whole block — bullet, paragraph, code fence, table row — whose *content* is one language's mechanism, not just its spelling: R10's guard and exit-path mechanics, R7's table-test mechanics, a worked example in Go | `{{include "path"}}`. The generator reads `lang/<lang>/path`; when the binding has no such file it reads `core/includes/path`, the language-neutral default. A binding adds a file only where its language truly differs |
| **Aside** | A Go word used as the common noun for a concept every language has, where the sentence stays true as written: "interface", "struct" as a shape, the attributed Go proverbs in `maxims.md` | Nothing changes; the decision is recorded once so the token is not re-triaged |
| **Override** | A whole core file whose text differs per language | `lang/<lang>/overrides/<core path>`. Never used for a rule, skill, agent or command; kept for files such as a plugin README that differ entirely |

## Seam rules

These decide which outcome a hit gets, and they are what keeps three bindings from
drifting apart.

- **Includes sit at block boundaries, never inside a sentence.** A clause-level
  include splits a core sentence across two files: the core author can no longer read
  their own sentence, and a per-language clause stops fitting the grammar around it
  without any check noticing. A lone Go clause is a Rewrite; three or more contiguous
  language-shaped bullets in one section are one include for that section
  (`rules/R10/design-guidance.md`), with the neutral bullets kept in core before or
  after it.
- **Doctrine is core; mechanism is binding.** Principle, Why, the reasoning in Design
  guidance and the *names and one-line meaning* of every Fix-pattern move stay in
  core. What a binding adds is how the mechanism is spelled in its language. When
  a section is mostly mechanism, core keeps the neutral bullets and ends the section
  with one include for the language's mechanics, whose core default is empty or a
  short neutral note.
- **Move names are catalogue names.** A refactoring move is shared vocabulary: the
  refactoring skill's pattern index, the code-designing dispatch table, the
  pre-commit-review hunter table, the skeptic's scope note and the evals' violation
  manifest all cite moves by name. A name that changes per language is not in the
  catalogue. So every move name is language-neutral core text — "Split Success and
  Error Tables", "Pass Cancellation Down", "Replace Import-Time Initialization with a
  Constructor", "Separate Failure from Absence", "Make the {{.Task}} Joinable" — and
  the Go spelling (`wantErr`, `ctx`, `init()`) lives in the move's body or the
  canonical example.
- **The generic binding is not a third rendering of the same text.** It detects the
  language at run time, so its per-language scalars are general phrases and its
  includes are instructions with cross-language examples. See "The generic binding"
  below.
- **No rule is an override.** An override would be written by every binding — Go,
  generic and Python alike — and a core rule that no binding renders is dead text: an
  edit to its Principle would reach nobody. R2 (`nil`), R10 (goroutines) and R6
  (interfaces versus mocks) looked like override candidates and are rendered with
  scalars, rewrites and block includes instead.

## Scalars

| Key | `{{.Name}}` | Go | Generic | Python | Carries |
|---|---|---|---|---|---|
| `nil` | `{{.Nil}}` | nil | null | None | the missing value as a noun: "{{.Nil}}-checks", "{{.Nil}} holes", "{{.Nil}} handling" |
| `task` | `{{.Task}}` | goroutine | concurrent task | concurrent task | a unit of concurrent work: R10's Principle and Why, "R10 {{.Task}} leaks", "no {{.Task}}s" at rung 0. Python says "concurrent task" too, so a leaked thread is in scope, not only an asyncio task |
| `doc_form` | `{{.DocForm}}` | godoc | doc comment | docstring | the documentation form as a noun or adjective: "its {{.DocForm}}", "kind ({{.DocForm}}/in-body/test)" |
| `doc_comment` | `{{.DocComment}}` | godoc comment | doc comment | docstring | the two-word noun in R9 and the comment critic; one scalar would render "docstring comments" |
| `src_ext` | `{{.SrcExt}}` | `*.go` minus the star | the language's source suffix | `*.py` minus the star | the source-file suffix in worked-example paths and R5's role-named files |
| `unexported` | `{{.Unexported}}` | unexported | unexported | underscore-prefixed | the visibility of a symbol outside the public surface, in R4's ladder, R9's visibility default and R2's field discipline. Every value starts with a vowel so "an {{.Unexported}} symbol" reads |

Plural forms append `s` to the scalar; every value above pluralizes that way. A
scalar never carries a sentence: when substitution would need a different article,
verb or clause per language, the site is a Rewrite or an include.

Two sentences the scalars do not fix on their own, and the Rewrite that does: "nil as
a value" in the hunter table renders "None as a value", which in Python is a
legitimate `X | None`; the neutral wording is "the missing value returned where a
real value is expected". "Replace nil returns" as a move name says stop while its
Python body says `X | None` is the answer for absence; the catalogue name is "Separate
Failure from Absence".

## The generic binding

`linter-driven-development` is rendered from the same core for repositories without
a language binding. It detects the language at run time from marker files, so
`src_glob`, `test_glob`, `project_marker`, `nolint`, `comment_prefix`, `src_ext`,
`default_test`, `default_lint` and `default_lint_fix` have no fixed value. The
binding answers this differently for text the model reads and for the script it
installs:

- **Model-facing text is an instruction with examples, not a lookup.** The generic
  scalars are short general phrases — "the language's source files", "the language's
  suppression directive", "the repository's test command" — and the generic default
  includes tell the model to adjust to what it sees: "Keep the doc comment on an
  important function or type short and point to the repo-brain doc for the rest.
  Use the language's documentation form — `//` line comments in Go, Rust or
  TypeScript, `#` in shell or Ruby, a docstring in Python." The same shape covers
  source globs (grep the files of the detected language), suppression directives
  (`//nolint`, `# noqa`, `eslint-disable`) and the test and lint commands (run the
  ones the repository already defines in its Taskfile, Makefile, package scripts or
  CI; none found is a finding, not a guess). The model reads the repository and
  substitutes; a placeholder scheme adds nothing it does not already do.
- **The gate script cannot adjust.** `check-repo-brain.sh` is bash: resolving a
  backticked symbol against real declarations and banning file-path citations need a
  parser per language. The generic binding's adapter block is a dispatch on the
  detected marker — `go.mod` selects the Go block, `pyproject.toml` the Python block —
  and an unknown marker keeps the structure checks (frontmatter, index, reachability,
  drift) while reporting code edges as unverified. This is the one place in the
  generic plugin where a lookup table is real, and it is code, not prose.

Its includes are the core defaults wherever core has one. That is what keeps the
generic binding a profile plus a handful of files rather than a second copy of core:
neutral text is written once, under `core/includes/`, and Go and Python add a file
only where their mechanism differs.

## Claude Code names a second plugin must not collide on

Two plugins from this core can be installed side by side — Go and generic in a
monorepo, or Go and Python. Everything a skill reaches by name is therefore a
coupling point, whether or not it looks like language:

- **Agents** are registered as `<plugin>:<agent>`. Core spawns them as
  `{{.Plugin}}:rule-hunter`, `{{.Plugin}}:lint-fixer`, `{{.Plugin}}:comment-critic`
  and `{{.Plugin}}:overabstraction-skeptic`, the same way `Skill({{.Plugin}}:…)`
  already names skills. A bare agent name with two plugins installed is a guess, and
  the wrong lint-fixer brings the wrong routing table.
- **Skill descriptions drive auto-triggering.** "META ORCHESTRATOR for any {{.Lang}}
  code change" collides when the generic plugin's description also matches a Go
  repository. The language clause of the orchestrator, code-designing and testing
  descriptions is an include; the generic one says it applies when no
  language-specific plugin is installed for the detected language.
- **Commands** carry `{{.CmdPrefix}}` in their file names. `wire-repo-brain` keeps
  no prefix: the documentation network it wires is a property of the repository, not
  of a language, and the only language-shaped part — the gate's declaration parser —
  lives in the adapter block the binding supplies. Two plugins installed side by side
  offer the same command doing the same structural work.
- **Report literals are core and never move.** The words evals parse — `FIXED:`,
  `ESCALATED:`, `LINT STATUS:`, the `Stop check` lines, `R<N>: <M> finding(s)`, the
  category headers, `🔗 CLUSTER:` — are the report contract; no binding include
  rewrites them.
- **Hooks and the repo-brain adapter are binding files**, not core.
  `hooks/check-package-sizes.sh` counts Go files; the gate's adapter block hardcodes
  the same globs and marker the profile holds. A binding that ships either writes its
  own; the generic binding's adapter dispatches on the detected language.

## How the scanner enforces this

`task lint-core` is what keeps these decisions from being remembered instead of
enforced:

- **Soft tokens cover every idiom the outcomes name**: the words with scalars,
  error-tuple signatures such as `(X, error)` and `(X, bool)`, `t.Run`, `Example_*`,
  capitalized standard-library calls (`errors.New`, `io.Discard`, `time.Now`),
  `panic`, `zero value`, `unexported` and "race detector". A linter name counts only
  inside backticks, so the English word "exhaustive" is not a hit; `context.` needs a
  capital letter after the dot, so a sentence ending in "context." is not one either.
- **A scalar's literal becomes a hard token once no core line spells it.** Until
  then it stays soft, and the promotion lands in the same change that removes the
  last literal, so `task lint-core` is green on every commit.
- **Rendered-tree checks guard the seams the scanner cannot see.** After rendering,
  the generator verifies that every move name a table cites appears verbatim as a
  Fix-pattern bullet of the rule the row points at, and that every relative link in a
  rendered file resolves inside the plugin tree — so a binding without `examples/`
  cannot ship a rule that points there. These two checks are what make block-level
  includes and shared move names safe to edit.

## Decisions taken

1. **Rewrite exists as an outcome, and it changes Go text.** The neutral rewording of
   about thirty clauses, the catalogue move names, the namespaced agent spawns and
   R6's smell-first opening sentence ship together as one content change with a
   version bump, measured like any other behavior change, before the includes are
   cut. The byte-identical sweep that follows is then a third of the size it would
   have been.
2. **Six scalars**, all recurring words: `nil`, `task`, `doc_form`, `doc_comment`,
   `src_ext`, `unexported`. Anything used fewer than five times, or needing grammar
   variants, is a Rewrite or an include.
3. **Move names are language-neutral core text**; no table row is an include.
4. **Includes are blocks with a core default**; the generic binding fills nothing
   that core already says.
5. **No rule is an override.**
6. **`interface` stays the general term**, including in R6, whose Principle opens
   with the smell — a seam that exists only so a test can substitute a double — so a
   Python hunter recognizes `mock.patch` on a concrete class as the same defect.
7. **`maxims.md` is an aside as a whole**: the proverbs are attributed quotations and
   their "Ask" illustrations are the author's, quoted the way a design book quotes Go
   proverbs.

Open, for the plugin owner: what the generic plugin's README promises about its
linter phase.
