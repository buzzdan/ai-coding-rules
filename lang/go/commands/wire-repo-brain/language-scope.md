**Language scope**: this is the Go plugin, so code↔docs verification is
Go-first. On a repo with no Go, the pass still delivers the whole structure
layer (frontmatter, index, drift check, conventions, routing, CI gate on
structure) — but code→docs edges, symbol drift detection, and the file-path
ban only cover `.go` files, and doc roots are only discovered at the repo root
and `go.mod` sub-projects (a TS/Python sub-project's own docs/ is not wired —
it is reported, not silently skipped). Non-Go CamelCase symbols cited in
covered docs still resolve via the gate's whole-word fallback.
