# R12 — Mutation Discipline (Encapsulated State)

## Principle

A validated value changes state only through methods that own its invariants — never
through leaked internals. Constructors copy the slices and maps they are given;
queries return copies (or iterators), not the internal reference; a method is a query
or a modifier, not both; and a type with a validating constructor exposes no setter
that skips the validation. This rule adapts Fowler's *Mutable Data* smell family
(Refactoring, 2nd ed.: Encapsulate Collection, Separate Query from Modifier, Remove
Setting Method, Split Variable) to Go, where slices and maps are references into
shared backing storage.

## Why

R2's payoff — validate once, trust the value everywhere after — is void the moment an
internal slice escapes. In Go, `return g.perms` does not return the permissions; it
returns a mutable alias into them. The caller can sort, truncate, or overwrite the
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

```go
type Grants struct {
    perms []Permission // constructor guarantees: non-empty, deduplicated
}

func ParseGrants(raw []string) (Grants, error) {
    perms, err := dedupeAndValidate(raw)
    if err != nil {
        return Grants{}, err
    }
    return Grants{perms: perms}, nil
}

// ❌ returns a mutable alias into the validated state
func (g Grants) All() []Permission { return g.perms }
```

```go
// ❌ a distant caller, months later
perms := user.Grants.All()
sort.Slice(perms, func(i, j int) bool { ... }) // reorders internal state
perms[0] = PermissionNone                       // corrupts it — no method called
```

The constructor's guarantee is now a lie, and nothing in `grants.go` changed. The
write that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```go
// ❌ constructor stores the caller's slice
func NewSchedule(days []Weekday) (Schedule, error) {
    if len(days) == 0 {
        return Schedule{}, errors.New("schedule: no days")
    }
    return Schedule{days: days}, nil
}

days := []Weekday{Monday}
s, _ := NewSchedule(days)
days[0] = Sunday // s just changed. NewSchedule's validation saw a different value.
```

### After

```go
func ParseGrants(raw []string) (Grants, error) {
    perms, err := dedupeAndValidate(raw) // freshly built here — no shared alias
    if err != nil {
        return Grants{}, err
    }
    return Grants{perms: perms}, nil
}

// All returns a copy; callers may do anything with it.
func (g Grants) All() []Permission { return slices.Clone(g.perms) }

// Or expose iteration instead of the collection (no copy, no alias):
func (g Grants) Each() iter.Seq[Permission] { return slices.Values(g.perms) }

func NewSchedule(days []Weekday) (Schedule, error) {
    if len(days) == 0 {
        return Schedule{}, errors.New("schedule: no days")
    }
    return Schedule{days: slices.Clone(days)}, nil // copy on the way in
}
```

Now every mutation path runs through the type. The caller's `sort.Slice` reorders its
own copy; the caller's `days[0] = Sunday` changes a slice `Schedule` no longer
shares. The invariant has exactly one set of doors, and the constructor guards all of
them.

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
  new value (`WithPort(n) (Server, error)`). If it isn't a real requirement, there is
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

1. **Does a method return an internal slice or map by reference?**
   Detection: for each type in the diff with a validating constructor, list its
   slice/map fields (`grep -A8 'type <X> struct' <file>`), then
   `grep -nE 'return [a-z][a-zA-Z]*\.(<field1>|<field2>)$' <file>` — a bare
   `return x.field` with no `Clone`/copy/iterator around it.
   Violation: an internal reference escapes a validated type — Copy on the Way Out.

2. **Does a constructor store a caller-provided slice/map without copying?**
   Detection: inside each `ParseX`/`NewX` in the diff, check the struct literal for a
   slice/map field assigned directly from a parameter identifier
   (`grep -nE '<param>\s*[,}]' within the return literal).
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In. (A collection built inside the constructor, like `dedupeAndValidate`'s
   result, is fine — no one else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a non-error return value,
   grep its body for assignments to receiver fields (`<recv>.<field> =`,
   `append(<recv>.` ).
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier. (If every caller
   genuinely needs both halves atomically — `sync`-guarded pop-and-report — it is
   one operation; name it as a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: `grep -rnE 'func \([a-z][a-zA-Z]* \*?[A-Z][a-zA-Z]*\) Set[A-Z]' --include='*.go' .`
   for setters; for each hit, does the receiver type have a `ParseX`/`NewX` that
   validates, and does the setter re-check?
   Violation: a setter that assigns unchecked on a constructor-validated type —
   Remove Setting Method. (Exported mutable fields on such types are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every reassignment (`x = ...` after
   `x := ...`), ask whether the right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new `slices.Clone`/`maps.Clone`/manual copy loop in the diff,
   trace the copied value: does the source or the copy ever cross a function
   boundary or outlive the call?
   Violation: cloning data that provably never escapes, or copying per-iteration in
   a loop the profile cares about — ceremony; delete the copy and note why sharing
   is safe.
