# Core

`core/` holds the language-neutral text of the linter-driven-development plugins:
rules, skills, agents, commands and the repo-brain gate, written once and rendered
per language. `lang/<lang>/` holds one binding per language: a `profile.yaml` with
the scalars the templates substitute, the snippet files they include, whole-file
overrides, and `passthrough/` for files copied into the plugin unchanged. Three
bindings exist: `lang/go/` renders `go-linter-driven-development/`; `lang/python/`
renders `python-linter-driven-development/`, adding a file wherever Python knowledge
beats detection and recording its positions in `docs/language-residue.md`, "The
Python binding"; and `lang/generic/` renders `linter-driven-development/`, the plugin
for repositories without a language binding — its profile holds phrases the model
reads as instructions, and it adds a file only where detection differs from
knowledge (`docs/language-residue.md`, "The generic binding").

`tools/ldd-gen` renders `core/` plus a binding into the plugin directory the
marketplace serves, and, for a binding whose profile names one, the standalone
coding-rules handbook outside it (`coding-rules/go.md`; "The handbook" below). Edit
sources here or under `lang/`, run `task generate` (and `task generate
BINDING=python`, `task generate BINDING=generic`), and commit all of them; `task
check` fails when a plugin directory or a handbook differs from its rendering.

## Templating

Go `text/template` with the default delimiters. Core files use only two constructs:

- `{{.Plugin}}`, `{{.Lang}}`, `{{.CmdPrefix}}`, `{{.SrcGlob}}`, `{{.TestGlob}}`,
  `{{.ProjectMarker}}`, `{{.Nolint}}`, `{{.CommentPrefix}}`, `{{.DefaultTest}}`,
  `{{.DefaultLint}}`, `{{.DefaultLintFix}}`, `{{.Nil}}`, `{{.Task}}`, `{{.DocForm}}`,
  `{{.DocComment}}`, `{{.SrcExt}}`, `{{.Unexported}}` — scalars from `profile.yaml`.
  The last six are single words core prose uses as common nouns (the missing value, a
  unit of concurrent work, the documentation comment form, the source-file suffix,
  the visibility of a non-public symbol); which sentences use them, and which Go
  idioms are includes instead, is recorded in `docs/language-residue.md`. A template that names a scalar the profile does not
  define fails to render.
- `{{include "rules/R1/canonical-example.md"}}` — the body of that file under
  `lang/<lang>/`, with exactly one trailing newline removed. When the binding has no
  file of that name, the body comes from `core/includes/` under the same path: the
  language-neutral default, so a binding adds a file only where its language differs.
  A name found in neither place is an error. Files under `core/includes/` are never
  rendered as outputs. An include body is itself a template — it may name scalars —
  but it may not include another file. An include sits at a block boundary — a bullet, paragraph,
  fence or table row — never inside a sentence; which text is an include and which is
  reworded in core is decided in `docs/language-residue.md`.

File-level rules the generator applies without template syntax:

- `include_fallback: {from: <lang>, under: <prefix>/}` in a profile makes another
  binding's include files stand in for the ones this binding lacks, for include
  names under that prefix only, before the core default is tried. One step only: a
  fallback binding may not itself fall back, and overrides and passthrough files
  never fall back. The generic binding uses it to read the Go case-study sections.
- `lang/<lang>/overrides/<core path>` replaces the core file of the same path (the
  path as written in `core/`, before file-name templating). The override is rendered as
  a template like the file it replaces and carries its own executable bit. An override
  with no matching core file is an error.
- File names are templates too: `core/commands/{{.CmdPrefix}}-analyze.md` renders
  to `commands/go-ldd-analyze.md` for the Go binding. The profile's `cmd_prefix` is
  limited to lower-case letters, digits and dashes, and a rendered path that is not a
  clean path inside the plugin is an error. `commands/wire-repo-brain.md` carries no
  prefix, so two installed bindings would both offer `/wire-repo-brain`; the second
  binding decides whether that command gets the prefix.
- This README is documentation for `core/` itself and is never rendered. Editor and OS
  droppings (`.DS_Store`, `._*`, `*.swp`, `*~`, `.#*`, `Thumbs.db`, `desktop.ini`) and
  any file or directory whose name the profile's `ignore` lists without a slash are never
  read as sources either.
