# R1 — Primitive Obsession

## Principle

Domain concepts must not travel as raw strings, numbers, booleans or lists. When a primitive
carries validation rules, behavior, or a domain name, it becomes a type with a
validating constructor and named methods. The inverse binds equally: a wrapper that
adds no validation, no logic, and no invariant is over-abstraction — score before you wrap.

## Why

A rule enforced on a primitive is enforced at every call site and owned by none: the
check gets duplicated, drifts, and is skipped exactly once — in the code path that
ships the bug. Logic trapped on primitives is also untestable in isolation: you must
construct whatever large object happens to hold the primitive. A domain type gives the
rule one owner (the constructor — see `R2-self-validating-types.md`), gives the
behavior a name, makes invalid values unrepresentable downstream, and turns the logic
into a leaf that unit-tests with literals. Where the extracted type then lives is
`R4-helper-placement.md`.

## Canonical example

The Port case, in TypeScript. The dashboard renders a link to a cluster's management
console. The API returns a service description with ports, and the UI must pick the
management port: prefer the port named `weka-api`, else fall back to the first valid
port.

### Before

```typescript
function managementPort(spec: ServiceSpec): number {
  for (const p of spec.ports) {
    if (p.name === 'weka-api' && p.port > 0 && p.port <= 65535) {
      return p.port
    }
  }
  for (const p of spec.ports) {
    if (p.port > 0 && p.port <= 65535) {
      return p.port
    }
  }
  return 0
}
```

Four defects in twelve lines:

- The validity rule `p.port > 0 && p.port <= 65535` is duplicated across the two
  loops — two copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic runs on the wire DTO inside the hook that fetched it, so it is testable
  only by rendering the page over an MSW fixture of the whole service response.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none" — the `<a href>` that forgets renders a link to port `0`.

### Stage 1 — self-validating types with constructors

```typescript
/** The wire DTO: exactly what the API returned, no rules. */
export interface ServicePort {
  readonly name: string
  readonly port: number
}

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

/** A collection of valid ports. */
export class Ports {
  constructor(private readonly items: readonly Port[]) {}

  firstNamed(name: string): Port | undefined {
    return this.items.find((p) => p.name === name)
  }

  first(): Port | undefined {
    return this.items[0]
  }

  management(): Port | undefined {
    // Stage 2 relocates this method — the "weka-api" preference is feature
    // policy, not networking vocabulary.
    return this.firstNamed('weka-api') ?? this.first()
  }
}

// Drops invalid wire entries — a documented decision that mirrors the original
// skip-and-fall-back behaviour: an invalid port was never chosen before; now it
// never exists.
export function parsePorts(wire: readonly ServicePort[]): Ports {
  const items: Port[] = []
  for (const w of wire) {
    try {
      items.push(parsePort(w.name, w.port))
    } catch {
      continue
    }
  }
  return new Ports(items)
}
```

The payoff, stated plainly: notice what was **not** written. There is no `isValid()`
method and no validity loop anywhere. Self-validation does not move the
`> 0 && <= 65535` check somewhere tidier — it **deletes the concept of a
maybe-invalid port from downstream logic**. Every `Port` inside a `Ports` is valid by
construction, so "find the first valid port" collapses to "find the first port". And
`management()` returns `Port | undefined`, a declared absence that every caller
narrows — never a `0` sentinel that smuggles validity back in-band. Absence that is
exceptional would throw instead; the TypeScript rule is that `undefined` is a
declared absence and never a disguised failure (`R2-self-validating-types.md`).
Types are erased, so the compiler never runs `parsePort`: `readonly` closes
assignment after construction, and the factory is the only production site that
spells a `Port` literal — R2 Q1 greps for the others.

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `firstNamed`, `first` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to a shared `src/networking/` module
(rung 3 of `R4-helper-placement.md`). The wire adapter `parsePorts` knows the
Kubernetes DTO, so it stays with the feature. The feature policy stays home as a
two-line storified function beside the hook that uses it:

```typescript
const WEKA_API_PORT = 'weka-api'

export function managementPort(ports: Ports): Port | undefined {
  return ports.firstNamed(WEKA_API_PORT) ?? ports.first()
}
```

