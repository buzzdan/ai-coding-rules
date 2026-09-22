Normative linter→rule routing, keyed by ruff codes and mypy. (The lint-fixer agent
embeds a compact copy of this table in `../../agents/lint-fixer.md` — keep them
consistent.) ruff has no duplicate-code, file-length, exhaustiveness or
single-implementer rule and Python has no race detector: those rows are review
findings the hunters own alone.

| Linter failure | Route |
|---|---|
| `C901` (complexity) | `../../rules/R3-storifying.md` |
| `PLR0912` (too many branches) / `PLR0915` (too many statements) | `../../rules/R3-storifying.md` |
| `PLR0911` (too many returns) | `../../rules/R3-storifying.md`; a tuple return with an error member is R1's named result type |
| `PLR1702` (nesting; preview) | `../../rules/R3-storifying.md` |
| `PLR0913` (too many arguments) | `../../rules/R1-primitive-obsession.md` (Introduce Parameter Object — a frozen dataclass, scored) |
| Duplicated code (review-only) | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated `match`/if-chains on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| A `match` missing enum cases (review-only; mypy sees it only under `assert_never`) | `../../rules/R11-conditional-dispatch.md` — handle the case at the single dispatch site and close it with `case _: assert_never(x)`; a second `match` appearing is the R11 violation itself |
| `FBT001` / `FBT002` (boolean positional parameter) | Mechanical — make it keyword-only; then read the branches: sharing little → `../../rules/R11-conditional-dispatch.md`, Split Flag Argument |
| File over ~450 lines (review-only) | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>`, `sed -n '/^## File and package routing/,/^## Preparatory mode/p'` over this skill's `reference.md` |
| `PLW0603` (`global` statement); import-time side effects (review-only) | `../../rules/R8-no-globals.md` |
| A `Protocol`/ABC with one implementer; a factory annotated to return the Protocol (review-only) | `../../rules/R6-test-only-interfaces.md` |
| Unguarded shared state; a `daemon=True` worker; `time.sleep` in a stoppable loop (review-only) | `../../rules/R10-concurrency-safety.md` |
| `B006` (mutable default argument) / `B008` (call in a default) | `../../rules/R12-mutation-discipline.md` (an immutable default, or a Null Object constant — never a shared literal) |
| `ARG` (unused argument), `SIM` (simplify), `RET` (return style), `B904` (`raise … from`), `BLE001`/`E722` (broad or bare `except`), `PLR2004` (magic value), `F401`/`F841` (unused import/variable), `I` (import order), `E`/`W` (style), `D` (docstring form), mypy `arg-type`/`return-value`/`assignment` | Mechanical — fix directly (name the constant, narrow the `except`, chain the exception, fix the type or the call, delete the unused symbol, write the docstring per @documentation's menus). Enum-shaped `PLR2004` strings and `== "READY"` comparisons → R1's "Name enum strings" move. A mypy `return-value` on `return None` is R1 Q4 — never a `# type: ignore`. |
