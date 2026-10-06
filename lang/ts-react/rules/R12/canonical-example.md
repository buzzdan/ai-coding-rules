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
