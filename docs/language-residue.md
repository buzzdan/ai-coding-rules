---
type: architecture
description: how Go idioms left in core prose are rendered per language binding — the five outcomes (rewrite, scalar, include, aside, override), the seam rules, the generic binding's instruction-with-examples shape, the Python binding's seven positions, and the Claude Code names a second plugin must not collide on
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

These decide which outcome a hit gets, and they are what keeps the bindings from
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
  Constructor", "Separate Failure from Absence", "Make Concurrent Work Joinable" — and
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
| `src_ext` | `{{.SrcExt}}` | `*.go` minus the star | `.<ext>` | `*.py` minus the star | the source-file suffix in worked-example paths and R5's role-named files. The generic value is a placeholder rather than a phrase because every use site glues it to a file name: `user/service.<ext>:14` reads, `user/servicethe language's source suffix:14` does not |
| `unexported` | `{{.Unexported}}` | unexported | internal | underscore-prefixed | the visibility of a symbol outside the public surface, in R4's ladder, R9's visibility default and R2's field discipline. Every value starts with a vowel so "an {{.Unexported}} symbol" reads. "Unexported" is Go's word, so the generic binding says "internal", the one most languages share; the generic handbook's residue gate is what caught it |

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
  scalars are short phrases chosen to read in every core sentence that substitutes
  them — `detected-language source` where a glob goes, `lint-suppression` before the
  word "directive", `the repository's test command` inside backticks, `.<ext>` and
  `<test-file suffix>` glued to file names, `<comment-marker>` before a `See` edge,
  `any-language` as the adjective in "any-language code work" — and the generic
  default includes tell the model to adjust to what it sees: "Keep the doc comment on an
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
only where their mechanism differs. The generic binding's own files are the ones
that are about detection: the pre-flight and command-discovery steps, the
`/wire-repo-brain` language-scope paragraph, the gate adapter that dispatches on the
marker, and the fixture rows its gate matrix runs — one row per language the adapter
detects, so the same cases prove the Go block and the Python block alike.

The canonical examples in `core/includes/` are language-neutral pseudocode rather
than the paired Go and Python snippets the roadmap allowed: a Go signature such as
"the value or an error" is a hard residue token, so a Go snippet cannot live under
`core/`, and a Python snippet would be a third language's idiom passed off as
universal. The pseudocode shows the shape; each example ends by saying which spelling
follows the repository's language. The handbook examples under
`core/includes/handbook/` take the same shape, shorter: one fence in the same dialect
(`fail`, `absent`, `spawn`, `hidden`) and a `> **Spelling:**` aside in place of the
Go and Python bindings' `> **In <Lang>:**` position, so `coding-rules/generic.md` is
rendered from core defaults plus the binding's two house rules and its mechanics rows
([handbook.md](handbook.md)).

## The Python binding

`python-linter-driven-development` is rendered from the same core with Python
knowledge: a file under `lang/python/` wherever knowing Python beats detecting it,
the core default everywhere else. Its scalars are values, not phrases. Three of them
were choices rather than translations:

- `test_glob` is `_test.py`, because core glues the scalar as a suffix
  (`rotator{{.TestGlob}}`); pytest collects both `test_*.py` and `*_test.py`, and the
  binding's own detection commands search both spellings.
- `task` is `concurrent task`, not `thread`, so a leaked thread and a dropped asyncio
  task are both in R10's scope; the binding's includes name each where the mechanics
  differ.
- `unexported` is `underscore-prefixed`, the leading-underscore convention. Every
  value of that scalar must start with a vowel because core writes "an
  {{.Unexported}} symbol"; `private` reads better in isolation and breaks six
  sentences. The convention is a convention, not a wall — a test can import a
  `_private` name — which is why R4 and R7 hunt for exactly that.

Where a rule's Go text meets a Python idiom, the binding takes a position and the
includes implement it; the handbook under `lang/python/handbook/` states each
position to the reader as an `In Python` aside under its rule
([handbook.md](handbook.md)). The seven positions:

1. **Absence.** `None` is a declared absence, never an undeclared failure. A
   `-> X | None` signature is fine when absence is normal and every caller narrows
   it, checked by mypy — `dict.get` beside `dict[k]` is the model. The findings are
   `None` returned where the signature promises `X` (R1 Q4, with
   `# type: ignore[return-value]` as the silenced form), `None` standing in for a
   failure (R2 Q5, Separate Failure from Absence — raise), and callers stacking
   `is None` guards because the absence should have been an exception. Never a
   `tuple[X, bool]`.
2. **Optional collaborators.** The default is a stateless do-nothing object bound
   once as a module-level constant — `NULL_SINK = NullSink()`, a name rather than a
   call because ruff `B008` flags a call in a default — with the parameter
   keyword-only and typed as the sink protocol, never as optional; `None` is rejected with a type error. A
   `param: X | None = None` with substitution in `__init__` is allowed only for a
   genuinely mutable or expensive default, and even then the attribute is typed
   without `None` and no method guards it. The py-mini fixture's
   `CASE-E.nil-parameters` plant is this position's anchor.
3. **Self-validating types.** `@dataclass(frozen=True)` with `__post_init__`, or a
   `parse` classmethod that normalises then constructs. Public read-only fields are
   fine: literal construction is not a hole because `__post_init__` runs on every
   literal. The finding is a mutable dataclass carrying invariants with no
   `__post_init__`. Pydantic is the boundary form where the repository already uses
   it; `model_construct` and `model_copy(update=)` are the bypasses the R2 hunter
   looks for; the plugin never proposes adding pydantic. typing's NewType scores zero on
   the invariant line.
