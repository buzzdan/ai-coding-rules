# R2 — Self-Validating Types

## Principle

A type validates its own invariants in its constructor — the only way to obtain a
value — and every method thereafter trusts the receiver. Validation ownership never
sits upstream: a type that relies on callers to have validated for it is not
self-validating, whatever its fields look like.

## Why

Constructor validation makes invalid values unrepresentable. Without it, every method
must defend against bad state, forgetting one check is a latent crash, and the
defensive noise buries the actual logic. With it, None-checks, emptiness checks, and
range checks vanish from the entire downstream call graph — the payoff compounds with
every method and every caller. Errors also surface at the boundary where the bad data
entered, carrying context, instead of deep in an unrelated call stack.

## Canonical example

Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing):

```python
@dataclass(frozen=True, slots=True)
class Port:
    """A named, validated service port; it cannot exist out of range."""

    name: str
    number: int

    def __post_init__(self) -> None:
        if not 0 < self.number <= 65535:
            raise ValueError(f"port {self.name!r}: {self.number} out of range 1-65535")
```

This is the Python self-validating type: a frozen dataclass whose `__post_init__`
runs on every construction, literal or not. Its fields are public and read-only,
which is what "the constructor is the only entry" means here — there is no literal
that skips the check and no assignment after it. Before this type existed,
`0 < p.port <= 65535` was duplicated across two loops at the use site. After, there
is no `is_valid()` and no re-check anywhere: the concept of a maybe-invalid port is
deleted from downstream logic, not relocated. A plain mutable dataclass with the
same two fields and no `__post_init__` is the hole this rule hunts: every caller can
build an invalid `Port`, and every method must defend.

The same pattern for a composed object — validate dependencies once, then trust:

```python
# ❌ every method defends
class UserService:
    def __init__(self, repo: Repository | None) -> None:
        self.repo = repo  # public, might be None

    def create_user(self, user: User) -> None:
        if self.repo is None:  # repeated in every method; forget one → AttributeError
            raise RuntimeError("repo is None")
        self.repo.save(user)


# ✅ constructor validates once; methods trust the instance
class UserService:
    def __init__(self, repo: Repository) -> None:
        if repo is None:  # only an untyped caller can get here; mypy rejects it first
            raise TypeError("UserService: repo is required")
        self._repo = repo

    def create_user(self, user: User) -> None:
        self._repo.save(user)  # no checks — an invalid service cannot exist
```

Where the value is built from unstructured input — a config string, a wire dict —
the constructor is a `parse` classmethod that normalises and then constructs, so
`__post_init__` sees typed fields:

```python
    @classmethod
    def parse(cls, raw: str) -> "Port":
        name, _, number = raw.partition(":")
        return cls(name, int(number))
```

At a boundary that already uses pydantic, a `BaseModel` with `frozen=True` and field
validators is the same type; inside the domain the dataclass is enough, and
`model_construct()` anywhere outside a test is a path around the constructor.

## Design guidance

- **Constructors are the only entry.** `ParseX(raw)` for values built from
  unstructured input, `NewX(deps)` for composed objects, each returning the value or an
  error (constructors may carry other names — any public function returning the type
  qualifies). Fields stay underscore-prefixed: building the value directly, bypassing the
  constructor, is a hole in the type.

- **Validation ownership.** A type never relies on upstream validation. "The handler
  already checked it" is not an invariant — handlers change, new call sites appear,
  and the type outlives both. A comment reading "caller must ensure X" is the
  signature of a type that does not own itself: move that sentence into the
  constructor as code.

  ```python
  # ❌ relies on callers to validate
  @dataclass
  class Config:
      host: str      # every caller must remember: if not host ...
      port: int


  # ✅ owns its own validation
  @dataclass(frozen=True)
  class Config:
      host: str
      port: int

      def __post_init__(self) -> None:
          if not self.host:
              raise ValueError("host required")
          if not 0 < self.port <= 65535:
              raise ValueError("invalid port")
  ```

- **Trust composed values.** Once you hold a `Port`, it is valid — never re-check it
  downstream, and never re-validate it in a composing constructor. Each type owns
  exactly its own invariants:

  ```python
  # ❌ re-validates what Host already guarantees
  @dataclass(frozen=True)
  class Address:
      host: Host
      port: Port

      def __post_init__(self) -> None:
          if not self.host.name:          # Host owns this
              raise ValueError("host required")


  # ✅ trusts composed self-validating types — nothing left to check, no __post_init__
  @dataclass(frozen=True)
  class Address:
      host: Host
      port: Port
  ```

- **None is not a value.** Never return None where a real value is expected —
  return an error instead. A failure result carries the error, not a value, so that
  position is exempt. Never pass None into a function; then functions do not
  check parameters for None.

