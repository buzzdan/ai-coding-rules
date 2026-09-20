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

### P3 — Tests import the package as a consumer (opinionated)

`from app import user`, never `from app.user._parse import _parse_row`. Python lets
you reach a `_private` name; the rule is that you do not. The urge is a placement
signal (R4).

**Review:** Does any test import a `_private` name?

### P4 — A fixture never hides the input a test is about (opinionated)

`tmp_path`, a fake HTTP server, an embedded database: those earn a fixture, and
`conftest.py` holds those. A small fixture that builds a literal is fine; a fixture
that returns the literal the test is *about* hides the one thing a reader needs to
see. Write that literal in the test.

**Review:** Does any fixture return the literal a test is about?

### P5 — Annotations are the contract (opinionated)

Every public function is fully annotated, and mypy passes where the repository
configures it. An unexplained `Any` on a public signature is a suppression spelled
differently: narrow it, or name the `Protocol`. Annotations are what let `X | None`
be a declared absence instead of a hope.

**Review:** Does any public signature carry an unexplained `Any` or lack an annotation?