4. **Docstrings.** The PEP 257 summary line is exempt from the critic's restatement
   verdict when it states the contract; the WHY budget applies to the body; the argument,
   return and raises sections do not count against it. DELETE becomes REWRITE
   wherever the repository's ruff `D` rules require a docstring; a `_private` name
   carries no `D` obligation, so a WHAT-docstring on one is still deleted.
5. **Dispatch.** The kept single switch is a `match` over an enum closed by
   `case _: assert_never(x)`; that arm is the completeness proof, not an
   unknown-kind default, and a `case _:` that raises or logs is R11 Q3's finding.
   The dictionary of callables is presented first, a protocol hierarchy second,
   `functools.singledispatch` third; a `.get(kind, fallback)` deep in logic is
   "unknown kind away from the boundary". A positional boolean parameter is always
   the finding and the lint-fixer makes it keyword-only (ruff `FBT001`/`FBT003`); a
   keyword-only boolean is fine while the branches share their body, and Split Flag
   Argument when they share little.
6. **Concurrency.** `asyncio.sleep` is cancellable by construction and exempt from
   R10 Q5; `time.sleep` on a thread with a stop condition is the finding, fixed
   with `Event.wait(timeout)`. The object that starts a thread exposes `close()`
   that sets the event and joins; a daemon thread is acceptable only in entry-point
   wiring for work that owns no resource (the `queue` module's own example uses
   one, which is where the nuance comes from). asyncio tasks live in an
   `asyncio.TaskGroup` or under a kept handle; a dropped `create_task` handle is a
   leak. No atomics, no concurrent dict, no race detector: a lock beside the
   fields it guards, taken with `with`, or confinement to one thread;
   `queue.Queue.shutdown()` on 3.13+ is the closed-channel twin.
7. **Module state.** Silent everywhere: `logging.getLogger(__name__)`, constants,
   enums, frozen instances as constants, exception classes, typing machinery. Silent
   only in the entry point: `Config.from_environ()`, `logging.basicConfig`, the
   framework `app`, a registry filled by hand, `asyncio.run`. Reported elsewhere:
   `from env import CONFIG` or `os.environ` reads, a module-level container
   functions write into, side effects in a module body, a lazily built instance
   behind a getter, `asyncio.run` or `get_event_loop` in library code. R8 Q3's
   "manufactured cancellation root" is those last two plus `basicConfig` in a
   library module. A test that monkeypatches production configuration is evidence
   against the production code.

The binding also holds stances that are not Python community norms and says so
under an "Opinionated" heading in its README: no `utils.py` or `common.py`, no
testing of `_private` functions, no `mock.patch` of internal collaborators
(patching the true external boundary is fine), no mutable module state; small
pytest fixtures that build a literal are fine, a fixture that hides the input is
R7 Q3.

Two files every binding must supply because core has no default for them — the
orchestrator's pre-flight and the analyze command's command discovery — name the
Python tool chain: `pyproject.toml` as the marker, `pytest`, `ruff check` and
`ruff format`, and `mypy` only where a `[tool.mypy]` table exists. The refactoring
routing table and the lint-fixer's compact copy are keyed by ruff codes; duplicated
code, file length, exhaustiveness and single-implementer protocols have no ruff rule
and are review-only rows, as the fixture's manifest records. The gate's adapter is
the Python block of the generic adapter between Go-style marker comments, and the
fixture include runs one row, `python`, with no detection cases.

## The case studies

The six files under `examples/` are case law: the rules cite them, and the review
skill names two of them, by path, in agent spawn prompts. Their prose is a story about specific
code, so most sentences name identifiers from the fence beside them. The seam is
therefore the section, not the fence: `core/examples/<case>.md` keeps the title,
the headings and the doctrine — the why-it-is-a-defect bullets, the verdicts, the
scorecards, the decision questions, the skeptic's operating rule, the dividing-line
paragraphs — and each code section (the fence plus the paragraphs that narrate its
identifiers) is one include under `examples/<case>/`. About a third of each file is
core; the rest is the binding's.

The Go sections are the original text, cut at section boundaries. The Python
sections are written in Python and may argue differently where Python differs: mypy
and `assert_never` where Go had the compiler and `exhaustive`, a recorded tuple of
implementers where Go sealed an interface with an unexported method, a frozen
dataclass where Go had private fields behind accessors, `_private` docstrings where
Go had comments on unexported symbols. Core headings such as "private fields +
accessors" stay, and the Python section says in one sentence which Python mechanism
answers to the name.

The generic binding reads the Go sections through `include_fallback` and adds the
demonstration note above the "Demonstrates" line through `examples/language-note.md`.
These sections have no neutral default: pseudocode case law would be a third
language's idiom passed off as universal, and a binding either writes its sections
or names a fallback.

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
- **A non-Go handbook is a residue gate.** The coding-rules handbook
  ([handbook.md](handbook.md)) renders each Principle and maxim without the
  same-language example that softens it in the plugin, so rendering the Python
  handbook fails on any hard or soft token in the result, except the asides above
  (`interface`, `struct`). This is how the R1, R8, R12 and maxim Rewrites were
  found, and the gate keeps the next one from shipping.
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
