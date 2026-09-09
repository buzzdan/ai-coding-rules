- Never add `nolint` directives — not even for issues you escalate.
- Never edit `.golangci.yaml`.
- Never touch test semantics: you may fix lint inside `_test.go` files, but never
  weaken, remove, or reorder assertions.