Teaching point: **promote only the domain-generic parts.** The `WEKA_API_PORT`
constant is feature policy and stays in the feature — a shared module that knows one
feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `managementPort()` meant rendering the page over an MSW fixture of
the whole service response — mounting a route to check a range predicate. After, the
logic is a leaf and its rung-0 unit tests (the composition ladder's bottom rung — see
@testing) are array literals against `Ports`; no render, no provider, no handler:

```typescript
describe('Ports', () => {
  it('prefers the named port', () => {
    const api = parsePort('weka-api', 14000)
    const web = parsePort('http', 80)

    expect(new Ports([web, api]).firstNamed('weka-api')).toBe(api)
  })

  it('rejects an out-of-range port number', () => {
    expect(() => parsePort('weka-api', 70000)).toThrow(/out of range/)
  })
})
```

### The opposite failure: don't over-extract

```typescript
// ❌ Ceremony, not a type: no rule, no behaviour — every number is as valid as any other.
type ReplicaCount = number

// ❌ A brand with no validating constructor: every call site casts, nothing checks.
type DeviceName = string & { readonly __brand: 'DeviceName' }

class Name { // ❌ the only "method" unwraps
  constructor(private readonly value: string) {}

  toString(): string {
    return this.value
  }
}
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the `number`; if a name is wanted, a well-named
variable or a non-exported helper in the same module is the whole answer
(`R4-helper-placement.md`, rung 1). A bare alias is erased and admits every literal,
and a brand without a factory admits every `as DeviceName`, so neither earns anything
on the invariant line either. Deep worked rejection with the cheaper alternatives:
`../examples/overabstraction-cidr.md`.

## Design guidance

A primitive should become a type when it has validation rules, has behavior attached,
represents a domain concept, is used in multiple places, or when passing an invalid
value would be a bug. When the call is not obvious, score it.

### Juiciness scoring

This scorecard lives here and only here — other rules and skills cite it, never
restate it.

**Behavioral (rich behavior):**
- Complex validation (regex, ranges, business rules): +3
- Multiple meaningful methods (≥2): +2
- State transitions/transformations: +2
- Format conversions: +1

**Structural (organizing complexity):**
- Parsing unstructured data into fields: +3
- Grouping related data that travels together: +2
- Making implicit structure explicit: +2
- Replacing a flat container of primitives that crosses a function boundary: +2
- Replacing a nested container (a container inside a container, a tuple holding more
  than single primitives): +3

**Usage (simplifies code):**
- Used in 5+ places: +2
- Used in 3-4 places: +1
- Significantly simplifies calling code: +1
- Makes tests cleaner: +1

**Invariant and vocabulary (what the type owns for the compiler and the reader):**
- Makes an invalid state unrepresentable — once a value exists it is valid for its
  whole lifetime, so a sentinel, a defensive re-check or a second validating copy
  downstream is deleted. Earned only when the whole lifetime holds: the construction
  path (`R2-self-validating-types.md`: internal fields behind a validating
  constructor, the default-constructed value either valid or never escaping, no in-package literal
  around the constructor) and the paths after it (`R12-mutation-discipline.md`: no
  setter without the constructor's checks, no internal slice or map escaping by
  reference). A bare alias of the primitive admits every literal and its default value
  and earns nothing: +2
- Gives the story a noun it needs — a loop, a flag pair or a repeated predicate at
  the call sites is really an operation on this concept and becomes a named method: +2

Both score 0 for a wrapper whose every literal is as valid as any other and whose
only method unwraps; that is the trap below, not a type.

**Verdict:**
- Score ≥4: HIGH priority — clear win, create the type.
- Score 2-3: MEDIUM priority — judgment call, present to the user.
- Score 0-1: LOW priority — do not create the type; that is over-engineering.

### The over-abstraction trap

The failure mode symmetric to primitive obsession is wrapping a primitive that has
nothing to own: no validation, no invariant, one method that merely unwraps. The
honest test: is `x.Field.IsSet()` *significantly* clearer than a well-named field or
accessor? If the real need is controlled mutation rather than validation or logic,
private fields with accessors beat a wrapper type. Deep worked case — the tried
extraction, the rejection rationale, and the cheaper alternatives:
`../examples/overabstraction-cidr.md`.

### Containers of primitives

Primitive obsession has a second form, one level up: a built-in container — a map, a
list, a set, a tuple — whose parameters are primitives. A map from string to string,
a pair of a mapping and a string. Such a value is a *shape*, not a concept: its type
says how the data is stored and nothing about what the data means. Three tiers decide
the verdict:

1. **Flat, local, named.** One container of primitives, built and read inside one
   function, under a telling name (`namesByUserID`, `header`). Not a finding. The
   variable name carries the meaning, and no other code sees the shape. This is the
   cheaper alternative the skeptic ships when a container type scores low.
2. **Flat, crossing a boundary.** The same container returned from a function or
   accepted as a parameter. A signature cannot carry the meaning the way a variable
   name does, so read every receiver and list what it *does* with the value: a
   lookup by key, a membership test, a length check, a write, a loop that filters by
   key or value and pulls a part out. Each operation is a method of a type that does
   not exist yet. The filtering loop is the strongest lead — "walk the headers, keep
   the one named Authorization, strip the Bearer prefix" is `headers.authToken()`
   already written, missing only its name and its owner. Two or more such operations,
   or two or more receivers, and the container is a hidden abstraction (Tell, don't
   ask — `../maxims.md`; the loop is also R3's "extracted steps want owners"). A
   pure pass-through under a telling parameter name is not a finding.
3. **Nested.** A container inside a container, or a tuple holding anything beyond
   single primitives: a map of maps, a map from string to a list, a pair of a
   mapping and a string. Always a finding, whatever the receivers do. The inner shape
   already *is* a type; it only has no name. A single collection *of a domain type*
   (a list of ports, a strategy map of handlers keyed by an enum —
   `R11-conditional-dispatch.md`) is not nesting: its element has a name.

The move is **Name the Container** (Fix pattern below). The new type is usually
vocabulary, not a validated value: a wrapper around a mapping with named queries has
no invariant to check, so `R2-self-validating-types.md` asks nothing of its
constructor beyond copying the container in (`R12-mutation-discipline.md`). Score
it like any type: the receivers' operations are its methods and earn the scorecard's
"noun the story needs" points.

### Placement

A juicy type must also land in the right package — feature-scoped versus
domain-generic. That decision is `R4-helper-placement.md`; the canonical example's
Stage 2 shows it applied.

## Fix pattern

- **Replace Primitive with Domain Type**: introduce `ParseX(raw)`, returning the value
  or an error (`R2-self-validating-types.md`); migrate call sites so raw values cross into `X`
  exactly once, at the boundary.
- **Extract Collection Type**: when logic loops over `[]primitive` or `[]DTO`, or
  walks a map with a filter, wrap the container (`type Ports []Port`) and move the
  loop into a named query method.
- **Replace Sentinel with Declared Absence**: `return 0` / `return ""` meaning
  absence/invalidity → a declared absence result, or an error.
- **Name enum strings**: `if status == "READY"` → `type Status string` with
  `const StatusReady Status = "READY"`. The same move owns a string *assigned* from a
  fixed set of literals: `scheme := "http"; if tls { scheme = "https" }` written in two
  functions is a two-value enum with no name, and the fix is `type Scheme string`, its
  two constants, and one constructor from the flag (`SchemeFor(tls bool) Scheme`) —
  never a private helper that returns the same bare string, which dedupes the
  decision and keeps the primitive.
- **Introduce Parameter Object** (Fowler): the same group of parameters traveling
  through multiple signatures (`host string, port int, useTLS bool`) becomes one
  type — that is the scorecard's "grouping related data that travels together" made
  concrete. Prefer passing the whole object over re-exploding its fields at the next
  call (Preserve Whole Object).
- **Name the Container**: a nested container, or a flat container of primitives that
  crosses a function boundary and is operated on by its receivers, becomes a named
  type that holds the container, with the receivers' lookups, filters and loops as
  its named methods (see "Containers of primitives" above for the three tiers). A
  tuple result is this move in its smallest form: the pair gets a name and each
  element gets a field name — Introduce Parameter Object applied to a result. Never a
  bare alias of the container with no method: that is the over-abstraction trap, and
  the cheaper alternative for a flat container inside one function is a telling
  variable name.
- **Over-abstraction found instead?** Apply the cheaper alternative — better naming,
  or private fields + accessors — per `../examples/overabstraction-cidr.md`.
- Multi-rule refactoring procedure (sequencing extraction with storifying):
  `../skills/refactoring/reference.md`. Forward design of the new types:
  @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detect-grep: `^\s*(\} else )?if \(.*\b[a-zA-Z_.]+ (===|!==) ''|^\s*(\} else )?if \(.*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]|^\s*(\} else )?if \(!?[a-zA-Z_.]+(\.length|\.trim\(\))?\)|\{[a-zA-Z_.]+ (<=?|>=?) [0-9]`
   Detection: the check often sits second in a compound condition (`if (failed ||
   days <= 0 || days > 365)`), so the pattern reads the whole `if` line, not its
   first clause; `if (!host)` is TypeScript's emptiness check and counts, and so does
   the same predicate written as a JSX guard (`{port > 0 && port <= 65535 && <Link
   />}`), which the last alternative finds.
   Violation: an emptiness/range/format check on a parameter, a prop or a DTO field
   that names a domain concept (port, id, email, path, addr), outside a `parseX`
   factory, a type guard in `typeGuards.ts` or, where the repository has a schema
   library, a schema refinement.

2. **Is the same predicate enforced in more than one place?**
   Detect: judgment
   Detection: for each predicate found above, grep its normalized form across the
   source tree, e.g.
   `grep -rn '> 0 && .*<= 65535' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   — count hits (the predicate in a function body and its copy in a JSX condition
   are one predicate written twice). `sonarjs/no-identical-functions` marks the
   larger copies.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `string[]`,
   Detect-grep: `(===|!==) '[a-z_-]+'|case '[a-z_-]+':|^\s*let [a-z]\w* = '[a-z]+'$`
   string-literal status comparisons, format logic on a `string` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detection: the first two alternatives find enum-shaped comparisons
   (`status === 'online'`) and `switch` arms on raw strings; the third a literal
   assigned to a variable, then read whether the same variable takes a second
   literal under a condition (`let scheme = 'http'; if (tls) scheme = 'https'`) and
   whether that pair appears in more than one function; inspect the diff for loops
   whose body interprets a primitive. `sonarjs/no-duplicate-string` marks the
   literal repeated three times. A `kind: 'email' | 'slack'` union names the set
   but carries no behavior; it scores like the bare string until a
   `Record<Kind, …>` or a function keyed by it owns the behavior.
   Violation: behavior attached to a bare primitive where a named method on a type
   (an `as const` enum with functions over it, a factory-built `readonly` type)
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detect-grep: `return (0|''|""|-1|null|undefined)\s*(//.*)?$|\bas [A-Z][A-Za-z]*\b|!\.|@ts-expect-error`
   Detection: read each hit's signature: the hit is a sentinel when the return type
   promises a real value (`: Device`, `: number`) and the body returns `-1`, `''`,
   `0` or `null` for the missing case. `tsc` rejects `return null` from a `: Device`
   function under `strict`, so that form arrives silenced — a `find(...)!`, an
   `as Device`, a `@ts-expect-error` on the line — and the silence is the same hit,
   which is why the last three alternatives find the cast, the non-null assertion
   and the directive; `-1`, `''` and `0` type-check against `number` and `string`,
   which is why the first exists. With `noUncheckedIndexedAccess` off, `items[0]`
   is typed `T` and a missing element is a silent `undefined` — the sentinel in its
   configuration form; the hunter reads `tsconfig` once to know which. A
   `: X | undefined` signature is a declared absence and is not this question, as
   long as the `undefined` means "not there" and never "it failed" (R2 Q5 owns that
   line). A trailing comment (`return 0 // sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires `X | undefined` for a normal
   absence, or a thrown error for a failure; never `[X, boolean]`.

5. **Do the same parameters travel together across signatures?**
   Detect-grep: `^\s*(export )?(async )?function [A-Za-z_][A-Za-z0-9_]*\([^)]*,[^)]*,|= (async )?\([^)]*,[^)]*,[^)]*\)(: [^=]+)? =>`
   Detection: the pattern finds a function or arrow with three or more parameters
   on one line; Prettier wraps a longer signature one parameter per line, and
   `max-params` (4) marks those. For each changed function with ≥3 parameters, grep
   the source tree for the same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'function .*host: string.*port: number' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`.
   The React form is prop drilling: the same trio (`clusterId`, `tenantId`,
   `region`) declared in three components' props and forwarded by each —
   `grep -rn 'clusterId={' --include='*.tsx' --exclude-dir=node_modules .` per
   member, then read whether the same component passes all of them on.
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detect-grep: `^(export )?type [A-Z][A-Za-z0-9]* = (string|number|boolean)( & \{| *$)|^(export )?class [A-Z][A-Za-z0-9]* \{`
   Detection: the pattern finds a bare alias of a primitive, a brand and a class
   declaration. Count the type's methods (`grep -cE '^  [a-zA-Z]+\(.*\)(: [^{]+)? \{' <file>`
   between the `class` line and its closing brace, or the functions whose first
   parameter is the type) and check whether any does more than unwrap or rename the
   primitive; score it with the scorecard above. A `type X = number`, a brand with
   no validating factory, or an `interface` with one field and no behavior scores 0
   on the invariant line: it is erased and admits every literal (every cast, for the
   brand).
   Violation: Score 0-1, or the only method is `toString()`/`valueOf()` returning
   the primitive — over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).

