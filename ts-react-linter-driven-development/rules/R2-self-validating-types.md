# R2 — Self-Validating Types

## Principle

A type validates its own invariants in its constructor — the only way to obtain a
value — and every method thereafter trusts the receiver. Validation ownership never
sits upstream: a type that relies on callers to have validated for it is not
self-validating, whatever its fields look like.

## Why

Constructor validation makes invalid values unrepresentable. Without it, every method
must defend against bad state, forgetting one check is a latent crash, and the
defensive noise buries the actual logic. With it, undefined-checks, emptiness checks, and
range checks vanish from the entire downstream call graph — the payoff compounds with
every method and every caller. Errors also surface at the boundary where the bad data
entered, carrying context, instead of deep in an unrelated call stack.

## Canonical example

Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing):

```typescript
/** A named, validated service port; it cannot exist out of range. */
export interface Port {
  readonly name: string
  readonly number: number
}

export function parsePort(name: string, number: number): Port {
  if (!Number.isInteger(number) || number <= 0 || number > 65535) {
    throw new RangeError(`port '${name}': ${number} out of range 1-65535`)
  }
  return { name, number }
}
```

This is the TypeScript self-validating type: a `readonly` shape and the one factory
that builds it. Types are erased, so no check runs on a literal; what "the
constructor is the only entry" means here is that `readonly` forbids assignment after
construction and `parsePort` is the only production site that spells a `Port`
literal — a discipline, enforced by Q1's grep rather than by `tsc`. Before this type
existed, `p.port > 0 && p.port <= 65535` was duplicated across two loops at the use
site. After, there is no `isValid()` and no re-check anywhere: the concept of a
maybe-invalid port is deleted from downstream logic, not relocated. A mutable
`interface` with the same two fields and no factory, or `{ name, number: 70000 }`
written beside the factory, is the hole this rule hunts: every caller can build an
invalid `Port`, and every method must defend.

The same pattern for a composed object — validate dependencies once, then trust:

```typescript
// ❌ every method defends
class UserService {
  constructor(public repo: Repository | undefined) {}

  async createUser(user: User): Promise<void> {
    if (this.repo === undefined) { // repeated in every method; forget one → TypeError at run time
      throw new Error('repo is undefined')
    }
    await this.repo.save(user)
  }
}

// ✅ constructor validates once; methods trust the instance
class UserService {
  constructor(private readonly repo: Repository) {} // new UserService(undefined) fails tsc

  async createUser(user: User): Promise<void> {
    await this.repo.save(user) // no checks — an invalid service cannot exist
  }
}
```

The typed half is mechanical: `repo: Repository` rejects `undefined` at compile time,
and a run-time guard behind it would trip `@typescript-eslint/no-unnecessary-condition`.
The finding survives where the parameter says `Repository | undefined`, or where the
caller is not type-checked.

Where the value is built from unstructured input — a wire response, a search param —
the constructor is a boundary parser that narrows `unknown` with type guards and then
constructs, so the domain only ever sees typed fields:

```typescript
export function parseDevice(raw: unknown): Device {
  if (!isRecord(raw) || typeof raw.id !== 'string' || typeof raw.hostname !== 'string') {
    throw new ApiError('device: malformed response')
  }
  return { id: parseDeviceId(raw.id), hostname: raw.hostname }
}
```

At a boundary that already uses a schema library, `deviceSchema.parse(raw)` is the
same constructor and `z.infer` its type; inside the domain the factory is enough.
`data as DeviceApiResponse`, `apiClient.get<Device>()` taken on faith and
`as unknown as Device` are paths around the constructor: an assertion is not
validation.

## Design guidance

- **Constructors are the only entry.** `ParseX(raw)` for values built from
  unstructured input, `NewX(deps)` for composed objects, each returning the value or an
  error (constructors may carry other names — any public function returning the type
  qualifies). Fields stay unexported: building the value directly, bypassing the
  constructor, is a hole in the type.

