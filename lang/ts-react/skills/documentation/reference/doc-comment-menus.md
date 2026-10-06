## JSDoc Menus

**These are MENUS, not forms** (normative: R9's tiered comment-budget policy —
**1–5 prose lines** scaled to the symbol's role; blank ` *` lines, the See-edge,
`@param`/`@returns`/`@throws` tags that add what the signature cannot, and short
`@example` blocks of 2–4 lines are free). The menus price **exported** API only —
non-exported symbols default to no JSDoc at all (R9's visibility default; special
case: one very-high-value line), and carry no `jsdoc/require-jsdoc` obligation. The
WHY is the default content; the type system carries the WHAT, so a line that
restates a type (`/** The cluster id */` on `clusterId: string`, a `@param id - the
id`, a `@type` tag) is never ordered. The tier caps how much of a menu any one
symbol can order:

- **Helper** (small function, plain constructor, obvious accessor, a presentational
  component whose props say it all) → 0–1 line, or nothing; a tiny `@example` only
  if it clarifies.
- **Contract** (`parseX` factory, self-validating type, a query hook, ordinary
  exported API) → 2–3 lines; a dos/don'ts `@example` is free and often earns its
  place.
- **Crossroads** (route component, page front door, provider, orchestrating hook,
  state machine) → up to 5 lines: WHY, architectural context, use cases.

Overflow never stays inline — it moves to the feature doc; the
`See docs/<feature>.md` edge (kept whenever the doc exists) carries the pointer. A
crossroads that deserves more than 5 lines inline gets an expand recommendation in
the FEATURE report instead of extra lines — a human decides (R9's escape hatch).

What fills the chosen menu lines comes from the [Comment Value Toolbox](#comment-value-toolbox)
above — every prose line must deliver one of its values, in plain English (R9's
three-test standard).

**The summary line is the contract, not a restatement.** The first line of the
block — one sentence, ending in a period — states what the symbol promises
(`/** A named, validated service port; it cannot exist out of range. */`). It is
exempt from the critic's restatement verdict when it does that, and a finding when
it repeats the name (`/** Gets the user. */` on `getUser`). The body, after one
blank ` *` line, is where the WHY budget applies. `@param` and `@returns` appear
only when they add what the signature cannot — units, ownership, what a valid value
is — never to restate a type. Where the repository's `jsdoc/require-jsdoc` requires
a block, a WHAT-comment is rewritten, never deleted; on a non-exported name it is
deleted.

### Module JSDoc Menu

Pick only the lines this module or package needs — one block at the top of the file,
before the first import:

```typescript
/**
 * [High-level purpose of the module, one line].          <- always (one line)
 *
 * [1-2 sentences: what problem this solves]              <- usually
 *
 * Main data flow:                                        <- only if non-obvious
 *   Response -> parse -> Domain type -> Component
 *
 * Core types:                                            <- multi-type modules only
 *   - Type1: [key responsibility]
 *
 * Design decisions:                                      <- only where rationale exists
 *   - [Key decision and why]
 *
 * See docs/[feature].md for architecture and usage.      <- whenever the doc exists
 */
```

**The `index.ts` hatch (R9):** when a package (a page or feature folder) genuinely
earns more than the standard budget — flow sketch, core-types list, and design
decisions all pulling their weight — the package doc lives at the top of its
`index.ts`, the public surface, bounded at ~20–30 lines, and the modules inside keep
to the standard tier budget.

### Component JSDoc Menu

The props type carries the WHAT; a prop gets a line only for what its type cannot say:

```tsx
interface SnapshotsTableProps {
  /** Newest first; the table does not sort. */            // <- ordering the type cannot say
  readonly snapshots: readonly Snapshot[]
  /** Milliseconds; 0 disables polling. */                 // <- units
  readonly pollInterval: number
  /** The page owns navigation; the table only reports. */ // <- ownership: who acts on it
  readonly onOpen: (id: SnapshotId) => void
  readonly clusterId: ClusterId                            // <- nothing: name and type say it
}

/**
 * [One-line domain meaning: what it renders, for whom].  <- always
 *
 * [WHY it has this shape: the state it does not own,     <- the default content
 *  the constraint behind a prop, the page that owns it]
 *
 * See docs/[feature].md for the full picture.            <- whenever the doc exists
 */
export function SnapshotsTable(props: Readonly<SnapshotsTableProps>) {
  // ...
}
```

### Hook JSDoc Menu

The return type is the WHAT; the block is the contract behind it:

```typescript
/**
 * [What the hook owns, one line].                        <- always
 *
 * [The contract of its return shape: what `data` is      <- the default content
 *  before the first fetch, when it refetches, what
 *  invalidates it]
 *
 * @throws {Error} outside `<ClusterProvider>`            <- context hooks: the failure contract
 *
 * See docs/[feature].md#section for the detailed flow.  <- whenever the doc exists
 */
export function useSnapshots(clusterId: ClusterId) {
  // ...
}
```

### Type JSDoc Menu

Pick per symbol kind (hints above):

```typescript
/**
 * [One-line domain meaning].                             <- always
 *
 * [WHY it exists: rationale, incident, constraint —      <- the default content
 *  context the code cannot carry]
 *
 * Invariant:                                             <- self-validating types:
 *   [what every value satisfies; only `parsePolicy`         what holds, and who builds it
 *    builds one]
 *
 * Use cases / flow:                                      <- logic-heavy types only
 *   [when to reach for it, or a short flow sketch]
 *
 * @example                                               <- parse functions:
 * parsePolicy('3x100ms').maxAttempts // => 3                 dos/don'ts inputs
 * parsePolicy('0x100ms') // throws PolicyError: zero attempts
 *
 * See docs/[feature].md for the full picture.            <- whenever the doc exists
 */
export interface Policy {
  readonly maxAttempts: number
  readonly baseDelayMs: number
}
```

### Function JSDoc Menu

Only for non-obvious behavior; a small function or plain constructor gets one line,
or nothing:

```typescript
/**
 * [Does what] for [purpose].                             <- always, if documented at all
 *
 * [Non-obvious behavior, performance characteristics]    <- only when non-obvious
 *
 * @param raw - [what a valid value is, not its type]     <- when a parameter needs more
 *                                                           than its name and type
 * @throws {ApiError} [when]                              <- the failure contract,
 *                                                           when callers must handle it
 * See docs/[feature].md#section for the detailed flow.  <- whenever the doc exists
 */
export function parseSnapshot(raw: unknown): Snapshot {
  if (!isSnapshotResponse(raw)) throw new ApiError('snapshot: unexpected shape')
  return { id: parseSnapshotId(raw.id), takenAt: new Date(raw.taken_at) }
}
```

### Runnable Example Template

```typescript
/**
 * A validated user id.
 *
 * @example
 * parseUserId('usr_123') // => 'usr_123'
 * parseUserId('') // throws RangeError: empty user id
 */
export type UserId = string & { readonly __brand: 'UserId' }

export function parseUserId(raw: string): UserId {
  if (raw === '') throw new RangeError('empty user id')
  return raw as UserId
}
```

Nothing runs an `@example`; the colocated `userId.test.ts` makes the same two calls
(`expect(parseUserId('usr_123')).toBe('usr_123')`,
`expect(() => parseUserId('')).toThrow(RangeError)`) and keeps it honest. Examples
show happy-path usage plus the one rejection that defines the contract. Keep simple —
complex scenarios belong in feature docs.
