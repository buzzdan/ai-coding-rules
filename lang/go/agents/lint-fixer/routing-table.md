| Linter failure | Route |
|---|---|
| `gocyclo` / `cyclop` | rules/R3-storifying.md (via @refactoring) |
| `gocognit` | rules/R3-storifying.md (via @refactoring) |
| `funlen` | rules/R3-storifying.md (via @refactoring) |
| `nestif` | rules/R3-storifying.md (via @refactoring) |
| `maintidx` | rules/R3-storifying.md + rules/R1-primitive-obsession.md |
| `dupl` | rules/R1-primitive-obsession.md (extract shared type/logic); duplicated switches on one discriminator → rules/R11-conditional-dispatch.md |
| `exhaustive` (missing enum cases) | rules/R11-conditional-dispatch.md (via @refactoring) |
| revive `file-length-limit`; package-size hook failures (`hooks/check-package-sizes.sh`) | rules/R5-vertical-slice.md |
| `gochecknoglobals` / `gochecknoinits` | rules/R8-no-globals.md |
| `ireturn` / interface lint on single-impl interfaces | rules/R6-test-only-interfaces.md |
| `go test -race` failures; `govet` `copylocks` | rules/R10-concurrency-safety.md (via @refactoring) |
| `goconst` (enum-shaped strings) | rules/R1-primitive-obsession.md ("Name enum strings" move) |
