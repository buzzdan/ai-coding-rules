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
factory per R2.

### Before

```typescript
export class Grants {
  private readonly perms: Permission[]

  constructor(raw: Iterable<string>) {
    this.perms = dedupeAndValidate(raw)            // non-empty, deduplicated
  }

  all(): Permission[] {                             // ❌ returns a mutable alias into the validated state
    return this.perms
  }
}
```

```typescript
// ❌ a distant caller, months later
const perms = user.grants.all()
perms.sort((a, b) => a.weight - b.weight)           // reorders internal state
perms[0] = Permission.None                          // corrupts it — no method called
```

The factory's guarantee is now a lie, and nothing in `grants.ts` changed. The write
that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```typescript
// ❌ constructor stores the caller's array
export class Schedule {
  private readonly days: Weekday[]

  constructor(days: Weekday[]) {
    if (days.length === 0) throw new ValidationError('schedule: no days')
    this.days = days
  }
}

const days = [Weekday.Monday]
const schedule = new Schedule(days)
days[0] = Weekday.Sunday    // schedule just changed. Schedule's validation saw a different value.
```

### After

```typescript
export class Grants {
  private constructor(private readonly perms: readonly Permission[]) {}

  static parse(raw: Iterable<string>): Grants {
    return new Grants(dedupeAndValidate(raw))       // freshly built here — no shared alias
  }

  all(): readonly Permission[] {                    // tsc rejects sort() and index assignment on it
    return this.perms
  }

  *[Symbol.iterator](): Iterator<Permission> {      // or expose iteration: no copy, no alias
    yield* this.perms
  }
}

export class Schedule {
  private constructor(private readonly days: readonly Weekday[]) {}

  static parse(days: Iterable<Weekday>): Schedule {
    const items = [...days]                         // copy on the way in
    if (items.length === 0) throw new ValidationError('schedule: no days')
    return new Schedule(items)
  }
}
```

Now every mutation path runs through the type. The caller's `grants.all().toSorted(…)`
sorts its own copy; the caller's `days[0] = Weekday.Sunday` changes an array
`Schedule` no longer shares. The TypeScript spellings of the two edges: a spread or
`Array.from` on the way in, a `readonly T[]`, `ReadonlyMap`/`ReadonlySet` or an
iterator on the way out, and `readonly` fields so no assignment slips in between —
all three checked by `tsc`, which is where an alias is caught cheapest. The invariant
has exactly one set of doors, and the factory guards all of them.

The React spellings of the same leak: a hook returning the array it keeps in a ref,
which a component `push`es into; a `select` option or selector that `.sort()`s query
data in place; `setState((d) => { d.status = x; return d })`, which mutates the
previous state and returns the same reference so React skips the render; a prop
array stored in a ref and mutated. The fixes are the same two edges — `readonly`
return types, `toSorted` or a spread copy at the boundary, an updater or reducer
that returns a new object — and, where a mutation is the honest job, a mutator named
as one.

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

1. **Does a method return an internal array, Map or Set by reference?**
   Detection: for each type in the diff with a validating factory, list its
   collection fields (`grep -nE '(private|readonly) +[a-zA-Z_]+ *: *([A-Za-z]+\[\]|Array<|Map<|Set<)' <file>`), then
   `grep -nE 'return this\.[a-zA-Z_]+$' <file>` — a bare `return this.items` whose
   return type is a mutable `T[]`/`Map`/`Set`, with no spread, `Array.from`, `new
   Map(…)`, `readonly` return type or iterator around it; a `get items()` accessor
   that returns the field is the same hit with a nicer name, and so is a hook that
   returns the array it keeps in a ref or in module state.
   Violation: an internal reference escapes a validated type — Copy on the Way Out
   (a `readonly Permission[]` return type, `[...this.items]`, a `ReadonlyMap` built
   with `new Map(this.byId)`, a generator).

2. **Does a constructor store a caller-provided array or Map without copying?**
   Detection: inside each constructor and static `parse` in the diff, check for a
   collection field assigned directly from a parameter (`this.items = items`; a
   parameter property `private readonly items: Item[]`). In a component, a prop
   array or object stored into `useRef`/`useState` and mutated later is the same
   alias.
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In (`[...items]`, `new Map(byId)`). A field typed `readonly T[]` makes the
   no-mutation half part of the contract but not the no-alias half: the caller
   still holds the mutable original, so the copy stays. (A collection built inside
   the factory, like `dedupeAndValidate`'s result, is fine — no one else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a return type other than `void`, grep
   its body for assignments to fields (`this\.[a-zA-Z_]+ =`,
   `this\.[a-zA-Z_]+\.(push|splice|sort|reverse|set|delete|clear)\(`); for each
   `select` option, selector or formatter over query data, grep for an in-place
   `.sort(`, `.reverse(` or `.splice(` on data the function did not build — the
   query cache is the receiver it mutates. `no-param-reassign` marks the writes to
   parameters; the in-place sort of someone else's data is review-only.
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier; a selector that
   sorts in place becomes `toSorted(…)`. (If every caller genuinely needs both
   halves atomically — a pop-and-report on a queue — it is one operation; name it as
   a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: `grep -rnE '^\s+set [a-zA-Z_]+\(|^\s+set[A-Z][a-zA-Z]*\([^)]*\): void' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for setters, and for each class or type with a validating `parse` check whether
   its fields are `readonly` (`sonarjs/prefer-read-only-props` is the same check for
   component props); for each hit, does the type validate in its factory, and does
   the setter re-check? In state: `setState((d) => { d.status = x; return d })`
   mutates the previous state and returns the same reference, so React skips the
   render (`react/no-direct-mutation-state` catches the class-component form; the
   hook form is review-only).
   Violation: a setter, or a mutable field, that assigns unchecked on a
   factory-validated type — Remove Setting Method (and `readonly`, so `port.number
   = 0` fails under `tsc`); an updater that mutates — return a new object
   (`{ ...d, status: x }`) or a reducer that returns new state. (Public mutable
   fields with no factory check at all are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every `let` that survives
   `prefer-const` (it is reassigned somewhere), including a loop variable reused
   after its loop or an `n` that counted one thing and then another, ask whether the
   right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new `[...x]`, `{ ...x }`, `Array.from`, `new Map(x)`,
   `structuredClone` or manual copy loop in the diff — and each `useMemo(() =>
   [...items], [items])` over a prop — trace the copied value: does the source or
   the copy ever cross a function boundary or outlive the call?
   Violation: cloning data that provably never escapes, or copying on every render
   of a list the profile cares about — ceremony; delete the copy and note why
   sharing is safe. A module-level `const EMPTY_ITEMS: Item[] = []` handed out as a
   default to several callers is the opposite failure — one array shared by every
   call; type it `readonly Item[]` so no caller can push into it.
