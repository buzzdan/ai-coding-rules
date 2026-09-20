# Changelog

All notable changes to the `linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **The move "Replace Sentinel with comma-ok" is "Replace Sentinel with Declared
  Absence".** Move names are catalogue names shared by every language rendering,
  and comma-ok is a Go spelling; the Python handbook placed it beside the aside
  that forbids that very shape. The move's body is unchanged.
- **Two more Go spellings leave the shared text.** R11's map dispatch no longer
  reads "comma-ok on lookup" or shows a Go map literal, and R5's first falsifying
  question asks about a package *or module* named after a layer or role.
- **Three Principle sentences read the same standing alone.** R1 names raw
  strings, numbers, booleans and lists instead of Go's type spellings; R8 names
  the composition root instead of `main`; R9's Open Knowledge Format sentence
  moves from the Principle to the top of Design guidance, where the bundle policy
  it points at lives; R12 says collections instead of slices and maps, and the
  "Parse, don't validate" maxim describes a parse function instead of quoting a
  Go signature. The coding-rules handbook renders each rule's Principle without
  the language example beside it, which is where the Go spellings showed.

## [0.1.0] - 2026-09-17

### Added

- **The generic plugin.** The same core as `go-linter-driven-development` — twelve
  rules, the maxims, the design, TDD, refactoring, testing, review and documentation
  skills, the hunter/skeptic/critic review and the repo-brain gate — rendered for
  repositories without a language binding. The language is detected from the
  repository's marker file at run time; canonical examples show each rule's shape in
  language-neutral pseudocode; detection commands say what to search for over the
  detected language's source files.
- **Linter phase without a binding.** The workflow runs the linter the repository
  already configures and routes its findings by what they are about (complexity,
  length, nesting, duplication, unused, shadowing, unchecked errors); a finding it
  cannot classify is escalated by its message and attributed to its linter, never
  silenced. No linter configured is a 🟠 New Practice finding, and the review
  continues on the rules alone.
- **Repo-brain gate with a detected adapter.** `scripts/check-repo-brain.sh` picks
  its language block from the marker file: `go.mod` selects Go, `pyproject.toml`
  (or `setup.cfg`/`setup.py`) selects Python; with neither, the structure checks
  run and the first output line says the code↔docs edges are unverified. The
  fixture matrix runs once per supported language.
- Commands `/ldd-autopilot`, `/ldd-quickfix`, `/ldd-prepare`, `/ldd-analyze`,
  `/ldd-review`, `/ldd-status` and `/wire-repo-brain`.
- **The worked case files** under `examples/`, shared with the Go plugin. Their code
  is Go for demonstration only, and each says so at the top; the skeptic and the
  critic read them as their payload in this plugin exactly as in the Go one.

### Not included

- No test-harness catalogue and no hooks: those are Go-specific and ship with the Go
  plugin.
