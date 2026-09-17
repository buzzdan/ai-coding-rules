# Core

`core/` holds the language-neutral text of the linter-driven-development plugins:
rules, skills, agents, commands and the repo-brain gate, written once and rendered
per language. `lang/<lang>/` holds one binding per language: a `profile.yaml` with
the scalars the templates substitute, the snippet files they include, whole-file
overrides, and `passthrough/` for files copied into the plugin unchanged.

`tools/ldd-gen` renders `core/` plus a binding into the plugin directory the
marketplace serves. Edit sources here or under `lang/`, run `task generate`, and
commit both; `task check` fails when a plugin directory differs from its rendering.

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
  rendered as outputs. An include sits at a block boundary — a bullet, paragraph,
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

- `skills/documentation/reference.md`: the Comment Value Toolbox is portable
  guidance, the godoc menus and testable-example template are Go, and the templates
  after them are portable but every worked example is Go code.
- `scripts/check-repo-brain_test.sh`: the fixture matrix is the language adapter's
  contract, but besides the conformant fixture several cases embed Go source,
  `go.mod` files and Go-specific path patterns.
- `skills/testing/reference.md` and `skills/testing/examples/`: a Go test-harness
  catalogue.
- `examples/`: worked case studies written as Go code.
- `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `hooks/`: describe or
  configure the Go plugin itself.

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
reference, source-file glob or nolint directive is left in core/.

Soft residue by token (312 lines):

| Token | Lines | Files |
|---|---:|---:|
| interface | 51 | 13 |
| nil | 42 | 7 |
| .go suffix | 34 | 10 |
| Go stdlib | 34 | 9 |
| godoc | 23 | 7 |
| unexported | 20 | 13 |
| goroutine | 18 | 5 |
| ctx | 15 | 4 |
| error tuple | 13 | 6 |
| struct | 13 | 9 |
| func | 11 | 5 |
| context. | 10 | 4 |
| httptest | 10 | 3 |
| Go (the word) | 9 | 7 |
| zero value | 8 | 4 |
| sync. | 7 | 4 |
| Go library | 6 | 3 |
| init() | 6 | 2 |
| Go linter name | 4 | 2 |
| wantErr | 4 | 3 |
| Example_ | 3 | 2 |
| Go code fence | 3 | 1 |
| pkg_test | 3 | 2 |
| go test / go vet | 2 | 2 |
| panic | 2 | 1 |
| t.Run | 2 | 1 |
| race detector | 1 | 1 |

Soft residue by file (312 lines):

| File | Lines | Tokens |
|---|---:|---:|
| `rules/R2-self-validating-types.md` | 53 | 9 |
| `rules/R10-concurrency-safety.md` | 33 | 10 |
| `rules/R11-conditional-dispatch.md` | 25 | 9 |
| `skills/refactoring/SKILL.md` | 22 | 12 |
| `skills/pre-commit-review/SKILL.md` | 20 | 7 |
| `rules/R6-test-only-interfaces.md` | 19 | 4 |
| `rules/R9-repo-brain.md` | 14 | 6 |
| `rules/R8-no-globals.md` | 13 | 7 |
| `skills/code-designing/SKILL.md` | 12 | 5 |
| `skills/testing/SKILL.md` | 12 | 7 |
| `rules/R7-test-placement.md` | 11 | 9 |
| `agents/overabstraction-skeptic.md` | 10 | 6 |
| `maxims.md` | 10 | 6 |
| `rules/R5-vertical-slice.md` | 10 | 1 |
| `skills/documentation/SKILL.md` | 10 | 4 |
| `agents/rule-hunter.md` | 6 | 2 |
| `rules/R1-primitive-obsession.md` | 6 | 4 |
| `rules/R4-helper-placement.md` | 5 | 4 |
| `skills/linter-driven-development/SKILL.md` | 5 | 5 |
| `skills/refactoring/reference.md` | 5 | 5 |
| `agents/comment-critic.md` | 4 | 2 |
| `rules/R12-mutation-discipline.md` | 3 | 2 |
| `commands/{{.CmdPrefix}}-analyze.md` | 2 | 2 |
| `agents/lint-fixer.md` | 1 | 1 |
| `commands/wire-repo-brain.md` | 1 | 1 |
<!-- residue:end -->
