# Python Linter-Driven Development

**The same engineering rules as the Go plugin, written the way a Python developer
would write them.**

This Claude Code plugin is built from the same core as
[`go-linter-driven-development`](../go-linter-driven-development/README.md): twelve
design rules stated once as data, thin skills that sequence design, TDD, refactoring,
testing, review and documentation, and an evidence-based review run by fresh-context
agents. What differs is the language-shaped part: every canonical example is Python,
every detection command greps `.py` files, the linter routing is keyed by ruff codes
and ty, and the testing skill speaks pytest.

Install it for a Python repository. A repository in a language without a binding
takes [`linter-driven-development`](../linter-driven-development/README.md), which
detects the language at run time; a Go repository takes the Go plugin.

## What the plugin knows about Python

The rules are language-neutral. Where a Go idiom in a rule has no Python twin, this
plugin takes a position, and the review hunts for the Python disease rather than the
Go one:

- **`None` is a declared absence, never a disguised failure.** A `-> X | None`
  return is fine when absence is normal and every caller narrows it — `dict.get`
  against `dict[k]` is the model. The findings are `None` returned where the
  signature promises `X`, `None` standing in for a failure (raise instead), and
  callers stacking `is None` guards because the absence should have been an
  exception. `tuple[X, bool]` is never the fix.
- **An optional collaborator is a Null Object constant.** `NULL_SINK = NullSink()`
  at module level, the parameter keyword-only and typed `Sink`; `None` is rejected
  with `TypeError`. A `sink: Sink | None = None` default replaced inside `__init__`
  is allowed only for a genuinely mutable or expensive default, and even then no
  method guards the attribute.
- **A self-validating type is a frozen dataclass with `__post_init__`**, or a
  `parse` classmethod that normalises and constructs. Public read-only fields are
  fine: `__post_init__` runs on every literal, so there is no path around it. The
  finding is a mutable dataclass carrying invariants with no `__post_init__`.
  Pydantic is the boundary form where the repository already uses it;
  `model_construct` and `model_copy(update=)` are the bypasses the hunter looks
  for; the plugin never proposes adding pydantic. `NewType` scores zero on the
  invariant line.
- **The docstring summary line is the contract**, exempt from the comment critic's
  restatement verdict when it states that contract; the WHY budget applies to the
  body; `Args:`, `Returns:` and `Raises:` sections are free. Where the repository's
  ruff `D` rules require a docstring, a WHAT-docstring is rewritten, never deleted;
  on a `_private` name it is deleted.
- **The kept switch is a `match` over an `Enum` closed by `case _: assert_never(x)`.**
  That arm is the completeness proof ty checks, not an unknown-kind default; a
  `case _:` that raises or logs is the finding. A dictionary of callables comes
  first, a `Protocol` hierarchy second, `functools.singledispatch` third. A
  positional boolean parameter is always a finding (ruff `FBT001`) and the
  lint-fixer makes it keyword-only; a keyword-only boolean stays while the branches
  share their body.
- **`asyncio.sleep` is cancellable by construction.** `time.sleep` on a thread that
  has a stop condition is the finding, fixed with `Event.wait(timeout)`. The object
  that starts a thread exposes `close()` that sets the event and joins; a daemon
  thread is acceptable only in entry-point wiring for work that owns no resource.
  asyncio tasks live in a `TaskGroup` or under a kept handle. There are no atomics
  and no race detector: a `Lock` beside the fields it guards, taken with `with`, or
  confinement to one thread.
- **Module state has three lists.** Silent everywhere: `logging.getLogger(__name__)`,
  constants, enums, frozen instances as constants, exception classes, typing
  machinery. Silent only in the entry point: `Config.from_environ()`,
  `logging.basicConfig`, the framework `app`, a hand-filled registry, `asyncio.run`.
  Reported everywhere else: `os.environ` reads and imported `CONFIG` objects,
  module-level containers functions write into, side effects in a module body, a
  lazily built instance behind a getter, `asyncio.run` or `get_event_loop` in
  library code. A test that monkeypatches production configuration is evidence
  against the production code.

## Opinionated

Some of what the plugin enforces is a stance, not a Python community norm. It holds
them because the rules hold them in every language:

- **No `utils.py`, no `common.py`.** A module is named for the domain vocabulary it
  holds, never for its role (R4, R5).
- **No testing of `_private` functions.** The urge is a placement signal: the helper
  wants its own module or package, where its public API is testable (R4, R7).
- **No `mock.patch` of internal collaborators.** A patch on a class you own is a
  seam that exists only so a test can substitute a double — the same smell as a
  single-implementer `Protocol`. Patching the true external boundary — the clock, a
  socket, the process environment in an entry-point test — is fine (R6).
- **No mutable module state** outside the entry point, and no `global` (R8).
- **Small pytest fixtures that build a literal are fine; a fixture that hides the
  input is not.** A fixture earns its place for real infrastructure — `tmp_path`, a
  fake server, a database — and `conftest.py` holds only those (R7).

## The linter phase

The plugin runs the checkers the repository already configures — `ruff check`,
`ruff format`, and `ty check` where a `[tool.ty]` table exists — through the task the
repository defines. It never adds a checker the repository does not use.

- **Findings route by ruff code.** `C901` and the `PLR` complexity family go to R3,
  `PLR0913` to R1, `PLW0603` to R8, `FBT` to R11, `B006`/`B008` to R12. The
  mechanical row — `ARG`, `SIM`, `RET`, `B904`, `BLE001`, `PLR2004`, import order,
  style — is fixed by the lint-fixer in an isolated context.