- `task generate` refuses to write when two bindings name the same plugin, when the
  rendering has no named `.claude-plugin/plugin.json`, or when the target directory
  already holds files and its manifest names a different plugin. A wrong `plugin` name
  in a profile therefore cannot delete another plugin or any other directory.

Include files carry no leading or trailing blank lines; the surrounding template
owns them. That is what keeps a rendered file byte-identical to a hand-written one.

## The handbook

`handbook/coding-rules.md` is the one core file that is not a plugin file: it is the
template of the standalone coding-rules document a team reads without the plugin,
rendered for every binding whose profile names a `handbook:` path (a clean relative
markdown path under the repository root, outside every plugin directory, such as
`coding-rules/go.md`). `task generate` writes it, `task check` compares it, and a
file at that path that does not open with the generator's marker comment is never
overwritten. The rendered document restates nothing: besides `{{include}}`, the
template has five extraction functions that read the rules the plugin already
carries, so the handbook cannot drift from the plugin.

| Construct | Renders |
|---|---|
| `{{section "rules/R1-primitive-obsession.md" "Principle"}}` | the body of that `## ` section of the core file, through the binding, with `` `Rn-….md` `` references shortened to `Rn` |
| `{{moves "rules/R1-primitive-obsession.md"}}` | the bold leads of the rule's Fix-pattern bullets, joined with ` · `; a lead that is a sentence (opens with an article, carries a comma, ends in punctuation) is guidance, not a move, and is left out |
| `{{questions "rules/R1/falsifying-questions.md" 1 4}}` | the bold headlines of the numbered questions in that include — the binding's file, else the core default — for the numbers given, or all of them with none; a number the file lacks is an error |
| `{{maxim "Tell, don't ask"}}` | `**Tell, don't ask.**` followed by that maxim's `**Ask:**` paragraph from `maxims.md` |
| `{{reviews "handbook/house-rules.md"}}` | the `**Review:**` lines of that include, joined with ` · ` |

What the binding supplies, under `lang/<lang>/handbook/`: `R1/example.md` to
`R12/example.md`, one short before-and-after per rule with an optional aside on the
language's position (`> **In Go:** …`); `house-rules.md`, the rules that exist only
in that language, each a `### ` heading, a short principle and one `**Review:**`
line; and `mechanics.md`, extra rows for the mechanics table. These have no core
default yet: a binding that names a `handbook:` path writes all of them. How to read
and consume the result: `docs/handbook.md`.

## What stays in the binding

Some Go-owned files have no portable text worth extracting, or their seams are not
clear yet. They sit under `lang/go/passthrough/` and are copied into the plugin
unchanged. Promotion into `core/` happens when a second language needs the text:

- `skills/testing/reference.md` and `skills/testing/examples/`: a Go test-harness
  catalogue. The generic binding ships a short `skills/testing/reference.md` of its
  own that says so and points at the repository's test utilities; the Python binding
  ships a short pytest catalogue in the same shape.
