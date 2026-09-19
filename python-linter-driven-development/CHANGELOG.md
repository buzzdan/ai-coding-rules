# Changelog

All notable changes to the `python-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
  is Go for demonstration only, and each says so at the top; the skeptic and the
  critic read them as their payload in this plugin exactly as in the Go one.

### Not included

- No package-size hook: the Go plugin's hook counts Go files. The refactoring skill
  carries the same zones as a `find` over `.py` modules.