7. **Does a nested container appear in a signature or a field?**
   Detect-grep: `(Record|Map|Set|Array|ReadonlyArray|ReadonlyMap|ReadonlySet)<[^>]*(Record|Map|Set|Array|ReadonlyArray)<|\[\][]>]|\]\[\]|: \{ \[key: string\]:|\[[^]]*(Record|Map|Array)<`
   Detection: the pattern finds a container type whose parameter is itself a
   container — `Record<string, string[]>`, `Map<string, Set<number>>`,
   `string[][]`, `[Record<string, string>, string]`, an inline index signature
   whose value is an array — in signatures, `interface` and `type` fields, props
   and module constants. Read the hit: `readonly T[]` is one level, a
   `Record<Kind, Handler>` is a strategy map (R11), and `Promise<string[]>` or
   `useState<string[]>` wraps one collection; each is a single collection of a
   named type and is not this question.
   Violation: every remaining hit. The inner shape is a type with no name — Name the
   Container: a `readonly` object type whose fields are the elements, or a class
   holding the mapping with the receivers' queries as methods (a nested container
   is +3 on the scorecard).

8. **Does a flat container of primitives cross a function boundary?**
   Detect-grep: `\): (Promise<)?(Record<string, (string|number|boolean)>|(string|number)\[\]|Map<string, (string|number)>|\[string, string\])|\(([a-z]+: Record<string, string>|[a-z]+: string\[\])|^\s+readonly [a-zA-Z]+\??: (Record<string, (string|number)>|(string|number)\[\])`
   Detection: the pattern finds a return type that is a container of primitives, a
   parameter typed as one, and a prop declared as one. For each hit, read every
   receiver and list what it does with the value: `[key]`, `.get(`, `in`,
   `.length`, a write, a `for … of` over `Object.entries(…)` or a `.filter(` /
   `.find(` that filters by key or value and extracts a part (grep the receivers
   for `Object\.(entries|keys)\(` and `\.(filter|find|some)\(` on the name). The
   filtering loop is the strongest lead: it is a method already written. The React
   form is prop drilling of the shape: the same `Record` or array prop declared in
   two components' props and handed through, each reading a part of it. A hit
   already reported under Q7 belongs to Q7; a `string[]` of class names handed to
   `clsx` and `children` are not this question.
   Violation: two or more such operations, or two or more receivers, and no type owns
   them — a hidden abstraction; Name the Container (flat-crossing is +2 on the
   scorecard, and each named operation earns the "noun the story needs" points). A
   pass-through under a telling parameter name, or a container built and read inside
   one function, is not a finding.
