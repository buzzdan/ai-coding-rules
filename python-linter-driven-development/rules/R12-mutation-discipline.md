# R12 — Mutation Discipline (Encapsulated State)

## Principle

A validated value changes state only through methods that own its invariants — never
through leaked internals. Constructors copy the collections they are given;
queries return copies (or iterators), not the internal reference; a method is a query
or a modifier, not both; and a type with a validating constructor exposes no setter
that skips the validation. This rule adapts Fowler's *Mutable Data* smell family
(Refactoring, 2nd ed.: Encapsulate Collection, Separate Query from Modifier, Remove
Setting Method, Split Variable) to languages where collections are passed by
reference into shared backing storage.

## Why

R2's payoff — validate once, trust the value everywhere after — is void the moment an
internal slice escapes. Returning an internal collection does not return the
permissions; it returns a mutable alias into them. The caller can sort, truncate, or overwrite the
"validated" state without calling a single method, so no grep for setters and no
review of the type's own file will ever find the write that broke the invariant. The
same aliasing runs backward: a constructor that stores a caller's slice without
copying has handed its state to code it has never met. Setters reopen the constructor
from the side, mixed query/modifiers make every call site a potential hidden write,
and a variable reused for two meanings makes both untraceable. Mutation is not the
defect — *unowned* mutation is: every state change must pass through code that knows
the invariants.

## Canonical example

`Grants` guarantees a non-empty, deduplicated permission set — enforced in the
constructor per R2.

### Before

```python
class Grants:
    def __init__(self, raw: Iterable[str]) -> None:
        self._perms: list[Permission] = dedupe_and_validate(raw)   # non-empty, deduplicated

    def all(self) -> list[Permission]:      # ❌ returns a mutable alias into the validated state
        return self._perms
```

```python
# ❌ a distant caller, months later
perms = user.grants.all()
perms.sort(key=lambda p: p.weight)          # reorders internal state
perms[0] = Permission.NONE                  # corrupts it — no method called
```

The constructor's guarantee is now a lie, and nothing in `grants.py` changed. The
write that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```python
# ❌ constructor stores the caller's list
class Schedule:
    def __init__(self, days: list[Weekday]) -> None:
        if not days:
            raise ValueError("schedule: no days")
        self._days = days


days = [Weekday.MONDAY]
s = Schedule(days)
days[0] = Weekday.SUNDAY    # s just changed. Schedule's validation saw a different value.
```

### After

```python
@dataclass(frozen=True, slots=True)
class Grants:
    _perms: tuple[Permission, ...]

    @classmethod
    def parse(cls, raw: Iterable[str]) -> "Grants":
        return cls(tuple(dedupe_and_validate(raw)))     # freshly built here — no shared alias

    def all(self) -> tuple[Permission, ...]:            # a tuple cannot be sorted or assigned into
        return self._perms

    def __iter__(self) -> Iterator[Permission]:         # or expose iteration: no copy, no alias
        return iter(self._perms)


@dataclass(frozen=True, slots=True)
class Schedule:
    _days: tuple[Weekday, ...]

    @classmethod
    def parse(cls, days: Iterable[Weekday]) -> "Schedule":
        items = tuple(days)                              # copy on the way in
        if not items:
            raise ValueError("schedule: no days")
        return cls(items)
```

Now every mutation path runs through the type. The caller's `sorted(grants.all())`
sorts its own list; the caller's `days[0] = Weekday.SUNDAY` changes a list `Schedule`
no longer shares. The Python spellings of the two edges: `tuple(...)` and
`frozenset(...)` on the way in, a tuple, `types.MappingProxyType` or an iterator on
the way out, and `frozen=True` so no assignment slips in between. The invariant has
exactly one set of doors, and the constructor guards all of them.

## Design guidance

- **Copy at both edges.** A constructor clones slice/map arguments (or builds fresh
  ones, as `dedupeAndValidate` does); a query returns `slices.Clone`/`maps.Clone` or
  an iterator (`iter.Seq`). Between the edges, methods mutate freely — that interior
  is exactly what the type owns.
- **Iterators beat copies for read paths.** When callers only range, expose
  `iter.Seq[T]` (or a `Each(func(T) bool)` walker) — no alias escapes and no copy is
  paid. Return a copy only when callers legitimately need their own collection.
- **A method is a query or a modifier.** A caller who wants the value must be able to
  get it without causing the side effect (Fowler: Separate Query from Modifier).
  `R3-storifying.md`'s Honest Rename is the naming half — a mutator must sound like
  one; this rule owns the structural half — when call sites need the query alone,
  split the method in two.
- **No setters around a validating constructor.** A `SetPort(n)` that assigns without
  checking is a hole in `ParsePort`'s wall. If post-construction change is a real
  requirement, the mutator validates exactly as the constructor does — or returns a
  new value (`WithPort(n)`, returning a new value or an error). If it isn't a real requirement, there is
  no setter. (`R2-self-validating-types.md` owns construction; this rule owns the
  paths that could bypass it afterward.)
- **One variable, one purpose.** A variable reassigned to mean something new
  (`size := len(x)` … `size = size * unitPrice`) hides a phase change inside a name.
  Split it into two named variables (Fowler: Split Variable); if the phases are big,
  that's `R3-storifying.md`'s extraction signal.
- **The inverse trap: ceremony copies.** Cloning a slice that never escapes the
  function, or copying inside a hot loop "to be safe," is defensive noise — the
  mirror of R1's ceremony wrappers. Copy where an alias crosses an ownership
  boundary (constructor arguments, query returns on validated types), not
  everywhere a slice appears. Local, short-lived sharing inside one function is
  fine and idiomatic.

## Fix pattern

- **Copy on the Way In**: constructor stores `slices.Clone(arg)` / `maps.Clone(arg)`
  (or builds its own collection) instead of the caller's reference.
- **Copy on the Way Out / Encapsulate Collection**: queries on validated types return
  clones or `iter.Seq` iterators; delete call-site mutations of the returned value or
  convert them into named methods on the type (`Sorted()`, `Without(p)`).
- **Separate Query from Modifier**: split a method that both returns data and mutates
  into a pure query and a command; migrate each call site to the half it actually
  uses. (Pure renaming cases stay with R3's Honest Rename.)
- **Remove Setting Method**: delete the setter; route the change through a validating
  mutator, a `WithX` copy-constructor, or full reconstruction via `ParseX`.
- **Split Variable**: one assignment per meaning; new meaning, new name.
- New named methods this creates (`Sorted()`, `WithX`) must earn their place —
  score against `R1-primitive-obsession.md` before adding; a method nobody calls
  twice is ceremony.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

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
