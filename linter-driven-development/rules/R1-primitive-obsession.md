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

The shape below is the same in every language; the Go plugin's version is the real
pull request it was taken from. A service wraps a wire-level description of a network
service and must pick the management port: prefer the port named `weka-api`, else fall
back to the first valid port.

### Before

```text
managementPort(service):
    for each port in service.ports:
        if port.name == "weka-api" and port.number > 0 and port.number <= 65535:
            return port.number
    for each port in service.ports:
        if port.number > 0 and port.number <= 65535:
            return port.number
    return 0
```

Four defects in twelve lines:

- The validity rule `> 0 and <= 65535` is duplicated across the two loops — two
  copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic lives on a wire DTO, so it is testable only by constructing a whole
  service object around it.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none".

### Stage 1 — self-validating types with constructors

```text
Port                         # fields are internal; the constructor is the only way in
    name, number
parsePort(name, number):     # the value, or a failure that names the port and the range
    if number <= 0 or number > 65535: fail "port <name>: <number> out of range 1-65535"
    return Port(name, number)

Ports                        # a collection of valid Port values
parsePorts(wire):            # drops invalid wire entries — a documented decision that
    for each entry in wire:  # mirrors the original skip-and-fall-back behavior: an
        parsePort(...) ok?   # invalid port was never chosen before; now it never exists
            keep it
Ports.firstNamed(name):      # the port, or an explicit "absent"
Ports.first():               # the port, or an explicit "absent"
Ports.management():          # prefers "weka-api", else the first valid port
    return firstNamed("weka-api") or first()
```

The payoff, stated plainly: notice what was **not** written. There is no `isValid()`
method and no validity loop anywhere. Self-validation does not move the range check
somewhere tidier — it **deletes the concept of a maybe-invalid port from downstream
logic**. Every `Port` inside a `Ports` is valid by construction, so "find the first
valid port" collapses to "find the first port". And `management()` returns the port
or an explicit absence — never a `0` sentinel that smuggles validity back in-band.
How "the value or a failure" and "the value or absent" are spelled — an error
result, an exception, an optional type — follows the repository's language.

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `firstNamed` and `first` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to a shared `networking` package
(rung 3 of `R4-helper-placement.md`). The wire adapter `parsePorts` knows the DTO, so
it stays with the feature. The feature policy stays home as a two-line storified
method: `management()` becomes `firstNamed(managementPortName) or first()` on the
service, with the `"weka-api"` constant beside it.

Teaching point: **promote only the domain-generic parts.** The `"weka-api"` constant
is feature policy and stays in the feature — a shared package that knows one
feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `managementPort` meant constructing a whole service fixture —
building a wire object to check a range predicate. After, the logic is a leaf and its
rung-0 unit tests (the composition ladder's bottom rung — see @testing) are literal
lists of ports: build two ports through `parsePort`, put them in a `Ports`, assert
which one `firstNamed` returns. No big-object construction.

### The opposite failure: don't over-extract

```text
ReplicaCount                 # ❌ ceremony, not a type: no rule, no behavior —
    wraps one integer        #    the only method unwraps it
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the plain integer; if you want a name, a
well-named variable or an internal helper in the same package is the whole
answer (`R4-helper-placement.md`, rung 1).

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
- Replacing an untyped map: +2

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

### Placement

A juicy type must also land in the right package — feature-scoped versus
domain-generic. That decision is `R4-helper-placement.md`; the canonical example's
Stage 2 shows it applied.

## Fix pattern

- **Replace Primitive with Domain Type**: introduce `ParseX(raw)`, returning the value
  or an error (`R2-self-validating-types.md`); migrate call sites so raw values cross into `X`
  exactly once, at the boundary.
- **Extract Collection Type**: when logic loops over `[]primitive` or `[]DTO`, wrap
  the slice (`type Ports []Port`) and move the loop into a named query method.
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
- **Over-abstraction found instead?** Apply the cheaper alternative — better naming,
  or private fields + accessors — per `../examples/overabstraction-cidr.md`.
- Multi-rule refactoring procedure (sequencing extraction with storifying):
  `../skills/refactoring/reference.md`. Forward design of the new types:
  @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

The detection below names what to search for; build each search over the language's
source files (`detected-language source`) with the repository's own grep or ripgrep, and read the
hits — a pattern finds candidates, the question decides.

1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: in the changed files, find conditionals that compare a parameter or DTO
   field against an empty string, a number bound or a format (`== ""`, `<= 0`,
   `> 65535`, a regex match) — the check often sits second in a compound condition
   (`if failed or days <= 0 or days > 365`), so read the whole condition, not its
   first clause.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, search its normalized form across the
   package or module (`> 0` and `<= 65535` together, the same regex, the same
   emptiness check on the same field name) — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over a list of
   strings, string-literal status comparisons, format logic on a string field, a
   variable assigned one of a fixed set of literals under a flag.
   Detection: search for enum-shaped comparisons (`== "READY"`, an upper-case string
   literal compared against a field); search for a lower-case literal assigned to a
   variable, then read whether the same variable takes a second literal under a
   condition (`scheme = "http"; if tls: scheme = "https"`) and whether that pair
   appears in more than one function; inspect the diff for loops whose body interprets
   a primitive.
   Violation: behavior attached to a bare primitive where a named method on a type
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: in the changed files, find `return 0`, `return ""`, `return -1` and
   `return null` (the language's missing value), then read each hit's signature:
   the hit is a sentinel when the signature promises a real value and has no separate
   absence or failure result (a missing value returned where a device is expected is
   one; the language's "no error" result is not). A trailing comment (`return 0 //
   sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires an explicit absence result (an
   optional, a found flag) or a failure.

5. **Do the same parameters travel together across signatures?**
   Detection: for each changed function with ≥3 parameters, search the package or
   module for the same parameter-name pair/trio in other signatures (`host` and `port`
   side by side in a second signature, say).
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detection: count its methods and check whether any method does more than unwrap or
   rename the primitive; score it with the scorecard above.
   Violation: Score 0-1, or the only method is `return <primitive>(x)` —
   over-abstraction; the finding must cite the cheaper alternative (better naming, or
   private fields with accessors).
