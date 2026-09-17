# Core

`core/` holds the language-neutral text of the linter-driven-development plugins:
rules, skills, agents, commands and the repo-brain gate, written once and rendered
per language. `lang/<lang>/` holds one binding per language: a `profile.yaml` with
the scalars the templates substitute, the snippet files they include, whole-file
overrides, and `passthrough/` for files copied into the plugin unchanged. Two
bindings exist: `lang/go/` renders `go-linter-driven-development/`, and
`lang/generic/` renders `linter-driven-development/`, the plugin for repositories
without a language binding — its profile holds phrases the model reads as
instructions, and it adds a file only where detection differs from knowledge
(`docs/language-residue.md`, "The generic binding").

`tools/ldd-gen` renders `core/` plus a binding into the plugin directory the
marketplace serves. Edit sources here or under `lang/`, run `task generate` (and
`task generate BINDING=generic`), and commit both; `task check` fails when a plugin
directory differs from its rendering.

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

## What stays in the binding

Some Go-owned files have no portable text worth extracting, or their seams are not
clear yet. They sit under `lang/go/passthrough/` and are copied into the plugin
unchanged. Promotion into `core/` happens when a second language needs the text:

- `skills/testing/reference.md` and `skills/testing/examples/`: a Go test-harness
  catalogue. The generic binding ships a short `skills/testing/reference.md` of its
  own that says so and points at the repository's test utilities.
- `examples/`: worked case studies written as Go code. Core rules and skills cite
  them by relative path; a binding without an `examples/` directory renders those
  citations as names of studies, not files.
- `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `hooks/`: describe or
  configure the Go plugin itself.

Two files the generic binding needed have been promoted and carry a note here
because the Go plugin renders them differently from the other bindings:

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

Soft residue by token (99 lines):

| Token | Lines | Files |
|---|---:|---:|
| interface | 69 | 20 |
| Go code fence | 12 | 1 |
| Go (the word) | 6 | 4 |
| struct | 6 | 4 |
| Go stdlib | 5 | 4 |
| race detector | 2 | 2 |
| func | 1 | 1 |
| sync. | 1 | 1 |

Soft residue by file (99 lines):

| File | Lines | Tokens |
|---|---:|---:|
| `skills/documentation/reference.md` | 18 | 5 |
| `rules/R11-conditional-dispatch.md` | 13 | 1 |
| `rules/R6-test-only-interfaces.md` | 13 | 1 |
| `includes/rules/R6/falsifying-questions.md` | 8 | 1 |
| `maxims.md` | 7 | 4 |
| `includes/rules/R11/falsifying-questions.md` | 5 | 1 |
| `skills/code-designing/SKILL.md` | 5 | 1 |
| `skills/refactoring/SKILL.md` | 4 | 2 |
| `skills/testing/SKILL.md` | 4 | 1 |
| `includes/skills/documentation/reference/doc-comment-menus.md` | 3 | 1 |
| `includes/rules/R10/falsifying-questions.md` | 2 | 2 |
| `agents/overabstraction-skeptic.md` | 1 | 1 |
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
