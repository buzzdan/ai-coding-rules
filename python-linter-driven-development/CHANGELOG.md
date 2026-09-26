# Changelog

All notable changes to the `python-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **Two report promises are back inline.** The S1–S4 proof run rendered no cluster
  entry on Case A twice and wrote the skeptic's alternative where the Fix-pattern move
  name belongs on Case B twice; both rules had shrunk to one line in the review
  skill's step 4 when their long form moved to `reference.md`. The step now carries the
  cluster-pass example and the fix-cell rule (move name first, verdict after, the
  alternative never in its place) itself, plus two rules the graders showed were
  load-bearing: a cluster's title line carries the ids of the rules that converged on
  it, and a finding line is never wrapped for width. The same run showed the
  pre-filter, now reading only each rule's falsifying questions, skips R2 on a
  "defensive re-check" that the baseline's parent found by reading the whole rule;
  R2's question 4 now names `defensive` and `re-check` in its detection.
- **The Agent tool has one use in the workflow.** The linter-driven-development
  skill, the quickfix command and the refactoring skill state that refactoring runs in
  the main thread and is never delegated to a general-purpose or any other subagent,
  however many escalations there are. The lint-fixer has a budget of six lint runs and
  forty edits per spawn, twelve turns; what it did not reach returns as `ESCALATED: …
  → mechanical, budget spent` lines, and the caller spawns a fresh lint-fixer over those
  packages, at most three times and never after one reports nothing fixed; a `no
  progress` leftover is never respawned. (Token budget stage S3.)
- **Two skills on a diet.** The pre-commit-review and refactoring skills keep their
  protocols and contracts and move the long form — hunt-focus table, agent output shapes,
  verdict rules, cluster pass and report example; pattern index, file and package
  routing, preparatory mode, stopping criteria in full,
  multi-rule procedures — into their `reference.md`, each step naming the `sed` range
  it reads when it needs it. `<file_and_package_routing>` and `<package_decomposition>`
  now live in the refactoring skill's `reference.md`; the skills that cite them say so. A range is printed inside a Bash call the step already makes, never as a call
  of its own; the bundle recipe and the suppression scan stay inline.
  (Token budget stage S4.)
- **Hunters read the scope once.** The pre-commit-review skill writes a scope
  bundle before spawning — the file list, the diff on a scoped review, and one
  numbered file per source file, with deleted, binary, generated and very long files
  listed but not bundled — and each rule-hunter and the comment critic read their
  rule and the bundled files their leads name in their first turn, in one command,
  under a stated ceiling. On `--all` each hunter gets its own reading order over the
  directories, its rule's pre-filter hits first. The hunter and the critic have a
  budget of the first turn plus four calls, six on a whole-repository review, the
  skeptic one call per finding, and each states what it returns when the budget is
  spent: receipts for the detection commands, which ran over the whole scope in one
  call, and a `not reached:` line for what was not read to judge, which the report
  header renders beside the tally with a `PARTIAL coverage` marker. The skeptic gets
  no bundle. (Token budget stage S1.)
- **Rules by reference.** The spawn prompt carries the rule file's absolute path
  and the pre-filter leads, not the rule's text; the hunter reads its rule in its
  first turn. The skeptic and the critic get their doctrine the same way, as paths
  with the `sed` range of the section to read, from every skill that spawns them; the
  parent never reads a rule or case file to build a spawn prompt, lists the resolved
  paths before spawning, and an agent whose rule or doctrine does not read returns
  that instead of hunting from memory. (Token budget stage S2.)
- **The type checker is `ty` first, with mypy still known.** Astral's `ty` is
  named first everywhere the binding names a type checker — `ty check`,
  `[tool.ty]`/`ty.toml`, `# ty: ignore[<rule>]`, and the routing tables'
  `invalid-argument-type`/`invalid-assignment`/`invalid-return-type` — and mypy
  stays beside it: `mypy` where a `[tool.mypy]` table or `mypy.ini` exists, the
  routing rows carry mypy's `arg-type`/`assignment`/`return-value` too, and every
  suppression sentence names `# noqa`, `# ty: ignore` and `# type: ignore` alike
  (ty honors a bare `# type: ignore`, so dropping it would have opened a hole).
  Each checker runs only where the repository configures it.
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
  unless `[tool.mypy]` names files, and each type checker runs only where its table
  exists; the pre-flight and the handbook's mechanics name them separately.

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
