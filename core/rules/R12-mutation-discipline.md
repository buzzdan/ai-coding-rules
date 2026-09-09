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

{{include "rules/R12/canonical-example.md"}}

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
{{include "rules/R12/falsifying-questions.md"}}
