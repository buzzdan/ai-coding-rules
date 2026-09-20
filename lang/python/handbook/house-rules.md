Rules marked *(opinionated)* are stances, not Python community norms; the departure
is deliberate.

### P1 — Booleans are keyword-only (opinionated)

A positional `True` at a call site says nothing. Every `bool` parameter sits after
`*`, so the call reads `fetch(url, follow_redirects=True)`. ruff `FBT001` and
`FBT003` enforce it where the repository enables them; elsewhere it is a review
finding. When the two branches share little, the flag wants to be two functions
(R11, Split Flag Argument).

**Review:** Is any `bool` parameter positional?

### P2 — A default is a name, never a mutable or a `None` to guard (opinionated)

Two halves. The community half: a mutable literal or a call in a signature is
evaluated once at definition time (ruff `B006`, `B008`; immutable calls such as
`tuple()` are exempt). The stance: an optional collaborator is a do-nothing object
bound once at module level, `def __init__(self, *, sink: Sink = NULL_SINK)`, never
`sink: Sink | None = None` substituted inside `__init__`. That idiom is allowed only
for a default that is genuinely mutable or expensive, and even then the attribute is
typed without `None` and no method guards it.

**Review:** Is any default a mutable literal or a call, or a `None` a method later guards?

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

### P5 — A fixture never hides the input a test is about (opinionated)

`tmp_path`, a fake HTTP server, an embedded database: those earn a fixture, and
`conftest.py` holds those. A small fixture that builds a literal is fine; a fixture
that returns the literal the test is *about* hides the one thing a reader needs to
see. Write that literal in the test.

**Review:** Does any fixture return the literal a test is about?

### P6 — Suppressions are review findings, not tools

`# noqa` and `# type: ignore` are the same thing. Neither is added on your own: fix
the code, and if it is a true false positive, propose a `[tool.ruff]` or
`[tool.mypy]` change and get it reviewed. A new suppression in a diff is itself a
finding, and no automated lint-fix pass edits either table.

**Review:** Did the diff add a `# noqa` or `# type: ignore`, or edit `[tool.ruff]` or `[tool.mypy]`?

### P7 — Annotations are the contract (opinionated)

Every public function is fully annotated, and mypy passes where the repository
configures it. An unexplained `Any` on a public signature is a suppression spelled
differently: narrow it, or name the `Protocol`. Annotations are what let `X | None`
be a declared absence instead of a hope.

**Review:** Does any public signature carry an unexplained `Any` or lack an annotation?

### P8 — Exceptions are caught narrowly and re-raised with their cause

`except Exception:` swallows the bug with the failure (ruff `BLE001`); catch the
class you can handle. Inside an `except`, raise with `from err` so the chain is kept
(ruff `B904`). Never log *and* re-raise the same error. Exception classes are
package vocabulary: defined once per package, named for what went wrong.

**Review:** Does any `except` catch `Exception`, re-raise without `from`, or both log and raise?
