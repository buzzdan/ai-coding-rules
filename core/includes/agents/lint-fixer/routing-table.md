| Linter failure | Route |
|---|---|
| Cyclomatic or cognitive complexity over the limit | rules/R3-storifying.md (via @refactoring) |
| Function too long | rules/R3-storifying.md (via @refactoring) |
| Nesting too deep | rules/R3-storifying.md (via @refactoring) |
| Maintainability index too low | rules/R3-storifying.md + rules/R1-primitive-obsession.md |
| Duplicated code | rules/R1-primitive-obsession.md (extract shared type/logic); duplicated switches on one discriminator → rules/R11-conditional-dispatch.md |
| Non-exhaustive switch or match (missing enum cases) | rules/R11-conditional-dispatch.md (via @refactoring) |
| File too long; a directory in the package-size red zone | rules/R5-vertical-slice.md |
| Mutable global variable; import-time side effect | rules/R8-no-globals.md |
| Interface, protocol or abstract class with a single implementation; returning an interface | rules/R6-test-only-interfaces.md |
| Data race; copied lock; unsynchronized shared state | rules/R10-concurrency-safety.md (via @refactoring) |
| Repeated string constant that is enum-shaped | rules/R1-primitive-obsession.md ("Name enum strings" move) |
| A finding no row above describes | Escalate to the rule its *message* describes, and name the linter it came from — never silence it, never guess |

The rows name finding families, not one linter's check names: the repository's linter
reports each family under its own name (a complexity check, a length check, a
duplication check), and its message says which row applies.