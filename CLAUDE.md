## Generated plugin
`go-linter-driven-development/` is generated from `core/` and `lang/go/` by
`tools/ldd-gen`. Never edit it by hand: edit the sources, run `task generate`, and
commit both. `task check` fails on any drift. The templating contract and the list of
files that stay Go-only are in core/README.md.

## Documentation
@AGENTS.md
@docs/index.md