- **Absence is a value too.** An *optional* collaborator — a logger, a metrics sink,
  an event writer, a clock — is not a field that may be None with a guard in every
  method. The default is a named do-nothing value the constructor supplies, the field
  is never None, and every "if the sink is set" guard disappears. This is the Null
  Object of `R11-conditional-dispatch.md`: a real implementation that honors the
  contract by doing nothing, so no caller ever branches on a missing destination. No
  parameter accepts None to mean "default": substituting the default inside the
  constructor keeps passing None legal and merely moves the check — the default
  lives in an option or the caller passes the Null Object by name. Only a *required*
  collaborator (a store, a client the type cannot work without) is rejected in the
  constructor — doing nothing silently there would hide a bug. Promoting an optional
  collaborator to a required positional parameter with a comment saying "pass the
  do-nothing value instead of None" changes nothing: the parameter still accepts
  None, the constructor neither defaults nor rejects it, and the first use crashes.
  A collaborator with a sensible do-nothing default is optional; it stays an option
  with the default in the constructor. An option handed None must not become a
  value that works: it records the failure on the value under construction, and the
  constructor fails with a message naming the option; the field never holds None;
  no method ever asks.

  **The Python shape.** A do-nothing object is stateless, so it can be a real default
  value: `NULL_SINK = NullSink()` at module level (a name, not a call — ruff's `B008`
  flags a call in a default), the parameter keyword-only and typed `Sink`, never
  `Sink | None`. mypy then rejects `Reporter(sink=None)` before it runs, and the
  constructor rejects it at run time for callers mypy never saw. `sink: Sink | None =
  None` with `self._sink = sink or NullSink()` inside the constructor keeps `None`
  legal and merely moves the check; it is allowed only when the default is genuinely
  mutable or expensive to build, and even then the attribute is typed without `None`
  and no method guards it.

  ```python
  # ❌ optional sink kept None-able; every method re-asks the question
  class Reporter:
      def __init__(self, sink: Sink | None = None) -> None:
          self.sink = sink

      def record(self, ev: Event) -> None:
          if self.sink is not None:
              self.sink.write(ev)


  # ✅ absence is a named value; no argument is ever None
  NULL_SINK = NullSink()          # a real Sink whose write() discards
  SYSTEM_CLOCK = SystemClock()


  class Reporter:
      def __init__(self, *, sink: Sink = NULL_SINK, clock: Clock = SYSTEM_CLOCK) -> None:
          if sink is None or clock is None:      # reachable only from untyped callers
              raise TypeError("Reporter: pass NULL_SINK or SYSTEM_CLOCK, never None")
          self._sink = sink
          self._clock = clock

      def record(self, ev: Event) -> None:
          self._sink.write(ev)                   # no guard anywhere
  # production: Reporter(sink=FileSink(path)); tests: Reporter(clock=FixedClock(t0))
  ```

- **No defensive coding.** Check arguments in the constructor so that methods contain
  zero None/emptiness checks on their own fields. A method validating its receiver is
  validation in the wrong place.

## Fix pattern

- **Add validating constructor**: make fields underscore-prefixed, add `NewX`/`ParseX`
  returning the value or an error, migrate every literal-construction site through it.
- **Hoist method checks into the constructor**: collect the field checks scattered
  across methods, run them once at construction, delete them from the methods. For a
  *required* collaborator the hoisted check rejects None; for an *optional* one it is
  the wrong move — use the next one.
- **Introduce Null Object** (`R11-conditional-dispatch.md`): an optional collaborator
  gets a *named* do-nothing value that the constructor supplies through an option or
  the caller passes explicitly; the field is never None by construction, an option
  handed None records the error for the constructor to return instead of
  substituting the default, and every guard in the methods is deleted. When the
  collaborator wraps a standard writer or clock, compose the standard no-op into it;
  do not introduce an interface for the sake of the no-op
  (`R6-test-only-interfaces.md`).
- **Delete re-validation of composed types**: if every parameter is itself
  self-validating and there is nothing left to check, the constructor no longer needs
  to fail.
- **Separate Failure from Absence**: an error for failure, an explicit absence result
  for a missing value — never None standing in for either; see the sentinel move in
  `R1-primitive-obsession.md`.