- **Some findings have no ruff rule.** Duplicated code, file length, a `match`
  missing enum cases, a `Protocol` with one implementer and shared-state races are
  review findings: the hunters own them alone.
- **`# noqa` and `# ty: ignore` are both suppressions.** The lint-fixer never adds
  either and never edits `[tool.ruff]` or `[tool.ty]`; a new one in a diff is
  itself a review finding.

## Architecture: Rules as Data

```
python-linter-driven-development/
├── maxims.md     the uncompiled layer — named design questions above the rules
├── rules/        R1-primitive-obsession … R12-mutation-discipline   (single source of truth)
├── skills/       linter-driven-development · code-designing · refactoring ·
│                 pre-commit-review · testing · documentation   (thin directional views)
├── agents/       rule-hunter · overabstraction-skeptic · comment-critic · lint-fixer
├── commands/     py-ldd-analyze · autopilot · quickfix · prepare · review · status · wire-repo-brain
├── examples/     storify-leaf-type · overabstraction-cidr · dependency-rejection ·
│                 anti-if-dispatch · switch-to-polymorphism · private-comment-noise   (case law, in Python)
└── scripts/      check-repo-brain.sh — repo-brain conformance gate with the Python adapter
```

- **[`rules/`](rules/)** — R1–R12, each a self-contained hunter rulebook: Principle,
  Why, a canonical before/after in Python, Design guidance, a Fix pattern, and
  Falsifying questions with grep commands over `.py` files.
- **[`skills/`](skills/)** — thin directional views that sequence and route into the
  rules. They never restate rule content. The testing skill's
  [reference](skills/testing/reference.md) is a short pytest harness catalogue.
- **[`agents/`](agents/)** — read-only or mechanical workers spawned in isolated
  contexts, pointed by path at the relevant rule file — and, for hunters and the
  critic, at the scope bundle — which they read in their first turn.
- **[`scripts/check-repo-brain.sh`](scripts/check-repo-brain.sh)** — the repo-brain
  gate. Its Python adapter resolves backticked symbols against classes, functions,
  methods and module-level assignments, and treats a `pyproject.toml` directory as a
  sub-project with its own doc root.
- **[`examples/`](examples/)** — the worked case studies the rules cite, in Python:
  the frozen dataclass that beat a wrapper, the `IPConfig` leaf a flag-driven loop
  became, the alert channels dispatched through a `Protocol` and a `match` closed by
  `assert_never`, the export patches that fill their own request, `env.CONFIG`
  pushed up to the app factory, and the nine `_private` docstrings judged one by
  one. The verdicts and decision questions are the same as the Go plugin's; the code
  is this plugin's.

## The Five-Phase Flow

The [`@linter-driven-development`](skills/linter-driven-development/SKILL.md) skill
is the meta-orchestrator:

```
1 DESIGN     @code-designing → DESIGN PLAN → user OK
1.5 PREPARE  preparatory refactoring: survey the plan's touch points,
      four autonomous gates decide, @refactoring reshapes → prep commit(s)
2 IMPLEMENT  per behavior: RED (one failing pytest, lowest rung) → GREEN → REFACTOR
3 FULL LINT  ONE run of ruff and ty via the lint-fixer agent (isolated context)
      mechanical → FIXED · design → ESCALATED → @refactoring
4 REVIEW     per completed slice: @pre-commit-review spawns hunters + skeptic + critic
5 SHIP       @documentation → commit (tests and lint green, tree dirty) → ship summary
```

## Slash Commands

| Command | Purpose | Auto-Fix |
|---------|---------|----------|
| `/py-ldd-autopilot` | Full workflow (Phases 1–5) | ✅ Yes |
| `/py-ldd-quickfix [files \| --all]` | Quality-gates loop until green over the files you are working on | ✅ Yes |
| `/py-ldd-prepare <change> [files]` | Preparatory refactoring ahead of a planned change | ✅ Yes |
| `/py-ldd-analyze [files \| --all]` | Tests + lint + review, combined report | ❌ No |
| `/py-ldd-review [files \| --all]` | Commit-readiness check | ❌ No |
| `/py-ldd-status` | Show current phase + progress | N/A |
| `/wire-repo-brain [path]` | Wire the documentation network in one pass | ✅ Wiring only |

`/wire-repo-brain` carries no prefix: the documentation network it wires is a
property of the repository, not of a language, and the Go plugin offers the same
command. Installed side by side, both do the same structural work.

## Installation

```
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install python-linter-driven-development@ai-coding-rules
```

Verify with `/plugin list`; it should show `python-linter-driven-development (enabled)`.

## How Auto-Detection Works

When you request code work ("implement feature X", "fix the bug in the handler") in
a Python project, Claude detects that the skill applies and asks for permission.
Select "don't ask again for this skill in this directory" on first use.

**Triggers auto-detection:** action verbs (`implement`, `fix`, `build`, `add`,
`refactor`, `update`, `change`, `modify`) in a Python project, a mention of "ldd" or
"@ldd", or a `/py-ldd-*` command.

## Updating and uninstalling

```
/plugin update python-linter-driven-development@ai-coding-rules
```

See [CHANGELOG.md](CHANGELOG.md) for what changed between versions. To uninstall,
run `/plugin`, select "python-linter-driven-development" and choose "Uninstall".

## Need Help or Want to Contribute?

Full details, the generator that renders this plugin from its core, and the Go and
generic plugins it shares that core with: the
[main repository](https://github.com/buzzdan/ai-coding-rules). Found a bug or have
an idea? [Open an issue](https://github.com/buzzdan/ai-coding-rules/issues).

## License

MIT
