## Generated plugins
`go-linter-driven-development/` and `linter-driven-development/` are generated from
`core/` plus `lang/go/` and `lang/generic/` by `tools/ldd-gen`. Never edit them by
hand: edit the sources, run `task generate` and `task generate BINDING=generic`, and
commit both. `task check` fails on any drift. The templating contract and the list of
files that stay in a binding are in core/README.md.

## Documentation
@AGENTS.md
@docs/index.md
