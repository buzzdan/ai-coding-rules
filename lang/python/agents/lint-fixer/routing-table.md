| Linter failure | Route |
|---|---|
| `C901` (complexity) | rules/R3-storifying.md (via @refactoring) |
| `PLR0912` / `PLR0915` (branches, statements) | rules/R3-storifying.md (via @refactoring) |
| `PLR0911` (too many returns) | rules/R3-storifying.md (via @refactoring); a tuple return with an error member → rules/R1-primitive-obsession.md |
| `PLR1702` (nesting) | rules/R3-storifying.md (via @refactoring) |
| `PLR0913` (too many arguments) | rules/R1-primitive-obsession.md (Introduce Parameter Object) |
| `FBT001` / `FBT002` whose branches share little after the keyword-only fix | rules/R11-conditional-dispatch.md (Split Flag Argument) |
| `PLW0603` (`global` statement) | rules/R8-no-globals.md |
| `B006` / `B008` (mutable or call default) | rules/R12-mutation-discipline.md; a `None`-able collaborator default → rules/R11-conditional-dispatch.md ("Introduce Null Object") |
| `PLR2004` on an enum-shaped string | rules/R1-primitive-obsession.md ("Name enum strings" move) |
| mypy `return-value` on a `return None` from a `-> X` function | rules/R1-primitive-obsession.md (Q4 — a sentinel, never a `# type: ignore`) |
| mypy `arg-type` for `None` passed to an `X` parameter | rules/R2-self-validating-types.md (Q6 — fix the caller or introduce a Null Object; never widen the parameter to `X \| None`) |
