## Generated plugins
`go-linter-driven-development/`, `linter-driven-development/`,
`python-linter-driven-development/` and the handbooks under `coding-rules/` are generated from
`core/` plus `lang/go/`, `lang/generic/` and `lang/python/` by `tools/ldd-gen`. Never
edit them by hand: edit the sources, run `task generate`, `task generate
BINDING=generic` and `task generate BINDING=python`, and commit all of them. `task
check` fails on any drift. The templating contract and the list of
files that stay in a binding are in core/README.md.

## Documentation
@AGENTS.md
@docs/index.md
