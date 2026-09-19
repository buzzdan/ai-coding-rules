# Over-Abstraction Case: The CIDRPresence Wrapper

Demonstrates: R1
{{include "examples/language-note.md"}}
A real refactoring where an extraction was tried, rejected, and replaced with two
cheaper alternatives. This is the case law for R1's over-abstraction trap: what a
correct refutation of a proposed type looks like.

## The setting

{{include "examples/overabstraction-cidr/setting.md"}}

Grouping them into a `CIDRConfig` domain type was a clear win (related data that
travels together, a query method that reads like English). The trap appeared one
step further: the temptation to wrap each boolean in its own type.

## The extraction that was tried

{{include "examples/overabstraction-cidr/extraction-tried.md"}}

## Why it was rejected

{{include "examples/overabstraction-cidr/why-rejected.md"}}

The rejection also identified the *real* need hiding under the proposal: **controlled
mutation**. Only the parsing code should be able to set these flags — and the wrapper
type does not deliver that (its fields were still freely settable). Naming the actual
need is what makes the cheaper alternatives findable.

## Cheaper alternative 1 — better naming

When the need is only clarity, rename and stop:

{{include "examples/overabstraction-cidr/alternative-naming.md"}}

## Cheaper alternative 2 — private fields + accessors (chosen)

{{include "examples/overabstraction-cidr/alternative-private-fields.md"}}

## The decision, tabulated

| Approach | Types | Readability | Safety | Ceremony | Verdict |
|----------|-------|-------------|--------|----------|---------|
| `CIDRPresence` wrapper | 6 | Good | Low | High | ❌ Over-abstraction |
| Public bool fields (naming) | 5 | Good | Low | Low | ⚠️ Acceptable for disciplined scope |
| Private bools + accessors | 5 | Good | **High** | Low | ✅ Chosen |

## The decision questions

Before creating a wrapper type, ask:

1. Does it have >1 meaningful method with logic — not just unwrapping?
2. Does it enforce invariants or validation?
3. Is the need actually *controlled mutation*? → private fields + accessors, not a
   wrapper.
4. Is the method call **significantly** clearer than good naming?
5. Does it hide complex implementation?

Mostly NO → use primitives with good naming, or private fields when mutation must be
controlled. (Score it with R1's scorecard; this wrapper scores 0.)

## The skeptic's operating rule

**A refutation must always propose the cheaper alternative — never just "no".**

Rejecting `CIDRPresence` was legitimate only because the rejection came with a design
that met the real need (controlled mutation) at lower cost. A bare "don't create the
type" would have left the original defect — uncontrolled mutation of the flags — in
place. The skeptic's job is therefore two moves, always together: name the need the
proposal was groping toward, then meet it more cheaply — better naming when the need
is clarity, private fields + accessors when the need is controlled mutation, and a
real type (per R1) only when the need is validation or behavior.