- `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `hooks/`: describe or
  configure the Go plugin itself.

Three promoted pieces carry a note here because the Go plugin renders them
differently from the other bindings:

- `examples/*.md`, the six case studies, are core templates. Each keeps its title,
  section headings and doctrine — the verdicts, scorecards, decision questions and
  the skeptic's operating rule — in core, and renders every code section (a fence
  with the paragraphs that narrate its identifiers) from an include under
  `examples/<case>/`. The Go binding's sections are cut from the original text; the
  Python binding's are written in Python. The generic binding declares
  `include_fallback: {from: go, under: examples/}` in its profile, so it reads the
  Go sections, and adds the demonstration note through
  `examples/language-note.md` — the one include that carries its own leading and
  trailing blank lines, because its default (and the Go and Python rendering) is
  empty and the template's line then becomes the paragraph break. These sections
  have no neutral default under `core/includes/`: a binding writes them or names
  a fallback, and the generator says so when it does neither.

- `skills/documentation/reference.md` is a core template. The Comment Value Toolbox
  and the templates after it are core; the doc-comment menus, the decoder-ring and
  runnable-example fences, the conventions-doc language sentence, the tail of the
  code-comments checklist and the bug-fix examples are includes, with the Go text
  under `lang/go/skills/documentation/reference/` and neutral defaults under
  `core/includes/`.
- `scripts/check-repo-brain_test.sh` is a core template whose cases read one include,
  `scripts/repo-brain-fixture.sh`: the fixture rows (marker, code file, second
  package, sub-project) for every language the rendered gate's adapter serves. The
  Go binding keeps its previous matrix verbatim as the one override in this
  repository, `lang/go/overrides/scripts/check-repo-brain_test.sh`, so the Go plugin
  stays byte-identical; the override goes when a Go release adopts the promoted
  matrix with a Go fixture include.

## Residue

`task lint-core` scans `core/` for language-specific text and rewrites this section.
Hard residue is a plugin-name or command-prefix literal, a `golangci` reference, a
source-file glob or a nolint directive: each has a profile scalar or an include, so a
hit is a missed substitution and fails the check. Soft residue is Go vocabulary that
reads fine in a Go plugin (`nil`, `ctx`, goroutines, `interface`, error tuples,
standard-library calls, linter and library names such as `exhaustive` or `testify`);
it is the list of words a second language binding must decide how to render, by
scalar, include or whole-file override. The decision per token is recorded in
`docs/language-residue.md`.

<!-- residue:begin -->
Hard residue: none. No plugin-name or command-prefix literal, golangci
reference, source-file glob, nolint directive, scalar word or retired Go idiom is
left in core/.

Soft residue by token (111 lines):

| Token | Lines | Files |
|---|---:|---:|
| interface | 80 | 23 |
| Go code fence | 12 | 1 |
| struct | 7 | 5 |
| Go (the word) | 6 | 4 |
| Go stdlib | 5 | 4 |
| race detector | 2 | 2 |
| func | 1 | 1 |
| sync. | 1 | 1 |

Soft residue by file (111 lines):

| File | Lines | Tokens |
|---|---:|---:|
| `skills/documentation/reference.md` | 18 | 5 |
| `rules/R11-conditional-dispatch.md` | 13 | 1 |
| `rules/R6-test-only-interfaces.md` | 13 | 1 |
| `includes/rules/R6/falsifying-questions.md` | 8 | 1 |
| `maxims.md` | 7 | 4 |
| `examples/switch-to-polymorphism.md` | 6 | 2 |
| `examples/anti-if-dispatch.md` | 5 | 1 |
| `includes/rules/R11/falsifying-questions.md` | 5 | 1 |
| `skills/code-designing/SKILL.md` | 5 | 1 |
| `skills/refactoring/SKILL.md` | 4 | 2 |
| `skills/testing/SKILL.md` | 4 | 1 |
| `includes/skills/documentation/reference/doc-comment-menus.md` | 3 | 1 |
| `includes/rules/R10/falsifying-questions.md` | 2 | 2 |
| `agents/overabstraction-skeptic.md` | 1 | 1 |
| `examples/storify-leaf-type.md` | 1 | 1 |
| `includes/agents/lint-fixer/routing-table.md` | 1 | 1 |
| `includes/rules/R1/canonical-example.md` | 1 | 1 |
| `includes/rules/R10/canonical-example.md` | 1 | 1 |
| `includes/rules/R11/canonical-example.md` | 1 | 1 |
| `includes/rules/R3/canonical-example.md` | 1 | 1 |
| `includes/rules/R6/canonical-example.md` | 1 | 1 |
| `includes/rules/R7/falsifying-questions.md` | 1 | 1 |
| `includes/rules/R8/falsifying-questions.md` | 1 | 1 |
| `includes/rules/R9/canonical-example.md` | 1 | 1 |
| `includes/skills/refactoring/routing-table.md` | 1 | 1 |
| `includes/skills/refactoring/testing-integration.md` | 1 | 1 |
| `rules/R10-concurrency-safety.md` | 1 | 1 |
| `rules/R2-self-validating-types.md` | 1 | 1 |
| `rules/R7-test-placement.md` | 1 | 1 |
| `skills/linter-driven-development/SKILL.md` | 1 | 1 |
| `skills/refactoring/reference.md` | 1 | 1 |
<!-- residue:end -->
