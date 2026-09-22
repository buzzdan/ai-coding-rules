# Changelog

All notable changes to the `python-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **Hunters read the scope once.** The pre-commit-review skill writes a scope
  bundle before spawning — the file list, the diff and the full text of every file
  in scope, or one file per source directory on a whole-repository review — and each
  rule-hunter, the comment critic and the over-abstraction skeptic read it in their
  first turn, in one command. A per-file read is for confirming a lead the bundle
  cannot settle. Each of the three agents states a tool-call budget and what it
  returns when the budget is spent: receipts for what it covered and a
  `not reached:` line for what it did not, which the report carries beside the
  tally. (Token budget stage S1.)
- **Rules by reference.** The spawn prompt carries the rule file's absolute path
  and the pre-filter leads, not the rule's text; the hunter reads its rule in its
  first turn. The skeptic and the critic get the paths and section names of their
  doctrine the same way, from every skill that spawns them, and the parent never
  reads a rule file or a case file to build a spawn prompt. (Token budget stage
  S2.)
- **Two sentences name visibility without Go's word.** The comment critic's
  verdict and the code-comments checklist opened with "Unexported symbols", a
  literal the visibility scalar could not reach; both now say "symbols outside the
  public surface", so the Python and generic renderings stop borrowing the Go term.
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

- **The default lint command is `ruff check .`.** A bare `mypy` with no targets fails
  unless `[tool.mypy]` names files, and mypy runs only where that table exists; the
  pre-flight and the handbook's mechanics name it separately.

### Added

- **`coding-rules/python.md`, the Python coding-rules handbook.** The twelve
  rules with Python examples and the binding's positions as `In Python` asides,
  the shared house rules H1–H2 (suppressions, errors) with their Python spelling,
  the Python house rules P1–P5 (keyword-only booleans, defaults as names, consumer
  imports in tests, fixtures never hide the input, annotations as the contract), a
  self-review checklist and the mechanics; generated from `core/handbook/` and
  `lang/python/handbook/`.

## [0.2.0] - 2026-09-19

### Changed

- **The six case studies under `examples/` are Python.** The over-abstraction
  rejection is a frozen dataclass against a `CIDRPresence` wrapper; the storify case
  extracts an `IPConfig` dataclass from a flag-driven loop; the anti-if case dispatches
  through a `Protocol`, a `StrEnum`-keyed dict and a `match` closed by `assert_never`;
  the switch-to-polymorphism case moves `fill_update` onto the patch classes and
  records the closed set mypy checks; dependency rejection replaces `env.CONFIG` with
  constructor injection from an app factory; the comment-noise verdicts fall on
  `_private` docstrings. The doctrine of each case (verdicts, decision questions, the
  skeptic's operating rule) is shared with the Go plugin; the code and its narration
  are this plugin's own.

## [0.1.0] - 2026-09-19

### Added

- **The Python plugin.** The same core as `go-linter-driven-development` — twelve
  rules, the maxims, the design, TDD, refactoring, testing, review and documentation
  skills, the hunter/skeptic/critic review and the repo-brain gate — rendered with
  Python knowledge. Every canonical example is Python; every falsifying question
  says what to grep in `.py` files.
- **Seven positions where the rules meet Python idiom**, recorded in the main
  repository's `docs/language-residue.md`: `None` is a declared absence and never a
  disguised failure; an optional collaborator is a Null Object constant, never a
  `None` default a method guards; a self-validating type is a frozen dataclass with
  `__post_init__` or a `parse` classmethod; the docstring summary line is the
  contract and exempt from the restatement verdict; a kept switch is a `match` over
  an `Enum` closed by `assert_never`; `asyncio.sleep` is cancellable and
  `time.sleep` on a stoppable thread is the finding; module state is silent for
  loggers, constants and enums, silent in the entry point for configuration and
  wiring, and reported everywhere else.
- **Linter routing keyed by ruff codes and mypy.** `C901` and the `PLR` complexity
  family route to R3, `PLR0913` to R1, `PLW0603` to R8, `FBT` to R11, `B006`/`B008`
  to R12; the mechanical row names the `ARG`, `SIM`, `RET`, `B904` and `BLE001`
  families. Duplicate code, file length, exhaustiveness and shared-state races have
  no ruff rule and are review findings. `# noqa` and `# type: ignore` are both
  suppressions the lint-fixer never adds.
- **pytest testing skill.** `pytest.param(id=...)` rows, separate success and error
  functions, `tmp_path` and a fake HTTP server as real infrastructure, `conftest.py`
  for infrastructure fixtures only, `pytest --cov` for the coverage gate, `tests/`
  for system tests, and a short harness catalogue.
- **Docstring menus** for module, class and function in the Google convention, with
  a doctest as the runnable example.
- **Repo-brain gate with the Python adapter.** `scripts/check-repo-brain.sh` resolves
  backticked symbols against classes, functions, methods and module-level
  assignments, owned by their module and their package directory; `pyproject.toml`
  marks a sub-project.
- Commands `/py-ldd-autopilot`, `/py-ldd-quickfix`, `/py-ldd-prepare`,
  `/py-ldd-analyze`, `/py-ldd-review`, `/py-ldd-status` and `/wire-repo-brain`.
- **The worked case files** under `examples/`, shared with the Go plugin. Their code
  was Go for demonstration only, and each said so at the top; the skeptic and the
  critic read them as their payload in this plugin exactly as in the Go one.

### Not included

- No package-size hook: the Go plugin's hook counts Go files. The refactoring skill
  carries the same zones as a `find` over `.py` modules.