- **Validation ownership.** A type never relies on upstream validation. "The handler
  already checked it" is not an invariant — handlers change, new call sites appear,
  and the type outlives both. A comment reading "caller must ensure X" is the
  signature of a type that does not own itself: move that sentence into the
  constructor as code.

  ```typescript
  // ❌ relies on callers to validate
  export interface Config {
    host: string // every caller must remember: if (host === '') ...
    port: number
  }

  // ✅ owns its own validation
  export interface Config {
    readonly host: string
    readonly port: number
  }

  export function parseConfig(host: string, port: number): Config {
    if (host === '') {
      throw new Error('host required')
    }
    if (!Number.isInteger(port) || port <= 0 || port > 65535) {
      throw new Error('invalid port')
    }
    return { host, port }
  }
  ```

- **Trust composed values.** Once you hold a `Port`, it is valid — never re-check it
  downstream, and never re-validate it in a composing constructor. Each type owns
  exactly its own invariants:

  ```typescript
  // ❌ re-validates what Host already guarantees
  export function createAddress(host: Host, port: Port): Address {
    if (host.name === '') { // Host owns this
      throw new Error('host required')
    }
    return { host, port }
  }

  // ✅ trusts composed self-validating types — nothing left to check, nothing to throw
  export interface Address {
    readonly host: Host
    readonly port: Port
  }
  // an object literal is its constructor: both parts arrive valid, so no factory is owed
  ```

- **undefined is not a value.** Never return undefined where a real value is expected —
  return an error instead. A failure result carries the error, not a value, so that
  position is exempt. Never pass undefined into a function; then functions do not
  check parameters for undefined.

- **Absence is a value too.** An *optional* collaborator — a logger, a metrics sink,
  an event writer, a clock — is not a field that may be undefined with a guard in every
  method. The default is a named do-nothing value the constructor supplies, the field
  is never undefined, and every "if the sink is set" guard disappears. This is the Null
  Object of `R11-conditional-dispatch.md`: a real implementation that honors the
  contract by doing nothing, so no caller ever branches on a missing destination. No
  parameter accepts undefined to mean "default": substituting the default inside the
  constructor keeps passing undefined legal and merely moves the check — the default
  lives in an option or the caller passes the Null Object by name. Only a *required*
  collaborator (a store, a client the type cannot work without) is rejected in the
  constructor — doing nothing silently there would hide a bug. Promoting an optional
  collaborator to a required positional parameter with a comment saying "pass the
  do-nothing value instead of undefined" changes nothing: the parameter still accepts
  undefined, the constructor neither defaults nor rejects it, and the first use crashes.
  A collaborator with a sensible do-nothing default is optional; it stays an option
  with the default in the constructor. An option handed undefined must not become a
  value that works: it records the failure on the value under construction, and the
  constructor fails with a message naming the option; the field never holds undefined;
  no method ever asks.

  **The TypeScript shape.** A do-nothing object is stateless, so it can be a real
  default value: `const NULL_SINK: Sink = { write() {} }` at module level, the
  options property optional (`sink?: Sink`) and filled by a destructuring default,
  the field typed `Sink`, never `Sink | undefined`. `tsc` then rejects
  `new Reporter({ sink: null })` before it runs, and a caller that spells
  `sink: undefined` gets the default and R2 Q6's finding. A parameter typed
  `sink: Sink | undefined` with `this.sink = sink ?? NULL_SINK` inside the constructor
  keeps `undefined` legal and merely moves the check. A destructuring default is
  evaluated per call, so a default that must be built rather than shared is still
  `sink = buildSink()` in the parameter list — never `??` behind a `| undefined`
  parameter.

  ```typescript
  // ❌ optional sink kept undefined-able; every method re-asks the question
  class Reporter {
    constructor(private readonly sink?: Sink) {}

    record(ev: UiEvent): void {
      if (this.sink !== undefined) {
        this.sink.write(ev, new Date())
      }
    }
  }

  // ✅ absence is a named value; no argument is ever undefined
  export const NULL_SINK: Sink = { write() {} } // a real Sink whose write() discards
  export const SYSTEM_CLOCK: Clock = { now: () => new Date() }

  interface ReporterOptions {
    readonly sink?: Sink
    readonly clock?: Clock
  }

  class Reporter {
    private readonly sink: Sink
    private readonly clock: Clock

    constructor({ sink = NULL_SINK, clock = SYSTEM_CLOCK }: ReporterOptions = {}) {
      this.sink = sink
      this.clock = clock
    }

    record(ev: UiEvent): void {
      this.sink.write(ev, this.clock.now()) // no guard anywhere
    }
  }
  // production: new Reporter({ sink: new HttpSink(apiClient) }); tests: new Reporter({ clock: fixedClock(t0) })
  ```

