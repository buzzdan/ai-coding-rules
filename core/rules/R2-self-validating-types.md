# R2 — Self-Validating Types

## Principle

A type validates its own invariants in its constructor — the only way to obtain a
value — and every method thereafter trusts the receiver. Validation ownership never
sits upstream: a type that relies on callers to have validated for it is not
self-validating, whatever its fields look like.

## Why

Constructor validation makes invalid values unrepresentable. Without it, every method
must defend against bad state, forgetting one check is a latent crash, and the
defensive noise buries the actual logic. With it, {{.Nil}}-checks, emptiness checks, and
range checks vanish from the entire downstream call graph — the payoff compounds with
every method and every caller. Errors also surface at the boundary where the bad data
entered, carrying context, instead of deep in an unrelated call stack.

## Canonical example

{{include "rules/R2/canonical-example.md"}}

## Design guidance

- **Constructors are the only entry.** `ParseX(raw)` for values built from
  unstructured input, `NewX(deps)` for composed objects, each returning the value or an
  error (constructors may carry other names — any public function returning the type
  qualifies). Fields stay {{.Unexported}}: building the value directly, bypassing the
  constructor, is a hole in the type.

- **Validation ownership.** A type never relies on upstream validation. "The handler
  already checked it" is not an invariant — handlers change, new call sites appear,
  and the type outlives both. A comment reading "caller must ensure X" is the
  signature of a type that does not own itself: move that sentence into the
  constructor as code.

{{include "rules/R2/validation-ownership-example.md"}}

- **Trust composed values.** Once you hold a `Port`, it is valid — never re-check it
  downstream, and never re-validate it in a composing constructor. Each type owns
  exactly its own invariants:

{{include "rules/R2/trust-composed-example.md"}}

- **{{.Nil}} is not a value.** Never return {{.Nil}} where a real value is expected —
  return an error instead. A failure result carries the error, not a value, so that
  position is exempt. Never pass {{.Nil}} into a function; then functions do not
  check parameters for {{.Nil}}.

- **Absence is a value too.** An *optional* collaborator — a logger, a metrics sink,
  an event writer, a clock — is not a field that may be {{.Nil}} with a guard in every
  method. The default is a named do-nothing value the constructor supplies, the field
  is never {{.Nil}}, and every "if the sink is set" guard disappears. This is the Null
  Object of `R11-conditional-dispatch.md`: a real implementation that honors the
  contract by doing nothing, so no caller ever branches on a missing destination. No
  parameter accepts {{.Nil}} to mean "default": substituting the default inside the
  constructor keeps passing {{.Nil}} legal and merely moves the check — the default
  lives in an option or the caller passes the Null Object by name. Only a *required*
  collaborator (a store, a client the type cannot work without) is rejected in the
  constructor — doing nothing silently there would hide a bug. Promoting an optional
  collaborator to a required positional parameter with a comment saying "pass the
  do-nothing value instead of {{.Nil}}" changes nothing: the parameter still accepts
  {{.Nil}}, the constructor neither defaults nor rejects it, and the first use crashes.
  A collaborator with a sensible do-nothing default is optional; it stays an option
  with the default in the constructor. An option handed {{.Nil}} must not become a
  value that works: it records the failure on the value under construction, and the
  constructor fails with a message naming the option; the field never holds {{.Nil}};
  no method ever asks.

{{include "rules/R2/absence-mechanics.md"}}

- **No defensive coding.** Check arguments in the constructor so that methods contain
  zero {{.Nil}}/emptiness checks on their own fields. A method validating its receiver is
  validation in the wrong place.

## Fix pattern

- **Add validating constructor**: make fields {{.Unexported}}, add `NewX`/`ParseX`
  returning the value or an error, migrate every literal-construction site through it.
- **Hoist method checks into the constructor**: collect the field checks scattered
  across methods, run them once at construction, delete them from the methods. For a
  *required* collaborator the hoisted check rejects {{.Nil}}; for an *optional* one it is
  the wrong move — use the next one.
- **Introduce Null Object** (`R11-conditional-dispatch.md`): an optional collaborator
  gets a *named* do-nothing value that the constructor supplies through an option or
  the caller passes explicitly; the field is never {{.Nil}} by construction, an option
  handed {{.Nil}} records the error for the constructor to return instead of
  substituting the default, and every guard in the methods is deleted. When the
  collaborator wraps a standard writer or clock, compose the standard no-op into it;
  do not introduce an interface for the sake of the no-op
  (`R6-test-only-interfaces.md`).
- **Delete re-validation of composed types**: if every parameter is itself
  self-validating and there is nothing left to check, the constructor no longer needs
  to fail.
- **Separate Failure from Absence**: an error for failure, an explicit absence result
  for a missing value — never {{.Nil}} standing in for either; see the sentinel move in
  `R1-primitive-obsession.md`.
- Forward design of new types: @code-designing. The primitive extraction that usually
  precedes this rule: `R1-primitive-obsession.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

{{include "rules/R2/falsifying-questions.md"}}
