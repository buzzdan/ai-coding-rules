# R3 — Storifying (Single Level of Abstraction)

## Principle

A top-level function reads like a story: every step is a named call at the same
conceptual level, and the whole flow is graspable at a glance. Method calls never mix
with string/index manipulation in the same body. A comment that names a block of code
is a function name waiting to be extracted.

## Why

Mixed abstraction levels bury the business flow: the reader must mentally execute
low-level details to reconstruct what the function *means*, and the linter measures
that cost as cognitive complexity. Steps that are inlined instead of named cannot be
tested independently — the only test surface is the whole tangle, with its I/O and
state attached. Storifying does two things at once: the orchestration becomes a
readable, low-complexity narration, and the extracted steps become named units that
either stay as focused helpers or graduate into leaf types
(`R1-primitive-obsession.md`) with 100% unit coverage. Most of a codebase's logic
should end up in those leaves; the story functions above them should be thin.

## Canonical example

Production-shaped code from a settings hook. `alignIpConfig` must pick usable IPv4
and IPv6 addresses from a device's reported network interface and align the `Config`
form state with them.

### Before

```typescript
function alignIpConfig(config: Config, iface: ReportedInterface): Config {
  if (iface.addrs.length === 0) {
    throw new ConfigError(`network addr: ${iface.name} reported no addresses`)
  }
  const draft = { ...config }
  let ip4Added = false
  let ip6Added = false
  for (const a of iface.addrs) {
    if (a.scope !== 'global') {
      continue
    }
    if (a.family === 'inet6') { // validate IP6
      if (ip6Added) { // already added. skip
        continue
      }
      if (!parseIp6(draft, a)) {
        throw new ConfigError(`IP6 '${draft.ip6}' address is not valid`)
      }
      ip6Added = true
      continue
    }
    if (ip4Added) {
      continue // already added. skip
    }
    if (!parseIp4(draft, a)) {
      throw new ConfigError(`IP4 '${draft.ip4}' address is not valid`)
    }
    ip4Added = true
  }
  if (!ip4Added && !ip6Added) {
    throw new ConfigError(`IP address is not valid. IP4: '${draft.ip4}', IP6: '${draft.ip6}'`)
  }
  return draft
}
```

Thirty-three lines, cognitive complexity 18: a discriminant check, boolean flags
tracking loop state, three nesting levels, `continue`-driven control flow — and the
actual policy (collect one IPv4 and one IPv6, then reconcile with the form state) is
nowhere stated. The comments `// validate IP6` and `// already added. skip` are
naming blocks that want to be functions. `parseIp4`/`parseIp6` write into `draft` —
the name hides the side effect.

### After

```typescript
function alignIpConfig(config: Config, iface: ReportedInterface): Config {
  if (iface.addrs.length === 0) {
    throw new ConfigError(`network addr: ${iface.name} reported no addresses`)
  }

  const ipConfig = collectIpConfig(iface.addrs)

  return alignIps(config, ipConfig)
}
```

Read aloud: get addresses → collect them into an IPConfig → align config with what
was collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals; `collectIpConfig`
is a `filter` over the global addresses and two `find`s, first IPv4 and first IPv6,
so the two boolean flags have no reason to exist. The mutating helpers were renamed
`alignIpv4`/`alignIpv6` — "align" admits the side effect that "parse" hid. In a
React repository the fat function is as often a component body or an effect: the
same `let` flags and nested `if`s inside a `useEffect`, or a render tree whose
ternaries nest three deep; the extracted leaf is a pure function or a custom hook,
and `react/no-unstable-nested-components` fires when the extraction is done in place
inside the component instead. Full worked study, including the leaf type and the
test payoff: `../examples/storify-leaf-type.md`.

## Design guidance

- **One conceptual level per function.** A function states *what* happens; the *how*
  lives one level down behind a named call. If you can explain the flow in 3–5 steps,
  the code should be those 3–5 calls.
- **Comments naming blocks are extraction orders.** `// validate input`,
  `// build query`, `// already added. skip` — extract a function and name it after
  the comment; the comment then disappears because the name carries it.
- **Extracted steps want owners.** When an extracted step operates on data it could
  own, don't leave it a free function — make it a method on a type (a leaf,
  `R1-primitive-obsession.md`); where that type then lives is
  `R4-helper-placement.md`. Storifying is how leaf types are discovered.