- **No defensive coding.** Check arguments in the constructor so that methods contain
  zero undefined/emptiness checks on their own fields. A method validating its receiver is
  validation in the wrong place.

## Fix pattern

- **Add validating constructor**: make fields unexported, add `NewX`/`ParseX`
  returning the value or an error, migrate every literal-construction site through it.
- **Hoist method checks into the constructor**: collect the field checks scattered
  across methods, run them once at construction, delete them from the methods. For a
  *required* collaborator the hoisted check rejects undefined; for an *optional* one it is
  the wrong move — use the next one.
- **Introduce Null Object** (`R11-conditional-dispatch.md`): an optional collaborator
  gets a *named* do-nothing value that the constructor supplies through an option or
  the caller passes explicitly; the field is never undefined by construction, an option
  handed undefined records the error for the constructor to return instead of
  substituting the default, and every guard in the methods is deleted. When the
  collaborator wraps a standard writer or clock, compose the standard no-op into it;
  do not introduce an interface for the sake of the no-op
  (`R6-test-only-interfaces.md`).
- **Delete re-validation of composed types**: if every parameter is itself
  self-validating and there is nothing left to check, the constructor no longer needs
  to fail.
- **Separate Failure from Absence**: an error for failure, an explicit absence result
  for a missing value — never undefined standing in for either; see the sentinel move in
  `R1-primitive-obsession.md`.
