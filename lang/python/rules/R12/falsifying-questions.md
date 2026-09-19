1. **Does a method return an internal list, dict or set by reference?**
   Detection: for each type in the diff with a validating constructor, list its
   collection attributes (`grep -nE '^\s+(self\.)?_?[a-z_]+: (list|dict|set)\[' <file>`), then
   `grep -nE 'return self\._?(<field1>|<field2>)$' <file>` — a bare
   `return self._items` with no `tuple(...)`, `list(...)`, `dict(...)`, `.copy()`,
   `MappingProxyType` or iterator around it; a `@property` that returns the
   attribute is the same hit with a nicer name.
   Violation: an internal reference escapes a validated type — Copy on the Way Out
   (`tuple(self._items)`, `types.MappingProxyType(self._by_id)`, `frozenset(...)`).

2. **Does a constructor store a caller-provided list or dict without copying?**
   Detection: inside each `__init__`, `__post_init__` and `parse` classmethod in the
   diff, check for a collection attribute assigned directly from a parameter
   (`self._items = items`; a dataclass field typed `list[...]` with no
   `object.__setattr__(self, "items", tuple(self.items))` in `__post_init__`).
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In (`tuple(items)`, `dict(by_id)`; a frozen dataclass field typed
   `tuple[...]` makes the copy part of the type's contract). (A collection built
   inside the constructor, like `_dedupe_and_validate`'s result, is fine — no one
   else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a return annotation other than `-> None`,
   grep its body for assignments to `self.` attributes (`self\.[a-z_]+ =`,
   `self\.[a-z_]+\.(append|extend|pop|update|remove|clear)\(`).
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier. (If every caller
   genuinely needs both halves atomically — a lock-guarded pop-and-report — it is
   one operation; name it as a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: `grep -rnE '@[a-z_]+\.setter|def set_[a-z_]+\(self' --include='*.py' .`
   for setters, and for each `@dataclass` with a `__post_init__` check whether it is
   `frozen=True`; for each hit, does the type validate in its constructor, and does
   the setter re-check?
   Violation: a setter, or an unfrozen dataclass, that assigns unchecked on a
   constructor-validated type — Remove Setting Method (and `frozen=True`, so
   `p.number = 0` raises `FrozenInstanceError`). (Public mutable fields with no
   constructor check at all are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every reassignment (`x = ...` after
   `x` was first bound, including a loop variable reused after its loop), ask
   whether the right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new `list(...)`, `dict(...)`, `.copy()`, `copy.deepcopy` or
   manual copy loop in the diff, trace the copied value: does the source or the copy
   ever cross a function boundary or outlive the call?
   Violation: cloning data that provably never escapes, or copying per-iteration in
   a loop the profile cares about — ceremony; delete the copy and note why sharing
   is safe. A mutable default argument (`def f(items: list[str] = [])`, ruff
   `B006`) is the opposite failure — one list shared by every call; the fix is an
   immutable empty default (`items: Sequence[str] = ()`), or a `None` default
   replaced inside the function when the collection must be mutable (R2's one
   allowed `None`).
