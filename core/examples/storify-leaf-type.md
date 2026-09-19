# Storify + Leaf Type Case: From Fat Function to Lean Orchestration

Demonstrates: R3, R1, R2
{{include "examples/language-note.md"}}
A real refactoring from a production codebase: a 48-line function mixing iteration,
validation, collection, and mutation becomes a 3-step story, with the juicy logic
extracted into a leaf type that unit-tests without mocks. This is the case law for
R3's core move — storifying discovers the leaf type — and for what the developer
actually shipped, including the imperfections and the next steps they left on the
table.

## The setting

{{include "examples/storify-leaf-type/setting.md"}}

## Before

{{include "examples/storify-leaf-type/before.md"}}

## The smells, named

{{include "examples/storify-leaf-type/smells.md"}}

The core problem: the juicy logic (which addresses count, how many of each family
to keep) is trapped inside an orchestration function. The fix is not to reshuffle
the fat function — it is to give that logic an owner.

## Step 1 — separate orchestration from logic

The function does three things: **collect** candidate IPs from the interface
(logic), **validate** the result (logic), **align** the config with what was found
(orchestration + logic). Collection and validation don't need `Config` at all —
that's the leaf type.

## After — the storified orchestrator

{{include "examples/storify-leaf-type/after-orchestrator.md"}}

Read aloud: get addresses → collect them into an IPConfig → align our config with
what we collected. No nested ifs, no `continue`, no boolean flags — every line at
one altitude.

## After — the extracted leaf type

{{include "examples/storify-leaf-type/after-leaf-type.md"}}

## After — the alignment side, honestly named

{{include "examples/storify-leaf-type/after-alignment.md"}}

## The test payoff

{{include "examples/storify-leaf-type/test-payoff.md"}}

## Metrics

{{include "examples/storify-leaf-type/metrics.md"}}

## Decision points

1. **Storifying discovered the type.** The extraction order was: name the steps
   (collect → validate → align), then notice that "collect" carries its own state —
   the loop flags — and give that state an owner. R3 and R1 are one move here, not
   two.
{{include "examples/storify-leaf-type/decision-points-tail.md"}}
