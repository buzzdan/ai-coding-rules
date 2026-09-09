# R11 — Conditional Dispatch (Anti-IF)

## Principle

A conditional that asks what a value *is* — a type switch, or a switch/if-chain on a
kind/status/mode discriminator — may exist **once**. The second copy of that
discriminator is a missing polymorphic type: the variants want to be implementations
of an interface (or entries in a dispatch map), chosen once at the boundary, so
downstream code *tells* the value what to do instead of asking what it is. One
well-placed, exhaustive switch is not a defect; a duplicated one always is.

## Why

Every `if (new kind) { new code }` doubles the execution paths through the function —
five conditionals means 32 paths to reason about and test. Worse, kind-switches
replicate: the same `switch msg.Channel` appears in send, validate, format, and retry
code, and adding a variant means finding and editing every copy — the one you miss is
the bug that ships. The compiler cannot help: an if-chain has no notion of
completeness, so a forgotten variant falls through silently. Dispatching once —
constructing the right implementation at the boundary (`R2-self-validating-types.md`
owns "validate once at the edge"; this rule is its behavioral twin: *decide* once at
the edge) — collapses N switches into one construction site, makes each variant a
leaf that unit-tests in isolation, and turns "add a variant" into "add a type" with
zero edits to existing code. This idea comes from the Anti-IF movement (Cirillo,
2007): the enemy is not `if`, it is the duplicated kind-conditional.

## Canonical example

{{include "rules/R11/canonical-example.md"}}

## Design guidance

- **The trigger is duplication, not existence.** Count the sites that inspect the same
  discriminator. One site — keep the switch (make it exhaustive). Two or more —
  the variants are a type family; dispatch.
- **Decide once, at the edge.** The one legitimate inspection of the raw discriminator
  is the constructor/parser that picks the implementation
  (`R2-self-validating-types.md` for the constructor discipline). Downstream code
  holds the chosen behavior and never re-asks. The corollary: a type switch over an
  interface the same package owns is always a re-ask — the decision was made when
  the value was constructed; cases that unpack the variants' fields are behavior
  asking to live on the interface (`../examples/switch-to-polymorphism.md`).
- **Dispatch requires owning the output.** An interface method can only be written
  in the package that declares the interface, and it cannot reference another
  package's unexported types. When the switch's output format belongs to a consumer
  (a private wire request in a client package) and the variants live in a shared API
  package, the move is unavailable — and forcing it (exporting the wire type,
  per-consumer `fill<X>Request` methods on domain types) inverts the dependency.
  There the switch is the honest boundary tax: shrink it to pure dispatch (one
  converter call per case) and stop. Worked counter-case, including the fill-style
  method shape for when the move IS available:
  `../examples/switch-to-polymorphism.md`.
- **Interface vs strategy map.** Variants with several behaviors or state → interface
  with one type per variant. Variants that differ by a single function → a map
  (`var renderers = map[Format]func(Alert) string{...}`) — a map lookup with a
  comma-ok check is a dispatch, not a conditional. Either way the decision has one
  owner.
- **Null object over nil-checks.** A scattered `if x != nil { x.Log(...) }` is the
  same disease with two variants. Construct a do-nothing implementation
  (`type NopLogger struct{}`) once; delete every guard. (R2's "nil is not a value"
  covers the constructor side.)
- **Flag arguments are two functions.** `func Render(a Alert, short bool)` forces
  every caller through a conditional the callee then unpicks. Split into `Render` and
  `RenderShort`, or make the variant a type.
- **A kept switch must be exhaustive.** When one switch over a closed enum stays
  (single site, trivial variance), name the enum (`R1-primitive-obsession.md`,
  "Name enum strings"), drop the `default`, and let the `exhaustive` linter prove
  completeness — the linter then does what the if-chain never could: fail the build
  when a variant is added but not handled.
- **The over-abstraction trap, dispatch edition.** An interface with one production
  implementation is R6's territory; two trivial implementations behind one switch at
  one site score LOW on R1's juiciness scorecard — keep the conditional. Conditionals
  on *state/values* (`if n > threshold`, `if err != nil`, guard clauses per
  `R3-storifying.md`) are healthy control flow, not dispatch — this rule never
  touches them.

## Fix pattern

- **Replace Duplicated Switch with Interface Dispatch**: define the interface from the
  union of what all copies of the switch do (one method per switching site is a
  starting point, then collapse); one type per variant; move each `case` body into
  its variant; introduce `ParseX(raw) (X, error)` as the single decision point and
  migrate call sites to method calls. When the dispatch produces an output that
  carries fields the variants don't own (shared name/TLS on a wire request), give
  the interface a fill-style method (`fillUpdate(req *T)`) instead of a constructor —
  the caller owns the shared fields, each variant fills its own
  (`../examples/switch-to-polymorphism.md`).
- **Replace If-Chain with Strategy Map**: single-behavior variance → package-level
  `map[Kind]func(...)` (or a field), comma-ok on lookup at the boundary only.
- **Introduce Null Object**: absent-collaborator nil-checks → a no-op implementation
  constructed by default; delete the guards.
- **Split Flag Argument**: boolean/enum parameter that selects behavior → two named
  functions, or a variant type chosen by the caller's constructor.
- **Keep the Single Exhaustive Switch**: one site, closed enum → named enum type (R1),
  no `default`, `exhaustive` linter enforcing completeness. This is the rule's
  sanctioned form — record it as the decision, not a TODO.
- New types this creates must pass R1's juiciness scorecard, land per
  `R4-helper-placement.md`, and never become test-only interfaces
  (`R6-test-only-interfaces.md`). Rejection case law — juiciness (the switch stays,
  goes exhaustive): `../examples/anti-if-dispatch.md`; dependency direction (the
  move is unavailable across the package boundary):
  `../examples/switch-to-polymorphism.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

{{include "rules/R11/falsifying-questions.md"}}
