Normative linter→rule routing. (The lint-fixer agent embeds a compact copy of this
table in `../../agents/lint-fixer.md` — keep them consistent.)

| Linter failure | Route |
|---|---|
| `gocyclo` / `cyclop` | `../../rules/R3-storifying.md` |
| `gocognit` | `../../rules/R3-storifying.md` |
| `funlen` | `../../rules/R3-storifying.md` |
| `nestif` | `../../rules/R3-storifying.md` |
| `maintidx` | `../../rules/R3-storifying.md` + `../../rules/R1-primitive-obsession.md` |
| `dupl` | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated blocks that switch on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| `exhaustive` (missing enum cases) | `../../rules/R11-conditional-dispatch.md` — handle the case at the single dispatch site; a second switch appearing is the R11 violation itself |
| revive `file-length-limit`; package-size hook failures (`hooks/check-package-sizes.sh`) | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>` below |
| `gochecknoglobals` / `gochecknoinits` | `../../rules/R8-no-globals.md` |
| `ireturn` / interface lint on single-impl interfaces | `../../rules/R6-test-only-interfaces.md` |
| `go test -race` failures; `govet` `copylocks` | `../../rules/R10-concurrency-safety.md` |
| `wrapcheck`, `errcheck`, `goconst`, revive `early-return`, renames | Mechanical — fix directly (`fmt.Errorf("context: %w", err)`, handle the error, extract constant, invert & return early). Enum-shaped `goconst` strings → R1's "Name enum strings" move. |
