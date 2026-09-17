- Linter failures that need a design decision, not a mechanical fix (the names are the
  families most linters report under some name; match the repository's linter by what
  its message says):
  - too many parameters → design an options type (grouping data that travels together — score it per `../../rules/R1-primitive-obsession.md`)
  - too many return values → design a named result type (same R1 scoring)
  - file too long → split juicy types into their own files (juiciness per R1; file-per-type per `../../rules/R5-vertical-slice.md`); a single god type routes to @refactoring's god-object decomposition procedure first
  - a directory in the package-size yellow/red zone → re-model with sub-packages *before* the zone escalates (@refactoring `<package_decomposition>`)