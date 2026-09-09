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