- Forward design of new types: @code-designing. The primitive extraction that usually
  precedes this rule: `R1-primitive-obsession.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Can the type exist in an invalid state?**
   Detection: for each new/changed type with invariants, read its declaration: a
   `@dataclass` without `frozen=True` and without a `__post_init__`, a plain class
   whose `__init__` assigns without checking, or a pydantic model with no validator
   for the field that carries the rule. Then
   `grep -rn '<Type>(' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` for
   construction sites and `grep -rn '\.model_construct(' --include='*.py' .` for the
   pydantic bypass. Literal construction is not the hole here: `__post_init__` runs
   on every `Port(...)`, so a frozen dataclass with one is closed. The hole is the
   dataclass that has no check to run, and the public field that can be assigned
   after construction.
   Violation: a mutable dataclass or plain class carrying an invariant it never
   checks, an assignable invariant-bearing field on a validated type, or a
   `model_construct` outside a test — each gives callers a path around the
   constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detection: `grep -nE 'if self\.[a-zA-Z_]+ is (not )?None|if not self\.[a-zA-Z_]+:|if len\(self\.[a-zA-Z_]+\) == 0' <changed files>`
   inside method bodies (not `__init__` or `__post_init__`).
   Violation: a method validating its own instance's fields — the check belongs in
   the constructor. Decide which fix by asking whether the field is required or
   optional: a required collaborator is rejected in `__init__` (Hoist method
   checks); an optional one (logger, sink, clock, metrics) gets a Null Object
   default there instead (Introduce Null Object, R11) — name both moves in the
   finding when the code does not say which the field is. An attribute typed
   `X | None` on the instance is the evidence that the question is asked in every
   method, whether or not each method spells the guard.

3. **Does a constructor re-validate a composed self-validating type?**
   Detection: read each `__post_init__`, `__init__` and `parse` classmethod in the
   diff; for every parameter whose type has its own `__post_init__` or validator,
   grep the body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detection: `grep -rniE 'caller must|assumes valid|already validated|defensive|re-?check' --include='*.py' .`;
   also flag public fields consumed by logic in a module that defines no
   `__post_init__`, `parse` or validator for the type, and a `NewType` standing in
   for a validated value (it is erased at run time and admits every literal).
   Violation: any invariant enforced — or merely documented — outside the type
   itself; a value re-validated after the point that validated it (a "defensive
   re-check") is the same finding, the invariant living in two places and in neither
   type.

5. **Does anything return or accept `None` as a value?**
   Detection: `grep -nE 'return None\s*(#.*)?$|^\s+return$' <changed files>` (a bare
   `return` in a function that returns a value counts), then read each hit's
   signature and the branch it sits in. Three verdicts:
   - the signature says `-> X` and the body returns `None`: R1 Q4's sentinel, cite
     it there;
   - the signature says `-> X | None` and the `None` branch is a normal absence a
     caller expects — a lookup by key, the first match of a filter, a blank line in
     a parser — and every caller narrows it: not a finding. `dict.get` versus
     `dict[k]` is the model; `X | None` is Python's declared absence, checked by
     mypy at each call site;
   - the signature says `-> X | None` and the `None` branch is a failure —
     malformed input, a broken invariant, an `except ...: return None` that turns an
     I/O error into "not found" — or callers stack `is None` guards because the
     absence should have been an exception: Separate Failure from Absence; `raise`
     where the failure `return None` was, and keep `X | None` only for the branch
     that is truly absence.
   Exempt: `-> None` procedures, and the `None` result of a well-typed `.get`.
   `tuple[X, bool]` is never the fix: it is the Go idiom with a Python spelling.
   Violation: `None` returned where the signature promises a value; `None` standing
   in for a failure; or a function `None`-checking a parameter instead of the value
   being guaranteed by construction and by its annotation.

6. **Does any call site pass `None` as a non-error argument?**
   Detection: `grep -nE '\(None[,)]|, None[,)]|=None[,)]' <changed files>` — exempt
   comparisons (`is None`, `is not None`), and standard-library idioms where `None`
   is the documented "no value" (`dict.get(k, None)`, `logging.getLogger(None)`,
   `subprocess.run(..., input=None)`).
   Violation: `None` passed where a value is expected. Q5 catches the return side
   and Q2 catches the callee that defends; this catches the caller when the callee
   does neither and raises `AttributeError` later. Fix on the callee's side: make
   `None` unrepresentable — a parameter typed `X`, never `X | None`; a constructor
   that raises `TypeError` on `None` (see the UserService example above); or, for
   an optional collaborator, a Null Object default so the caller never has a reason
   to pass `None` (`Reporter(sink, None, None)` is the smell; R11). `param: X | None
   = None` with the substitution inside `__init__` is allowed only for a default
   that is genuinely mutable or expensive to build, and even then the attribute is
   typed `X` and no method guards it. mypy makes the typed half of this question
   mechanical: `None` passed to an `X` parameter fails `arg-type`, so the finding
   survives only where the parameter is typed `X | None` or the code is not
   type-checked.
