---
type: architecture
description: how each Go idiom left in core prose is rendered per language binding — the scalar, include and aside decision for every soft residue token, and why no rule is a whole-file override
---
# Language Residue Decisions

`core/` is rendered once per language binding. Most of its text is language-neutral,
but the Go plugin was written first, so some sentences still reason from Go: `nil`
as the missing value, goroutines, `ctx`, godoc, table tests with `wantErr`. The
generator's `task lint-core` scans `core/` for these words and writes the count per
token and per file into the Residue section of [core/README.md](../core/README.md).
That section says *where* the residue is. This document says *what happens to each
hit*: which mechanism renders it for a second language, and why.

## The four outcomes

Every hit gets exactly one of these. The Go plugin must render byte-identical after
each decision is applied, which is what `task check` proves.

| Outcome | When | Mechanism |
|---|---|---|
| **Scalar** | One word or spelling that recurs in five or more lines, and substituting it keeps every sentence true in every binding | A new `profile.yaml` key, rendered as `{{.Name}}`. Its Go literal then becomes hard residue, so a missed site fails `task lint-core` |
| **Include** | A sentence, bullet, list or code fence that reasons from one language's idiom (error tuples, options, `io.Discard`, Go's package-doc file, external test packages) | `{{include "path"}}` under `lang/<lang>/`. The Go include is the old text verbatim. An include may sit inline mid-sentence; the generator trims exactly one trailing newline |
| **Aside** | A Go word used as the common noun for a concept every language has, where the sentence stays true as written | Nothing changes. The decision is recorded below so the token is not re-triaged |
| **Override** | A whole core file whose text differs per language | `lang/<lang>/overrides/<core path>`. **Not used for any rule** — see the next section |

## Why no rule is an override

Three rules looked like override candidates: R2 (`nil`), R10 (goroutines) and R6
(interfaces versus mocks). All three stay in core with includes, because an override
would be written by every binding — Go, generic and Python alike — and a core file
that no binding renders is dead text: an edit to its Principle would reach nobody.
Includes keep the shared parts shared:

