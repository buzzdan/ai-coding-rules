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

{{include "rules/R3/canonical-example.md"}}

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

{{include "rules/R3/falsifying-questions.md"}}
