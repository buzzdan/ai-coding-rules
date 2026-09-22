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
     ty at each call site;
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
   typed `X` and no method guards it. ty makes the typed half of this question
   mechanical: `None` passed to an `X` parameter fails `invalid-argument-type`, so
   the finding survives only where the parameter is typed `X | None` or the code is
   not type-checked.
