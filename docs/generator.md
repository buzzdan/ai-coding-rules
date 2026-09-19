---
type: guide
description: how the plugin directories are generated from core/ and one binding under lang/, and the checks that keep them honest
---
# Plugin Generator

The directories the marketplace serves, `go-linter-driven-development/`,
`python-linter-driven-development/` and `linter-driven-development/`, are not edited
by hand. `tools/ldd-gen` renders each from two sources: `core/`, the language-neutral
text of the rules, skills, agents, commands and the repo-brain gate, and one binding
under `lang/` — `lang/go/` for the Go plugin, `lang/python/` for the Python plugin,
`lang/generic/` for the plugin that detects the language at run time. The
templating contract (the scalars, the include construct and its `core/includes/`
defaults, overrides, file-name templating) and the residue backlog live in
[core/README.md](../core/README.md); how a Go idiom in core prose is rendered for a
second language is decided in [language-residue.md](language-residue.md).

## Working on the plugins

1. Edit a file under `core/` or `lang/<binding>/`. Text that is the same for every
   language belongs in `core/`; text that names one language's tools, globs or
   idioms belongs in that binding as a `profile.yaml` scalar or an include file; the
   language-neutral default for an include slot belongs in `core/includes/`, where a
   binding without its own file picks it up. A binding may also declare
   `include_fallback` in its profile to read another binding's includes under one
   path prefix; the generic binding reads the Go case-study sections this way.
2. Run `task generate` for the Go plugin, `task generate BINDING=python` for the
   Python one and `task generate BINDING=generic` for the generic one. Each renders
   its binding over its plugin directory: every file the generator owns is
   rewritten, and files it no longer produces are removed.
3. Commit the sources and the generated directories together. A binding without its
   rendered directory turns CI red for everyone, because `task check` renders every
   directory under `lang/`.

`task check` renders every binding to memory and compares it with the plugin
directory on disk; any missing, extra or changed file, or a changed executable bit,
fails, and changed files print a unified diff. CI runs it on every pull request,
together with `task lint-core` (no hard residue in `core/`, and the Residue section of
its README is current), `task docs:check`, `task test-gate` (each generated gate passes
its own fixture matrix — the Go and Python gates on their own row, the generic gate
once per language its adapter detects), and the generator's unit tests and linter. The fixture matrix uses
GNU `sed`, so on macOS two of its cases fail while the same run passes on Linux.
Paths listed under `ignore` in the profile, such as eval cases copied under the
plugin's `evals/` directory at run time, are left alone by both `check` and
`generate`; a file the generator produces inside such a directory is still checked.

## The generator

`ldd-gen` is a small Go module under `tools/ldd-gen` with its own `go.mod`, so the
repository root stays free of any Go module or workspace file: the plugin's own
package-size hook stays quiet here, and Go modules checked out below the root (the
evals clone, the eval fixture) build normally. The tasks run the tool from its own
directory and pass the repository root with `-root`. Inside, `Profile` parses and validates the binding's scalars, `Binding` resolves
includes, overrides and passthrough files, `Render` produces the plugin tree in
memory, and `Compare` and `Write` sync that tree with the directory on disk.
