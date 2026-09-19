# Anti-IF Dispatch Case: One Decision, One Owner

Demonstrates: R11 (edges into R1, R2, R6)
{{include "examples/language-note.md"}}
A worked study of the R11 moves on a realistic alert-notification slice: a string
discriminator inspected in three files becomes an interface chosen once at the
boundary; a single-function variance becomes a strategy map instead; and the inverse
case — where the skeptic kills the extraction and the switch *stays* — is worked to
its cheaper alternative. The compact excerpt lives in
`../rules/R11-conditional-dispatch.md`; this file is the full case law.

## The disease: a decision with three owners

{{include "examples/anti-if-dispatch/disease.md"}}

Why this is a defect and not a style choice:

{{include "examples/anti-if-dispatch/disease-defects.md"}}

## Move 1 — Replace Duplicated Switch with Interface Dispatch

{{include "examples/anti-if-dispatch/move-1.md"}}

**R6 check, answered explicitly:** this interface is *earned* — it has three
production implementations on day one. R6 forbids interfaces whose only second
implementer is a test double; a dispatch interface born with one variant "for the
future" fails that test and should stay a switch until the second variant is real.

### The testing payoff

{{include "examples/anti-if-dispatch/move-1-tests.md"}}

## Move 2 — Replace If-Chain with Strategy Map

Not every variance deserves an interface. Suppose only *rendering* varies by an
output format, in one behavioral dimension:

{{include "examples/anti-if-dispatch/move-2-before.md"}}

One behavior → a map, not three types:

{{include "examples/anti-if-dispatch/move-2-after.md"}}

## Move 3 — the rejection: when the switch stays

The skeptic's side of R11, worked honestly. The same codebase has this:

{{include "examples/anti-if-dispatch/move-3-switch.md"}}

{{include "examples/anti-if-dispatch/move-3-scoring.md"}}

Verdict: **REFUTED.** The extraction would turn 12 readable lines into three files
and an interface for zero deletion — no duplicated switch exists to delete. The
cheaper alternative is R11's sanctioned form, **Keep the Single Exhaustive Switch**:

{{include "examples/anti-if-dispatch/move-3-kept.md"}}

**The dividing line, restated:** dispatch is bought with the *deletion of duplicated
decisions*. Three sites collapsed to one boundary — clear win (Move 1). One
single-dimension variance — a map (Move 2). One site, trivial variance — the switch
stays, made exhaustive (Move 3). If nothing gets deleted, the abstraction is
ceremony.
