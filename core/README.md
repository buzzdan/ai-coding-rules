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

Go `text/template` with the default delimiters and exactly two constructs:

- `{{.Plugin}}`, `{{.Lang}}`, `{{.CmdPrefix}}`, `{{.SrcGlob}}`, `{{.TestGlob}}`,
  `{{.ProjectMarker}}`, `{{.Nolint}}`, `{{.CommentPrefix}}`, `{{.DefaultTest}}`,
  `{{.DefaultLint}}`, `{{.DefaultLintFix}}` — scalars from `profile.yaml`.
- `{{include "rules/R1/canonical-example.md"}}` — the body of that file under
  `lang/<lang>/`, with exactly one trailing newline removed.

File-level rules the generator applies without template syntax:

- `lang/<lang>/overrides/<core path>` replaces the core file of the same path.
- File names are templates too: `core/commands/{{.CmdPrefix}}-analyze.md` renders
  to `commands/go-ldd-analyze.md` for the Go binding.
- This README is documentation for `core/` itself and is never rendered.

Include files carry no leading or trailing blank lines; the surrounding template
owns them. That is what keeps a rendered file byte-identical to a hand-written one.

## What stays in the binding

Some Go-owned files have no portable text worth extracting, or their seams are not
clear yet. They sit under `lang/go/passthrough/` and are copied into the plugin
unchanged. Promotion into `core/` happens when a second language needs the text:

- `skills/documentation/reference.md`: the Comment Value Toolbox is portable
  doctrine, the godoc menus and testable-example template are Go, and the templates
  after them are portable but every worked example is Go code.
- `scripts/check-repo-brain_test.sh`: the 45 cases are the language adapter's
  contract, but besides the conformant fixture several cases embed Go source,
  `go.mod` files and Go-specific path patterns.
- `skills/testing/reference.md` and `skills/testing/examples/`: a Go test-harness
  catalogue.
- `examples/`: worked case studies written as Go code.
- `README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `hooks/`: describe or
  configure the Go plugin itself.

## Residue

`task lint-core` scans `core/` for language-specific text and rewrites this section.
Hard residue is a plugin-name literal, linter name, source glob or nolint directive:
each has a profile scalar or an include, so a hit is a missed substitution and fails
the check. Soft residue is inline Go vocabulary (`nil`, `ctx`, goroutines, `interface`)
that reads fine in a Go plugin; it is the list of words a second language binding
must decide how to render, by scalar, include or whole-file override.

<!-- residue:begin -->
Hard residue: none. Every plugin-name literal, linter name, source glob and
nolint directive in the plugin comes from a binding.

Soft residue by token (217 lines):

| Token | Lines | Files |
|---|---:|---:|
| interface | 45 | 12 |
| .go suffix | 30 | 8 |
| godoc | 22 | 6 |
| goroutine | 18 | 5 |
| nil | 18 | 6 |
| ctx | 15 | 4 |
| struct | 13 | 9 |
| context. | 12 | 5 |
| httptest | 10 | 3 |
| Go (the word) | 7 | 5 |
| sync. | 7 | 4 |
| func | 5 | 3 |
| init() | 4 | 2 |
| wantErr | 4 | 3 |
| pkg_test | 3 | 2 |
| Go code fence | 2 | 1 |
| go test / go vet | 2 | 2 |

Soft residue by file (217 lines):

| File | Lines | Tokens |
|---|---:|---:|
| `rules/R10-concurrency-safety.md` | 30 | 6 |
| `rules/R6-test-only-interfaces.md` | 18 | 3 |
| `skills/pre-commit-review/SKILL.md` | 18 | 6 |
| `rules/R2-self-validating-types.md` | 16 | 4 |
| `rules/R11-conditional-dispatch.md` | 15 | 4 |
| `rules/R8-no-globals.md` | 14 | 5 |
| `skills/testing/SKILL.md` | 14 | 5 |
| `rules/R9-repo-brain.md` | 12 | 4 |
| `rules/R5-vertical-slice.md` | 10 | 1 |
| `skills/code-designing/SKILL.md` | 10 | 4 |
| `rules/R7-test-placement.md` | 9 | 6 |
| `skills/documentation/SKILL.md` | 8 | 2 |
| `skills/refactoring/SKILL.md` | 8 | 6 |
| `maxims.md` | 7 | 3 |
| `agents/rule-hunter.md` | 5 | 1 |
| `skills/refactoring/reference.md` | 5 | 5 |
| `skills/linter-driven-development/SKILL.md` | 4 | 4 |
| `agents/comment-critic.md` | 3 | 1 |
| `rules/R4-helper-placement.md` | 3 | 3 |
| `commands/{{.CmdPrefix}}-analyze.md` | 2 | 2 |
| `rules/R12-mutation-discipline.md` | 2 | 1 |
| `agents/lint-fixer.md` | 1 | 1 |
| `agents/overabstraction-skeptic.md` | 1 | 1 |
| `commands/wire-repo-brain.md` | 1 | 1 |
| `rules/R1-primitive-obsession.md` | 1 | 1 |
<!-- residue:end -->