- Forward design of new types: @code-designing. The primitive extraction that usually
  precedes this rule: `R1-primitive-obsession.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Can the type exist in an invalid state?**
   Detection: for each new/changed type with invariants, read its declaration: an
   `interface` or `type` whose fields are not `readonly`, a class whose constructor
   assigns without checking, or (where the repository has a schema library) a schema
   with no refinement for the field that carries the rule. Then
   `grep -rnE '<Type> = \{|: <Type> = \{|as <Type>\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   for construction sites outside the factory, and
   `grep -rn 'as unknown as' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for the double cast. Literal construction is the hole here: types are erased, so
   an object literal typed `Port` never meets `parsePort`, and the factory is the
   only entry by discipline — every literal outside it and outside tests is a path
   around the constructor. A class with a `private` field and a private constructor
   closes the path for the compiler as well.
   Violation: a mutable field carrying an invariant it never checks, an object
   literal or `as <Type>` outside the factory and tests, or an `apiClient.get<T>()`
   whose `T` is a domain type — each gives callers a path around the constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detection: `grep -nE 'if \(!?this\.[a-zA-Z_]+( (===|!==) (undefined|null))?\)|if \(this\.[a-zA-Z_]+\.length === 0\)|this\.[a-zA-Z_]+\?\.' <changed files>`
   inside method bodies (not the constructor); in a hook or component the instance
   is its props and state, so `if (!cluster)` and `cluster?.name` on a required prop
   are the same hits.
   Violation: a method validating its own instance's fields — the check belongs in
   the constructor. Decide which fix by asking whether the field is required or
   optional: a required collaborator is rejected in the constructor (Hoist method
   checks); an optional one (logger, sink, clock, metrics) gets a Null Object
   default there instead (Introduce Null Object, R11) — name both moves in the
   finding when the code does not say which the field is. A field typed
   `X | undefined` on the class is the evidence that the question is asked in every
   method, whether or not each method spells the guard; `?.` spells it in one
   character.

3. **Does a constructor re-validate a composed self-validating type?**
   Detection: read each `parseX`/`createX` factory and class constructor in the
   diff; for every parameter whose type has its own factory or type guard, grep the
   body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detection: `grep -rn 'caller must\|assumes valid\|already validated' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`;
   also flag mutable fields consumed by logic in a module that defines no factory or
   type guard for the type, and a bare `type DeviceId = string` or a brand with no
   validating constructor standing in for a validated value (both are erased; the
   alias admits every literal and the brand every cast).
   Violation: any invariant enforced — or merely documented — outside the type
   itself.

5. **Does anything return or accept `undefined` or `null` as a value?**
   Detection: `grep -nE 'return (undefined|null)\s*(//.*)?$|^\s+return$' <changed files>`
   (a bare `return` in a function with a return type counts), then read each hit's
   signature and the branch it sits in. Three verdicts:
   - the signature says `: X` and the body returns `null` or `undefined`: `tsc`
     rejects it under `strict`, so the hit arrives silenced — `as X`, a `!`, a
     `@ts-expect-error` — or as `-1`/`''`/`0`: R1 Q4's sentinel, cite it there;
   - the signature says `: X | undefined` and the `undefined` branch is a normal
     absence a caller expects — a `Map.get`, the first match of a `find`, an
     optional property — and every caller narrows it: not a finding. `undefined` is
     TypeScript's declared absence, checked by `strict` at each call site; `null` is
     the wire's absence and stops at the boundary, where the parser maps it to
     `undefined` or to a domain value;
   - the signature says `: X | undefined` (or `| null`) and the branch is a failure
     — malformed input, a broken invariant, a `catch` that returns `null` and turns
     a network error into "not found" — or callers stack `?.`, `??` and `if (!x)`
     because the absence should have been an exception: Separate Failure from
     Absence; `throw` where the failure `return` was, and keep `X | undefined` only
     for the branch that is truly absence.
   Exempt: `: void` procedures, the `undefined` result of a well-typed `.get` or
   `.find`, and a component returning `null` to render nothing. `[X, boolean]` is
   never the fix: it is a comma-ok idiom with a TypeScript spelling.
   Violation: `null`/`undefined` returned where the signature promises a value;
   `undefined` standing in for a failure; or a function guarding a parameter against
   `undefined` instead of the value being guaranteed by construction and by its type.

6. **Does any call site pass `undefined` or `null` as a non-error argument?**
   Detection: `grep -nE '\((undefined|null)[,)]|, (undefined|null)[,)]|: (undefined|null)[,} ]' <changed files>`
   — exempt comparisons (`=== undefined`, `!== null`), and platform idioms where the
   value is the documented "no value" (`JSON.stringify(v, null, 2)`, `useRef<T>(null)`
   for a DOM ref, `createContext<T | undefined>(undefined)` for the key whose `useX()`
   throws outside its provider).
   Violation: `undefined` or `null` passed where a value is expected — `useX(undefined)`,
   `new Reporter(sink, undefined)`. Q5 catches the return side and Q2 catches the
   callee that defends; this catches the caller when the callee does neither and
   throws `TypeError` later. Fix on the callee's side: make the hole unrepresentable
   — a parameter typed `X`, never `X | undefined` or `x?: X` on a required value; a
   constructor whose parameter type rejects it (see the UserService example above);
   or, for an optional collaborator, a Null Object default through destructuring so
   the caller never has a reason to pass `undefined` (R11). An optional callback prop
   (`onOpenEvents?`) is not this finding when the component has a meaning without
   it; it is when every render path guards it, or the component cannot do its job
   without it — then the prop is required. `tsc` makes the typed half of this
   question mechanical: `undefined` passed to an `X` parameter does not compile, so
   the finding survives only where the parameter is typed `X | undefined` or `x?: X`,
   or the code is not type-checked.
