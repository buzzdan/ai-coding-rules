Normative linter→rule routing, keyed by what a finding is *about*. The rows name
the finding families most linters report under some name; route the repository's
own linter by the family its message describes, whatever the check is called. (The
lint-fixer agent embeds a compact copy of this table in `../../agents/lint-fixer.md`
— keep them consistent.)

| Linter failure | Route |
|---|---|
| Cyclomatic or cognitive complexity over the limit | `../../rules/R3-storifying.md` |
| Function too long | `../../rules/R3-storifying.md` |
| Nesting too deep | `../../rules/R3-storifying.md` |
| Maintainability index too low | `../../rules/R3-storifying.md` + `../../rules/R1-primitive-obsession.md` |
| Duplicated code | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated blocks that switch on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| Non-exhaustive switch or match (missing enum cases) | `../../rules/R11-conditional-dispatch.md` — handle the case at the single dispatch site; a second switch appearing is the R11 violation itself |
| File too long; a directory in the package-size red zone | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>`, `sed -n '/^## File and package routing/,/^## Preparatory mode/p'` over this skill's `reference.md` |
| Mutable global variable; import-time side effect | `../../rules/R8-no-globals.md` |
| Interface, protocol or abstract class with a single implementation; returning an interface | `../../rules/R6-test-only-interfaces.md` |
| Data race; copied lock; unsynchronized shared state | `../../rules/R10-concurrency-safety.md` |
| Unchecked error, missing error context, magic constant, early-return style, unused symbol, shadowed variable, renames, formatting, import order | Mechanical — fix directly (handle the error, add context when wrapping it, extract the constant, invert & return early, delete or rename). Enum-shaped repeated strings → R1's "Name enum strings" move. |
| A finding no row above describes | Never silenced, never guessed: escalate it to the rule its *message* describes and name the linter it came from. |