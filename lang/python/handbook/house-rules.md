Some of these are a stance, not a Python community norm, and are marked
**opinionated**: the departure is deliberate, held because the rules above hold it
in every language.

### P1 — Booleans are keyword-only

A positional `True` at a call site says nothing. Every `bool` parameter sits after
`*`, so the call reads `fetch(url, follow_redirects=True)`. ruff `FBT001` and
`FBT003` enforce it; when the two branches share little, the flag wants to be two
functions (R11, Split Flag Argument).

**Review:** Is any `bool` parameter positional?

### P2 — A default is a name, never a call

`def __init__(self, *, sink: Sink = NULL_SINK)`, where `NULL_SINK = NullSink()` is
bound once at module level. `sink: Sink = NullSink()` in the signature is ruff
`B008`; `events: list[Event] = []` is `B006`. A `param: X | None = None` with
substitution inside `__init__` is allowed only for a default that is genuinely
mutable or expensive, and even then the attribute is typed without `None` and no
method guards it.

**Review:** Is any default a call or a mutable literal, or a `None` a method later guards?

### P3 — No `utils.py`, no `common.py`, no `helpers.py` (opinionated)

A module is named for the vocabulary it holds, never for its role. The moment a
function lands in `utils.py` it has no owner, and the next one lands beside it
because it did. Find the noun; make the module.

**Review:** Did a module named for its role appear?

### P4 — Tests import the package as a consumer (opinionated)

`from app import user`, never `from app.user._parse import _parse_row`. Python lets
you reach a `_private` name; the rule is that you do not. The urge is a placement
signal (R4).

**Review:** Does any test import a `_private` name?

### P5 — A fixture builds infrastructure, not the input under test (opinionated)

`tmp_path`, a fake HTTP server, an embedded database: those earn a fixture, and
`conftest.py` holds only those. A fixture that returns the literal the test is about
hides the one thing a reader needs to see. Write the literal in the test.

**Review:** Does any fixture return the literal a test is about?

### P6 — Suppressions are review findings, not tools

`# noqa` and `# type: ignore` are the same thing. Neither is added on your own: fix
the code, and if it is a true false positive, propose a `[tool.ruff]` or
`[tool.mypy]` change and get it reviewed. A new suppression in a diff is itself a
finding, and the linter phase never edits either table.

**Review:** Did the diff add a `# noqa` or `# type: ignore`, or edit `[tool.ruff]` or `[tool.mypy]`?

### P7 — Type hints are the contract, mypy is the compiler

Every public function is fully annotated and mypy passes where the repository
configures it. `Any` on a public signature is a `# type: ignore` spelled
differently: narrow it or name the protocol. Annotations are what let `X | None` be
a declared absence instead of a hope.

**Review:** Does any public signature carry `Any` or lack an annotation?