- **Principle and Why stay one text.** Where a Principle names a Go word (R10's
  goroutine, R2's nil), a scalar carries the language's word; where a clause is a Go
  idiom (R8's `context.Background()` prohibition), an inline include carries the
  clause.
- **Fix-pattern move names are vocabulary.** The refactoring skill's pattern index,
  the code-designing dispatch table and the pre-commit-review hunter table all name a
  rule's moves. For R7, R8 and R10 the move names are Go-shaped ("Split `wantErr`
  tables", "Thread `ctx`", "Make the Goroutine Joinable"), so the rule's Fix pattern
  body and the three rows that cite it are includes owned by the same binding. For
  every other rule the names are neutral and stay in core.
- **R6's word is "interface".** The rule's failure mode — a hand-written double
  standing in for the real collaborator — exists in every language. Python's
  version adds `unittest.mock.patch` and MagicMock stand-ins that need no
  interface at all; that story belongs in R6's canonical example and falsifying
  questions, which the binding already owns. The prose keeps "interface" as the
  general term (Java, C#, TypeScript, Go and PHP use the keyword; Python's Protocol
  and Rust's trait are structural interfaces).

## New scalars

| Key | `{{.Name}}` | Go | Generic | Python | Replaces |
|---|---|---|---|---|---|
| `nil` | `{{.Nil}}` | nil | null | None | "nil" as a noun in prose: nil-checks, nil holes, nil handling, "nil is not a value", "Replace nil returns" (the move name) |
| `task` | `{{.Task}}` | goroutine | concurrent task | task | "goroutine" in prose: R10's Principle and Why, "R10 goroutine leaks", "no goroutines" at rung 0, "every planned goroutine gets an owner" |
| `doc_form` | `{{.DocForm}}` | godoc | doc comment | docstring | "godoc" as a noun or adjective: "its godoc", "godocs", "kind (godoc/in-body/test)", "godoc + feature docs" |
| `doc_comment` | `{{.DocComment}}` | godoc comment | doc comment | docstring | the two-word noun "godoc comment(s)" in R9 and the comment critic; a single scalar would render "docstring comments" |
| `src_ext` | `{{.SrcExt}}` | `*.go` minus the star | (per detected row) | `*.py` minus the star | file names in worked examples and role-file names in R5; the ldd trigger's "source files present" clause; the package-size zone's "non-test source files" count |

`{{.Lang}}` already exists; R9's monorepo note still says "this build carries the Go
adapter" as a literal and renders through the scalar instead.

Plural forms append `s` to the scalar (`{{.Task}}s`, `{{.DocForm}}s`); every value
above pluralizes that way. The generic binding's `src_ext` is not a fixed value: the
generic plugin detects the language at run time, so its profile carries the phrase
the detection step defines.

## Decisions by file

Anchors quote the phrase in the core text rather than a line number, because line
numbers move with every edit. Where an include is named, the Go binding's file holds
the current core text unchanged.

### rules/R2-self-validating-types.md

| Anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| Why: "nil-checks, emptiness checks" | nil | Scalar | `{{.Nil}}-checks` |
| "a struct-literal or zero-value path around the constructor" | struct | Aside | "struct literal" reads as "building the value directly, bypassing the constructor" in any language with literals or default constructors |
| Validation ownership: the Config code fence | fence, struct, func, nil | Include | `rules/R2/validation-ownership-example.md` |
| Trust composed values: the Address code fence | fence, func, nil | Include | `rules/R2/trust-composed-example.md` |
| "**Nil is not a value.**" through the end of "Absence is a value too", including the Reporter code fence and the option paragraph | nil, func, fence | Include | `rules/R2/absence-guidance.md`. The two bullets reason from Go's error positions (`nil, err`), functional options, `errors.Join` and `io.Discard`. Python's text says None, raises, keyword defaults and a sentinel object; the generic text names the language's null and a named do-nothing value |
| No defensive coding: "zero nil/emptiness checks" | nil | Scalar | `{{.Nil}}/emptiness checks` |
| Fix, Hoist method checks: "the hoisted check rejects nil" | nil | Scalar | |
| Fix, Introduce Null Object: the bullet body after the name | nil, interface | Include | `rules/R2/fix-null-object.md` — options, `errors.Join`, `io.Writer` and `io.Discard` |
| Fix, "**Replace nil returns**: `(X, error)` for failures, `(X, bool)` for absence" | nil | Scalar + Include | the name renders `Replace {{.Nil}} returns`; the body is `rules/R2/fix-nil-returns.md` (Python: raise for failure, `X | None` only for absence) |

Not flagged by the scanner but Go all the same: the constructor signatures
`ParseX(raw) (X, error)` and `NewX(deps) (X, error)` in "Constructors are the only
entry" and in "Add validating constructor", and "loses its `error` return entirely"
in "Delete re-validation". These are the error-tuple idiom; they become the include
`rules/R2/constructor-signatures.md` (inline, twice) and the scanner gains a soft
token for `(X, error)`-shaped tuples so the next language finds them.

### rules/R10-concurrency-safety.md

| Anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| Principle: "Every goroutine has an owner", "who stops the goroutine" | goroutine | Scalar | `{{.Task}}` — the Principle is neutral once the word is |
| Why: "a `for { <-ch }` goroutine has no way out" | goroutine | Include | `rules/R10/why-no-exit.md`, inline: the clause with the code |
| Why: "a leaked goroutine accumulates", "a goroutine nobody can stop", "two goroutines without a guard" | goroutine | Scalar | |
| Why: "an unsynchronized concurrent map write is a **fatal runtime crash**, not an error; a bare `time.Sleep` in a retry loop" | — | Include | `rules/R10/why-failures.md`, inline. Go-specific facts: Python's dict writes do not crash, its sleep is `time.sleep` versus `asyncio.sleep` |
| Why: "The mechanical neighbors of this rule belong to the linter … `errcheck` … `bodyclose` … `govet copylocks`" | linter names | Include | `rules/R10/why-linter-neighbors.md`; the Design guidance already has `rules/R10/linter-neighbors.md` for the same list |
| Design guidance: every bullet from "Whoever starts a goroutine" through "Production code does not sleep" | goroutine, ctx, context., sync., errgroup, golang.org | Include | `rules/R10/design-guidance.md` — one include for the section body. Each bullet is a Go mechanism: `select` on `ctx.Done()`, `atomic`, `sync.Map`, `sync.OnceFunc`, `time.After`, `context.WithoutCancel`, `golang.org/x/time/rate`. Python's says asyncio tasks kept by reference, cancellation and `gather`, `threading.Event`, locks and the GIL; the generic one states the owner, exit path, guard-with-state and no-sleep principles by concept |
| Design guidance: "`ctx` threading discipline: `R8-no-globals.md`" | ctx | Include | `rules/R10/cross-ref-cancellation.md`, inline |
| Fix pattern: all five moves | ctx, goroutine, errgroup, sync., go vet | Include | `rules/R10/fix-pattern.md`. Move names are binding-owned (see "Fix-pattern move names are vocabulary") |

### rules/R6-test-only-interfaces.md

| Anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| "interface" throughout Principle, Why, Design guidance and Fix pattern | interface | Aside | the general term for the concept; see "R6's word is interface" |
| Why: "A hand-written struct that only satisfies a production interface" | struct | Aside | struct as "object" |
| Why: "embedded DB, `httptest` server, temp dir" | httptest | Include | `rules/R6/fake-examples.md`, inline — the list of real-with-fake-data harnesses |
| Design guidance: "(real store over embedded DB, real client against `httptest`)" | httptest | Include | `rules/R6/wire-real-examples.md`, inline |
| Fix pattern: "(embedded DB, temp dir, `httptest` server)" | httptest | Include | `rules/R6/rewrite-examples.md`, inline |
| Fix pattern: "the fake struct in `*{{.TestGlob}}` / `fakes/` / `mocks/`" | struct | Aside | |

### rules/R7-test-placement.md

| Anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| Principle: "public API only, `pkg_test` package" | pkg_test | Include | `rules/R7/principle-public-api.md`, inline — the parenthetical's last item. Python has no external test package; its text says "importing only public names" |
| Why: "a conditional inside `t.Run` means one case is really two" | — | Include | `rules/R7/why-subtest.md`, inline; unflagged today, `t.Run` gains a soft token |
| Design guidance: the four bullets from "Leaf types (rung 0)" through "Complexity 1 inside every `t.Run`" | pkg_test, httptest, interface, wantErr | Include | `rules/R7/design-guidance-mechanics.md` — external test package, `httptest`, `t.Run`, `wantErr bool`, `TestX_Success`. The two neutral bullets that follow (private-test urge, ladder pointer) stay in core |
| Design guidance: "**Mechanics**: named struct fields … no `time.Sleep` … testify suites" | struct, testify, Go stdlib | Include | `rules/R7/mechanics.md` |
| Fix pattern: "**Split `wantErr` tables**" | wantErr | Include | `rules/R7/fix-split-tables.md` |
| Fix pattern: "**Replace sleep with synchronization**: channel + `select`/timeout, or `sync.WaitGroup`" | sync. | Include | `rules/R7/fix-replace-sleep.md` |

### rules/R8-no-globals.md

| Anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| Principle: "no package-level mutable state, no `init()` writing state, no singletons fetched from inside business logic, no `context.Background()` in library code — `ctx` flows from caller to callee" | init(), context., ctx | Include | `rules/R8/principle-prohibitions.md`, inline. Python's list: no module-level mutable state, no import-time side effects, no singletons reached from business logic |
| Why: "`context.Background()` deep in a call chain is the same sin in context form: it severs cancellation, timeouts, and tracing" | context. | Include | `rules/R8/why-context.md`, inline |
| Why: "couples every caller to one config struct" | struct | Aside | |
| Why: "loggers designed to be global (`slog`, `zerolog`), constants, and `var Err... = errors.New` sentinels are fine" | Go stdlib | Include | `rules/R8/acceptable-globals.md`, inline — the list of globals that are not defects; Python's names `logging.getLogger`, constants and exception classes |
| Design guidance: the three bullets "`ctx` flows down", "`init()` computes nothing observable", "Singletons are wiring, not access" | ctx, context., init(), sync. | Include | `rules/R8/design-guidance-language.md` |
| Fix pattern: "**Replace `init()` with a constructor**" and "**Thread `ctx`**" | init(), ctx, context. | Include | `rules/R8/fix-pattern-language.md` — the two Go moves; "Extract Clean Island" and "Push the Global Up One Level" stay in core |

### rules/R11-conditional-dispatch.md

| Anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| "interface" throughout | interface | Aside | |
| "exhaustive switch", "make it exhaustive", "goes exhaustive" | exhaustive (the word) | Aside | English, not the linter |
| "Null object over nil-checks" bullet: from "A scattered `if x != nil`" through "absence is a value too" | nil, Go (the word), struct, interface | Include | `rules/R11/null-object-shape.md` — "The Go shape follows the collaborator's type", `type NopLogger struct{}`, `io.Discard`, `time.Now` |
| "**Flag arguments are two functions.** `func Render(a Alert, short bool)`" | func | Include | `rules/R11/flag-argument-example.md`, inline — the example signature |
| "let the `exhaustive` linter prove completeness" and Fix "no `default`, `exhaustive` linter enforcing completeness" | linter name | Include | `rules/R11/exhaustiveness-check.md`, inline at both sites. Python: mypy with `assert_never`; generic: the linter's exhaustiveness check where the language has one |
| "`if err != nil`, guard clauses" | nil | Include | part of the state-conditional examples; `rules/R11/state-conditional-examples.md`, inline |
| Fix, Introduce Null Object: "absent-collaborator nil-checks", "(`DiscardSink()` composing `io.Discard`)" | nil, interface | Scalar + Include | `{{.Nil}}-checks`; the parenthetical is `rules/R11/fix-null-object-example.md`, inline |
| Fix, Replace Duplicated Switch: "introduce `ParseX(raw) (X, error)` as the single decision point" | error tuple | Include | `rules/R11/decision-point-signature.md`, inline |

### Other rules

| File and anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| R1, scorecard: "Replacing `map[string]interface{}`: +2" | interface | Include | `rules/R1/scorecard-untyped-map.md`, inline — Python `dict[str, Any]`, generic "an untyped map" |
| R1, Fix: "introduce `ParseX(raw) (X, error)`" and "absence/invalidity → `(X, bool)` or `(X, error)`" | error tuple | Include | `rules/R1/constructor-signature.md` and `rules/R1/comma-ok-signature.md`, inline — Python: a classmethod that raises, and `X | None` for absence |
| R4, Design guidance: "The Go accelerant: embedding a domain type … `sync` primitives per `R10-concurrency-safety.md`" | Go, struct, interface, sync. | Include | `rules/R4/embedding-accelerant.md` — Python's accelerant is inheriting from a domain type; the generic text names inheritance or embedding |
| R5, role-named files: parser, handler, repository, service and the rename `<feature>_service` → `service` | source suffix (10 lines) | Scalar | `{{.SrcExt}}` on every file name; the layout is the same in a Python package |
| R9, "godoc comments → repo docs → the index", "a godoc comment lives beside the code" | godoc | Scalar | `{{.DocComment}}` |
| R9, "its godoc", "Code comments (godoc)", "the godoc states the incident", "richer inline godoc", "expanding <Symbol>'s godoc" | godoc | Scalar | `{{.DocForm}}` |
| R9, Guarantees: "thread safety, nil handling, invariants" | nil | Scalar | |
| R9, escape hatch: the "**Package docs in** …" bullet naming Go's dedicated package-doc file | source suffix, godoc | Include | `rules/R9/package-doc-file.md` — Python's package docstring lives in the package's init module |
| R9, monorepo note: "this build carries the Go adapter" | Go | Scalar | `{{.Lang}}` — a missed substitution |
| R12, Principle: "to Go, where slices and maps are references into shared backing storage" | Go | Include | `rules/R12/aliasing-semantics.md`, inline — true of Python lists and dicts too, with different nouns |
| R12, Why: "In Go, `return g.perms` does not return the permissions; it returns a mutable alias" | Go | Include | `rules/R12/aliasing-example.md`, inline |
| R12, no setters: "or returns a new value (`WithPort(n) (Server, error)`)" | error tuple | Include | `rules/R12/with-method-example.md`, inline — the parenthetical |
| R9, comment budget: "anything bigger belongs in an `Example_*` testable example" | Example_ | Include | `rules/R9/inline-example-overflow.md`, inline — Python: a doctest or an example under the docs |

### maxims.md

Aside, the whole file. The Go proverbs are attributed quotations and the scanner
already exempts the attribution lines. Their "Ask" and "Compiled into" paragraphs
mention `ParseX(raw) (X, error)`, `bytes.Buffer`, `sync.Mutex`, `io.Reader` and "this struct" as illustrations
of quoted doctrine; a Python or generic plugin quotes the same proverbs with the same
illustrations, the way a book on design quotes Go proverbs.

### Skills

| File and anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| pre-commit-review, hunter table row R2: "nil as a value"; cluster pass: "a nil handed to the constructor" | nil | Scalar | |
| pre-commit-review, hunter table rows R7 and R8: "wantErr conditionals", "`context.Background()` in library code" | wantErr, context. | Include | `skills/pre-commit-review/hunt-R7.md`, `hunt-R8.md`, one per row; the other ten rows are neutral and stay |
| pre-commit-review, hunter table row R10: "goroutines without exit paths or owners" | goroutine | Scalar | `{{.Task}}s` |
| pre-commit-review, Bugs category: "(nil returned as a value, cancellation swallowed by `context.Background()`, R10 goroutine leaks and unguarded concurrent writes)" | nil, context., goroutine | Include | `skills/pre-commit-review/bug-examples.md`, inline — the parenthetical |
| pre-commit-review, "(godoc, in-body, test)" and the report example's "the godoc restates the name" | godoc | Scalar | `{{.DocForm}}` |
| pre-commit-review, the cluster example's notify path and the report example's file paths | source suffix (11 lines) | Scalar | `{{.SrcExt}}`; the example's `// compare password` uses `{{.CommentPrefix}}`, which exists |
| pre-commit-review, "the switch stays, goes exhaustive" | exhaustive | Aside | |
| refactoring SKILL, pattern index row R2: "Replace nil returns" | nil | Scalar | |
| refactoring SKILL, pattern index rows R7, R8, R10 | wantErr, init(), ctx, goroutine | Include | `skills/refactoring/moves-R7.md`, `moves-R8.md`, `moves-R10.md` — the move-name cells; they must match the binding's Fix pattern includes |
| refactoring SKILL, "**Introduce Null Object, the Go shape.**" paragraph | Go, nil, interface | Include | `skills/refactoring/null-object-shape.md` |
| refactoring SKILL, "(`grep -rn 'func .*Parse' --include='{{.SrcGlob}}'` on the step's noun)" | func | Include | `skills/refactoring/find-existing-function.md`, inline — the grep pattern is Go syntax |
| refactoring SKILL, stop check step 2: "because a package-level variable, an `init()` or a singleton has no function to sit in" | init() | Include | `skills/refactoring/package-level-declarations.md`, inline — the list of R8 shapes that live outside any function |
| refactoring SKILL, stop check step 2: "the `init()` under it, the `context.Background()` in the function just reshaped" | init(), context. | Include | `skills/refactoring/rerun-leftovers.md`, inline — the list of illustrative leftovers |
| refactoring SKILL, noun check: "never a nil-able field, and an option handed nil records the error" | nil | Scalar | |
| refactoring SKILL, critic step: "the `// Sink is where events are written.` godoc beside the code" | godoc | Include | `skills/refactoring/restating-comment-example.md`, inline; a docstring is not a `#` comment, so the comment-prefix scalar does not fit |
| refactoring SKILL, "interface dispatch", "owned interface", "this struct three questions" | interface, struct | Aside | |
| refactoring SKILL, stop check step 2, the "still — routed again" example path, and the BROADER CONTEXT example line | source suffix | Scalar | `{{.SrcExt}}` |
| refactoring reference, "≥13 non-test … files at one directory level" | source suffix | Scalar | `{{.SrcExt}}` |
| refactoring reference, "`func normalizeFoo(s string) string` wants to be `(f Foo) Normalize()`" | func | Include | `skills/refactoring/method-candidate-example.md`, inline |
| refactoring reference, "**Persistence naming**: Store, not Repository (Go-idiomatic, concrete)" | Go | Include | `skills/refactoring/persistence-naming.md` — the claim is about Go idiom |
| refactoring reference, "the package provides context." | context. | Aside | scanner false positive: the English word at a sentence end |
| refactoring reference, "Never invert the arrow with an interface" | interface | Aside | |
| testing SKILL, "(table-driven vs testify suites)" | testify | Include | `skills/testing/strategy-choices.md`, inline |
| testing SKILL, "Use `pkg_test` package name" | pkg_test | Include | `skills/testing/public-api-package.md` — the bullet |
| testing SKILL, the five bullets under "No mocks" naming `httptest`, struct doubles and testutils | httptest, struct, interface | Include | `skills/testing/no-mocks-bullets.md`; the heading stays in core |
| testing SKILL, "**Assertions**: testify is the default … goweka uses stdlib assertions" | testify | Include | `skills/testing/assertions.md` |
| testing SKILL, rung 0: "No I/O, no goroutines, no production dependencies" | goroutine | Scalar | `{{.Task}}s` |
| testing SKILL, "httptest server, bufconn gRPC, in-memory NATS, temp files, embedded VictoriaMetrics" | httptest | Include | `skills/testing/real-layer-examples.md`, inline |
| code-designing, rule dispatch row R2: "nil is not a value" | nil | Scalar | |
| code-designing, rule dispatch row R8: "`ctx` threaded from callers" | ctx | Include | `skills/code-designing/dispatch-R8.md` — the cell |
| code-designing, rule dispatch row R10 and checklist R10: "Every planned goroutine", "Every goroutine has an owner" | goroutine | Scalar | `{{.Task}}` — the rest of both lines is neutral |
| code-designing, checklist R8: "ctx flows down" | ctx | Include | `skills/code-designing/checklist-R8.md` — the line |
| code-designing, "Every planned interface", "No test-only interfaces", "interface, strategy map, or a single exhaustive switch" | interface, exhaustive | Aside | |
| documentation SKILL, "narration in a godoc", "godocs and feature docs", "Rung 1 — godoc", "richer inline godoc", "godoc: <symbols touched>", "expanding its godoc" | godoc | Scalar | `{{.DocForm}}` |
| documentation SKILL, "A package that earns more moves its godoc to …" and "Add testable examples (`Example_*`)" | godoc, source suffix | Include | `skills/documentation/package-doc-and-examples.md` — the package-doc-file sentence and the `Example_*` sentence; the latter is unflagged Go today |
| documentation SKILL, "beats an exhaustive doc" | exhaustive | Aside | English |
| documentation SKILL, report artifacts: "testable examples: <Example_* functions>" | Example_ | Include | `skills/documentation/testable-examples-artifact.md` — the artifact line; Python lists doctests |
| linter-driven-development, trigger: "(`{{.ProjectMarker}}` or … files present)" | source suffix | Scalar | `{{.SrcExt}}` |
| linter-driven-development, SAFE gate: "(`go test -cover` on the touched packages)" | go test | Include | `skills/linter-driven-development/coverage-check.md`, inline — pytest spells it `--cov` |
| linter-driven-development, "creates a type/interface/package" | interface | Aside | |
| linter-driven-development, Phase 5: "godoc + feature docs" | godoc | Scalar | `{{.DocForm}}` |

### Agents and commands

| File and anchor | Tokens | Outcome | Slot or reason |
|---|---|---|---|
| rule-hunter, the worked example block from "Lead (pre-filter)" to the Finding line | source suffix (6 lines) | Include | `agents/rule-hunter/worked-example.md` — besides the paths it reads `strings.Contains` and `errors.New`, which the scanner does not flag; the block is one example and moves whole |
| overabstraction-skeptic, "A validating constructor, unexported fields, an Option func type with its `With*` functions, a named Null Object default …" | func | Include | `agents/overabstraction-skeptic/r2-mechanisms.md`, inline — the list |
| overabstraction-skeptic, "nil holes", "a nil-guard R2 deletes" | nil | Scalar | |
| overabstraction-skeptic, "the bigger the interface, the weaker the abstraction" | interface | Aside | attributed quotation |
| comment-critic, "after it writes godocs", "kind (godoc/in-body/test)" | godoc | Scalar | `{{.DocForm}}` |
| comment-critic, "godoc comments, in-body comments, and test comments" | godoc | Scalar | `{{.DocComment}}s` |
| lint-fixer, the parenthetical route example "(`gocognit → rules/R3-storifying.md (via @refactoring) at` …)" | linter name, source suffix | Include | `agents/lint-fixer/escalation-example.md`, inline — a Go linter name and a Go path in one example |
| lint-fixer, "belongs to the main context." | context. | Aside | scanner false positive |
| analyze command, "(incl. R10 goroutine leaks and unguarded concurrent writes)" | goroutine | Scalar | `{{.Task}}` |
| analyze command, the "Analyze specific file" usage example | source suffix | Scalar | `{{.SrcExt}}` |
| wire-repo-brain command, "one-line godoc edge additions" | godoc | Scalar | `{{.DocForm}}` |

## How the scanner enforces this

`task lint-core` is what keeps these decisions from being remembered instead of
enforced:

- **Soft tokens cover every idiom named above.** Besides the words with scalars, the
  scanner reports error-tuple signatures such as `(X, error)` and `(X, bool)`,
  `t.Run`, `Example_*`, and capitalized standard-library calls (`errors.New`,
  `io.Discard`, `time.Now`). A linter name counts only inside backticks, so the
  English word "exhaustive" is not a hit; `context.` needs a capital letter after
  the dot, so a sentence ending in "context." is not one either.
- **A scalar's literal becomes a hard token once no core line spells it.** While a
  literal is still triaged as an include that has not moved, it stays soft; the
  promotion to hard lands in the same change that moves the last literal, so
  `task lint-core` stays green on every commit.
- **A binding that overrides nothing** is the expected shape after this triage; the
  override mechanism stays for files outside the rules, such as a plugin README that
  differs entirely.

## Decisions taken to the plugin owner

The defaults below are what this document applies; each is one line to flip.

1. **`nil` is a scalar, not an override.** Python renders None, the generic plugin
   renders null; the Go idiom blocks around it are includes. The alternative — an R2
   override per binding — leaves core R2 unrendered by anyone.
2. **R6 and R10 are not overrides either**, for the same reason. R10's Design guidance
   and Fix pattern are each one include, which is the same amount of binding text an
   override would carry, without duplicating the Principle.
3. **Five new scalars**, all recurring words: `nil`, `task`, `doc_form`,
   `doc_comment`, `src_ext`. Anything used fewer than five times is an include, so the
   profile stays a list of spellings rather than a phrasebook.
4. **Move names for R7, R8 and R10 are binding-owned.** The three tables that cite
   them carry per-row includes for those rules only.
5. **`interface` is the general term** and stays in core prose, including R6's. The
   Python-specific mock forms live in R6's canonical example and questions.
