# Changelog

All notable changes to the `python-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

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
  the house rules P1–P7 (keyword-only booleans, defaults as names, no `utils.py`,
  consumer imports in tests, fixtures for infrastructure only, suppressions as
  findings, annotations as the contract), a self-review checklist and the
  mechanics; generated from `core/handbook/` and `lang/python/handbook/`.

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
