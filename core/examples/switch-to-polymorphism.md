# Switch-to-Polymorphism Case: The Ever-Growing Export Switch

Demonstrates: R11, R6 (edges into R3)
{{include "examples/language-note.md"}}
Adapted from production code. `../examples/anti-if-dispatch.md` works R11's canonical
disease — a *raw* discriminator (a kind string) inspected at three sites. This case
is the type-switch sibling: a value that is **already polymorphic** (an interface,
dispatched once at construction) gets *un-dispatched* by a type switch that unpacks
its fields. The decision was made when the value was built; the switch asks it again.

Two things make this case worth its own file. First, the *obvious* refactoring
(extract each case body into a helper) is a trap — it shrinks the function but
preserves the disease. Second, the rejection axis here is different from
`anti-if-dispatch.md`'s Move 3: there the skeptic kills an extraction on juiciness
(one site, trivial variance); here the counter is **dependency direction** — a
situation where the dispatch move is physically unavailable and the switch is the
honest answer.

## Before — the hump that grows forever

{{include "examples/switch-to-polymorphism/before.md"}}

Three defects, and only one of them is size:

{{include "examples/switch-to-polymorphism/defects.md"}}

## The tempting wrong fix — extract each case body

The reflexive move is Extract Function per case:

{{include "examples/switch-to-polymorphism/wrong-fix.md"}}

The function gets shorter and each case reads better — and nothing real changed.
The switch still exists, still grows a case per destination forever, and a
forgotten case is still a silent no-op. This is the ceiling of function
extraction, not the fix.

The falsifying question that breaks the frame: **why are we switching on type and
extracting data at all?** A type switch whose cases all do the same *kind* of work
(map my fields onto that struct) is behavior asking to live on the types. The
cased types already share an interface — the switch is a hand-rolled vtable.

## After — the interface owns the behavior

Add the fill behavior to the interface the concrete types already implement:

{{include "examples/switch-to-polymorphism/after.md"}}

## The payoffs

{{include "examples/switch-to-polymorphism/payoffs.md"}}

## Fill, don't construct

{{include "examples/switch-to-polymorphism/fill-not-construct.md"}}

## The boundary counter — when the switch must stay

This move has one precondition: **the package that owns the case types must also
legitimately own the output format.** Here both `Patch` and `updateExportRequest`
live in one package (a client whose API surface and wire format are the same
concern), so the method is natural.

When the patch types live in a shared API package and the wire request is one
consumer's private detail, the move is unavailable and wrong:

{{include "examples/switch-to-polymorphism/boundary-physics.md"}}

{{include "examples/switch-to-polymorphism/boundary-verdict.md"}}

Note this rejection is orthogonal to the juiciness rejection in
`anti-if-dispatch.md` Move 3: there the extraction *could* be written but isn't
worth it; here it *cannot* be written where it belongs, at any price.

The decision test, two questions in order:

1. *Why am I switching on type and unpacking fields?* → the behavior wants to live
   on the types (R11).
2. *Does the types' package own this output format?* → yes: interface method, the
   switch dies. No: thin dispatch switch, and the boundary earns its keep.
