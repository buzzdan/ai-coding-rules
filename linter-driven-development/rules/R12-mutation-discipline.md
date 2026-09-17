# R12 — Mutation Discipline (Encapsulated State)

## Principle

A validated value changes state only through methods that own its invariants — never
through leaked internals. Constructors copy the slices and maps they are given;
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

```text
Grants
    perms                    # constructor guarantees: non-empty, deduplicated
parseGrants(raw):
    perms = dedupeAndValidate(raw)     # fails → the failure
    return Grants(perms)
Grants.all():
    return self.perms        # ❌ returns a mutable alias into the validated state
```

```text
# ❌ a distant caller, months later
perms = user.grants.all()
perms.sort(...)              # reorders internal state
perms[0] = PermissionNone    # corrupts it — no method called
```

The constructor's guarantee is now a lie, and nothing in the grants file changed. The
write that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```text
# ❌ constructor stores the caller's list
newSchedule(days):
    if days is empty: fail "schedule: no days"
    return Schedule(days)

days = [Monday]
schedule = newSchedule(days)
days[0] = Sunday             # schedule just changed. newSchedule's validation saw a different value.
```

### After

```text
parseGrants(raw):
    perms = dedupeAndValidate(raw)     # freshly built here — no shared alias
    return Grants(perms)

Grants.all():
    return copy of self.perms          # callers may do anything with it

Grants.each():
    yield each permission              # or expose iteration instead of the collection
                                       # (no copy, no alias)

newSchedule(days):
    if days is empty: fail "schedule: no days"
    return Schedule(copy of days)      # copy on the way in
```

Now every mutation path runs through the type. The caller's sort reorders its own
copy; the caller's `days[0] = Sunday` changes a list `Schedule` no longer shares. The
invariant has exactly one set of doors, and the constructor guards all of them. In a
language with immutable collections, storing a frozen copy is the same move with the
copy made once.

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

Build each search over the language's source files (`detected-language source`).

1. **Does a method return an internal list or map by reference?**
   Detection: for each type in the diff with a validating constructor, list its
   collection fields (read the type's declaration), then find in its methods a bare
   `return self.<field>` / `return x.<field>` with no copy, clone or iterator around
   it.
   Violation: an internal reference escapes a validated type — Copy on the Way Out.

2. **Does a constructor store a caller-provided list or map without copying?**
   Detection: inside each `ParseX`/`NewX` in the diff, check the construction for a
   collection field assigned directly from a parameter identifier.
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In. (A collection built inside the constructor, like `dedupeAndValidate`'s
   result, is fine — no one else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a non-error return value, search its body
   for assignments to receiver fields (`self.<field> =`, `this.<field> =`, an append
   or push onto a receiver collection).
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier. (If every caller
   genuinely needs both halves atomically — a lock-guarded pop-and-report — it is one
   operation; name it as a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: search the source files for setters on public types (methods named
   `set<Field>`, a property setter, a public mutable field); for each hit, does the
   receiver type have a `ParseX`/`NewX` that validates, and does the setter
   re-check?
   Violation: a setter that assigns unchecked on a constructor-validated type —
   Remove Setting Method. (Public mutable fields on such types are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every reassignment (`x = ...` after
   `x` was first bound), ask whether the right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new clone, copy or manual copy loop in the diff, trace the
   copied value: does the source or the copy ever cross a function boundary or
   outlive the call?
   Violation: cloning data that provably never escapes, or copying per-iteration in
   a loop the profile cares about — ceremony; delete the copy and note why sharing
   is safe.