- **Boolean flags tracking loop state** (`addrIP4Added`, `isClusterCIDRSet`) signal a
  collection or domain type waiting to absorb the loop.
- **Honest naming.** A name must reveal side effects: `align`/`upsert`/`set` mutate;
  `parse`/`validate`/`is` must not. A `validateX` that mutates is a storifying bug
  even if the flow reads well.
- **Size and shape limits**: functions under 50 LOC, at most 2 nesting levels; deeply
  nested if/else becomes early returns or extracted functions.

## Fix pattern

- **Extract Function named after the comment**: each commented block becomes a call;
  the story is what remains.
- **Extract Leaf Type**: when extracted steps share data (loop flags, accumulated
  state), move them onto a new type — see `../examples/storify-leaf-type.md` for the
  full move, and `R1-primitive-obsession.md` to score whether the type is warranted.
- **Replace Nesting with Early Returns**: invert conditions, return early, flatten to
  ≤2 levels.
- **Split Phase** (Fowler): when one function interleaves decoding/parsing with
  computation — wire fields and business decisions in the same body — split it into
  phase 1, which parses input into an intermediate domain structure, and phase 2,
  which computes over that structure alone. The intermediate type is a leaf
  candidate (score per `R1-primitive-obsession.md`); when phase 1 validates, it is a
  `ParseX` constructor and the move collapses into `R2-self-validating-types.md`.
  Split Phase differs from Extract Function: extraction names a step in place, Split
  Phase introduces a data structure *between* the steps so each phase can change —
  and be tested — without the other.
- **Honest Rename**: mutating helpers get mutating names (`parseIP4` → `alignIPv4`).
- Multi-rule sequencing (storify first or extract first, and when to stop):
  `../skills/refactoring/reference.md`. Forward design of the new types:
  @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does any changed function exceed the size/shape limits?**
   Detection: run the complexity rules (`sonarjs/cognitive-complexity`,
   `sonarjs/cyclomatic-complexity`, `sonarjs/max-lines-per-function`,
   `sonarjs/nested-control-flow`; `react/no-unstable-nested-components` for a
   component declared inside another) with `npx eslint` on the changed files; or
   count — `awk '/^(export )?(async )?function /,/^}/' <file>` per function for LOC,
   eyeball nesting depth. Nested JSX ternaries (`a ? <X /> : b ? <Y /> : <Z />`)
   are nesting levels, and a component past `max-lines-per-function` is the fat
   function.
   Violation: > 50 LOC or > 2 nesting levels — the function is doing more than
   narrating.

2. **Does one body mix abstraction levels?**
   Detection: read each changed function and list its statements' altitudes: a named
   function/hook call is high; string slicing, `.split()`, index arithmetic,
   `typeof`/`in` checks, and protocol details (`response.json()`, header parsing,
   `URLSearchParams` decoding) are low.
   Violation: both altitudes in the same body — e.g. `line.split(',', 2)` three
   lines from a business decision, or a date-format call beside a JSX branch. Cite
   the two lines.

3. **Do block comments narrate sections inside a function body?**
   Detection: `grep -nE '^\s+// |\{/\* ' <file>` within function and component
   bodies (not the JSDoc above a declaration, not an `eslint-disable` or
   `@ts-expect-error` directive); `// --- filters ---` and `{/* header */}` in a
   render tree count.
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function, or in a render tree a component, named
   after the comment (placed per `R4-helper-placement.md`).

4. **Do boolean flags track state across a loop?**
   Detection: `grep -nE '^\s+let [a-zA-Z_]+ = (false|true)$' <changed files>` near
   `for`, `while` and `.forEach` loops; look for flags set inside the loop and read
   after it, and for a `return` inside a `forEach` callback meant as a `break` — it
   is not one, and the flag it sets is the loop state in disguise.
   Violation: flag-driven loops — a collection/domain type (or a `find`/`some`/
   `reduce` on it) should absorb the loop (see
   `../examples/storify-leaf-type.md`).

5. **Does any function name lie about side effects?**
   Detection: for each `parse*`/`validate*`/`is*`/`get*` function in the diff,
   check the body for assignments to a parameter's properties, a `.push()`/
   `.splice()`/`.sort()` on an argument, a state-setter call, or a `ref.current =` write.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation; a `getX` that calls a state setter is the same
   finding with a worse disguise.
