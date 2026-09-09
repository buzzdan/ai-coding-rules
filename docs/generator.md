---
type: guide
description: how the Go plugin directory is generated from core/ and lang/go/, and the checks that keep it honest
---
# Plugin Generator

The directory the marketplace serves, `go-linter-driven-development/`, is not edited
by hand. `tools/ldd-gen` renders it from two sources: `core/`, the language-neutral
text of the rules, skills, agents, commands and the repo-brain gate, and `lang/go/`,
the Go binding. The templating contract (the scalars, the include construct, overrides,
file-name templating) and the residue backlog live in [core/README.md](../core/README.md).

## Working on the plugin

1. Edit a file under `core/` or `lang/go/`. Text that is the same for every language
   belongs in `core/`; text that names Go tools, globs or idioms belongs in the binding
   as a `profile.yaml` scalar or an include file.
2. Run `task generate`. It renders the binding over the plugin directory: every file
   the generator owns is rewritten, and files it no longer produces are removed.
3. Commit the sources and the generated directory together.

`task check` renders every binding to memory and compares it with the plugin
directory on disk; any missing, extra or changed file, or a changed executable bit,
fails, and changed files print a unified diff. CI runs it on every pull request,
together with `task lint-core` (no hard residue in `core/`, and the Residue section of
its README is current), `task docs:check`, `task test-gate` (the generated gate passes
its own fixture matrix), and the generator's unit tests and linter. The fixture matrix
uses GNU `sed`, so on macOS two of its cases fail while the same run passes on Linux.
Paths listed under `ignore` in the profile, such as eval cases copied under the
plugin's `evals/` directory at run time, are left alone by both `check` and
`generate`; a file the generator produces inside such a directory is still checked.

## The generator

`ldd-gen` is a small Go module under `tools/ldd-gen` with its own `go.mod`, so the
repository root stays free of a Go module and the plugin's own package-size hook
stays quiet here; the root `go.work` makes `go run ./tools/ldd-gen` work from the
root. Any other Go module checked out below the root, such as the evals clone under
`.evals/`, must build with `GOWORK=off`, which `scripts/evals.sh` sets. Inside, `Profile` parses and validates the binding's scalars, `Binding` resolves
includes, overrides and passthrough files, `Render` produces the plugin tree in
memory, and `Compare` and `Write` sync that tree with the directory on disk.
