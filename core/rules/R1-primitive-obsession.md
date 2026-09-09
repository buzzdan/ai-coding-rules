# R1 — Primitive Obsession

## Principle

Domain concepts must not travel as raw `string`/`int`/`bool`/`[]T`. When a primitive
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

{{include "rules/R1/canonical-example.md"}}

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
- Replacing `map[string]interface{}`: +2

**Usage (simplifies code):**
- Used in 5+ places: +2
- Used in 3-4 places: +1
- Significantly simplifies calling code: +1
- Makes tests cleaner: +1

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

- **Replace Primitive with Domain Type**: introduce `ParseX(raw) (X, error)`
  (`R2-self-validating-types.md`); migrate call sites so raw values cross into `X`
  exactly once, at the boundary.
- **Extract Collection Type**: when logic loops over `[]primitive` or `[]DTO`, wrap
  the slice (`type Ports []Port`) and move the loop into a named query method.
- **Replace Sentinel with comma-ok**: `return 0` / `return ""` meaning
  absence/invalidity → `(X, bool)` or `(X, error)`.
- **Name enum strings**: `if status == "READY"` → `type Status string` with
  `const StatusReady Status = "READY"`.
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
{{include "rules/R1/falsifying-questions.md"}}
