```typescript
// ❌ returns a mutable alias into validated state; a distant caller sorts it in place
export class Grants {
  private readonly perms: Permission[]

  constructor(raw: Iterable<string>) {
    this.perms = dedupeAndValidate(raw) // non-empty, deduplicated
  }

  all(): Permission[] {
    return this.perms
  }
}

const perms = user.grants.all()
perms.sort((a, b) => a.weight - b.weight) // reorders internal state; no method called

// ✅ copy on the way in; hand out a readonly view, not the storage
export class Grants {
  private constructor(private readonly perms: readonly Permission[]) {}

  static parse(raw: Iterable<string>): Grants {
    return new Grants([...dedupeAndValidate(raw)]) // freshly built here — no shared alias
  }

  all(): readonly Permission[] { // tsc rejects sort() and index assignment on it
    return this.perms
  }
}

const sorted = user.grants.all().toSorted((a, b) => a.weight - b.weight) // the caller's own copy
```

> **In TypeScript:** `readonly` is a compile-time wall, and `tsc` is where an alias is
> caught cheapest: a spread or `Array.from` on the way in, `readonly T[]`,
> `ReadonlyMap` or `ReadonlySet` on the way out, `readonly` fields so nothing is
> assigned in between. `as const` freezes the type, not the value, and `Object.freeze`
> is shallow. The React forms of the leak: a selector that `.sort()`s query data in
> place, an updater that mutates the previous state and returns the same reference so
> React skips the render, a prop array stored in a ref and mutated; the fix is
> `toSorted` or a spread copy, and an updater that returns a new object.
