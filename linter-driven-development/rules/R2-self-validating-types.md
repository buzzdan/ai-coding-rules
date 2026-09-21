# R2 — Self-Validating Types

## Principle

A type validates its own invariants in its constructor — the only way to obtain a
value — and every method thereafter trusts the receiver. Validation ownership never
sits upstream: a type that relies on callers to have validated for it is not
self-validating, whatever its fields look like.

## Why

Constructor validation makes invalid values unrepresentable. Without it, every method
must defend against bad state, forgetting one check is a latent crash, and the
defensive noise buries the actual logic. With it, null-checks, emptiness checks, and
range checks vanish from the entire downstream call graph — the payoff compounds with
every method and every caller. Errors also surface at the boundary where the bad data
entered, carrying context, instead of deep in an unrelated call stack.

## Canonical example

Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing). The shape is the same in every
language; how the constructor reports a failure — an error result, an exception —
follows the repository's.

```text
Port                         # cannot exist out of range — the constructor is the only entry
    name, number             # internal: no literal builds a Port around the check
parsePort(name, number):
    if number <= 0 or number > 65535: fail "port <name>: <number> out of range 1-65535"
    return Port(name, number)
```

Before this type existed, the range check was duplicated across two loops at the use
site. After, there is no `isValid()` and no re-check anywhere: the concept of a
maybe-invalid port is deleted from downstream logic, not relocated.

The same pattern for a composed object — validate dependencies once, then trust:

```text
# ❌ every method defends
UserService
    repo                     # public, might be missing
UserService.createUser(user):
    if repo is null: fail "repo is missing"     # repeated in every method; forget one → crash
    return repo.save(user)

# ✅ constructor validates once; methods trust the receiver
UserService
    repo                     # internal
newUserService(repo):
    if repo is null: fail "repo is required"
    return UserService(repo)
UserService.createUser(user):
    return repo.save(user)   # no checks — an invalid service cannot exist
```

## Design guidance

- **Constructors are the only entry.** `ParseX(raw)` for values built from
  unstructured input, `NewX(deps)` for composed objects, each returning the value or an
  error (constructors may carry other names — any public function returning the type
  qualifies). Fields stay internal: building the value directly, bypassing the
  constructor, is a hole in the type.

- **Validation ownership.** A type never relies on upstream validation. "The handler
  already checked it" is not an invariant — handlers change, new call sites appear,
  and the type outlives both. A comment reading "caller must ensure X" is the
  signature of a type that does not own itself: move that sentence into the
  constructor as code.

  The canonical example above shows the shape: the check that used to live in every
  caller's head lives once, in the constructor, in the repository's language.

- **Trust composed values.** Once you hold a `Port`, it is valid — never re-check it
  downstream, and never re-validate it in a composing constructor. Each type owns
  exactly its own invariants:

  A composing constructor whose every parameter is already a validated type has
  nothing left to check and no failure to report.

- **null is not a value.** Never return null where a real value is expected —
  return an error instead. A failure result carries the error, not a value, so that
  position is exempt. Never pass null into a function; then functions do not
  check parameters for null.

- **Absence is a value too.** An *optional* collaborator — a logger, a metrics sink,
  an event writer, a clock — is not a field that may be null with a guard in every
  method. The default is a named do-nothing value the constructor supplies, the field
  is never null, and every "if the sink is set" guard disappears. This is the Null
  Object of `R11-conditional-dispatch.md`: a real implementation that honors the
  contract by doing nothing, so no caller ever branches on a missing destination. No
  parameter accepts null to mean "default": substituting the default inside the
  constructor keeps passing null legal and merely moves the check — the default
  lives in an option or the caller passes the Null Object by name. Only a *required*
  collaborator (a store, a client the type cannot work without) is rejected in the
  constructor — doing nothing silently there would hide a bug. Promoting an optional
  collaborator to a required positional parameter with a comment saying "pass the
  do-nothing value instead of null" changes nothing: the parameter still accepts
  null, the constructor neither defaults nor rejects it, and the first use crashes.
  A collaborator with a sensible do-nothing default is optional; it stays an option
  with the default in the constructor. An option handed null must not become a
  value that works: it records the failure on the value under construction, and the
  constructor fails with a message naming the option; the field never holds null;
  no method ever asks.

  How the default is supplied — an option, a keyword argument, a sentinel object —
  and how a rejected argument is reported follow the repository's construction idiom;
  the canonical example above shows one language's spelling.

- **No defensive coding.** Check arguments in the constructor so that methods contain
  zero null/emptiness checks on their own fields. A method validating its receiver is
  validation in the wrong place.

## Fix pattern

- **Add validating constructor**: make fields internal, add `NewX`/`ParseX`
  returning the value or an error, migrate every literal-construction site through it.
- **Hoist method checks into the constructor**: collect the field checks scattered
  across methods, run them once at construction, delete them from the methods. For a
  *required* collaborator the hoisted check rejects null; for an *optional* one it is
  the wrong move — use the next one.
- **Introduce Null Object** (`R11-conditional-dispatch.md`): an optional collaborator
  gets a *named* do-nothing value that the constructor supplies through an option or
  the caller passes explicitly; the field is never null by construction, an option
  handed null records the error for the constructor to return instead of
  substituting the default, and every guard in the methods is deleted. When the
  collaborator wraps a standard writer or clock, compose the standard no-op into it;
  do not introduce an interface for the sake of the no-op
  (`R6-test-only-interfaces.md`).
- **Delete re-validation of composed types**: if every parameter is itself
  self-validating and there is nothing left to check, the constructor no longer needs
  to fail.
- **Separate Failure from Absence**: an error for failure, an explicit absence result
  for a missing value — never null standing in for either; see the sentinel move in
  `R1-primitive-obsession.md`.
- Forward design of new types: @code-designing. The primitive extraction that usually
  precedes this rule: `R1-primitive-obsession.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

The detection below names what to search for; build each search over the language's
source files (`detected-language source`), excluding test files, with the repository's own grep
or ripgrep, and read the hits.

1. **Can the type exist in an invalid state?**
   Detection: for each new/changed type with invariants, search for literal
   construction outside its own file (the type's name followed by the language's
   literal or constructor-call syntax, in non-test files); check whether
   invariant-bearing fields are public.
   Violation: any literal-construction site or public invariant-bearing field gives
   callers a path around the constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detection: in the changed files, find conditionals inside method bodies that test
   the receiver's own fields for the missing value or for emptiness (`if self.repo is
   null`, `if len(this.items) == 0`).
   Violation: a method validating its own receiver's fields — the check belongs in
   the constructor. Decide which fix by asking whether the field is required or
   optional: a required collaborator is rejected in the constructor (Hoist method
   checks); an optional one (logger, sink, clock, metrics) gets a Null Object
   default there instead (Introduce Null Object, R11) — name both moves in the
   finding when the code does not say which the field is.

3. **Does a constructor re-validate a composed self-validating type?**
   Detection: read each `NewX`/`ParseX` in the diff; for every parameter whose type
   has its own constructor, search the body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detection: search the source files for `caller must`, `assumes valid` and
   `already validated`; also flag public fields consumed by logic in a package or
   module that defines no constructor for the type.
   Violation: any invariant enforced — or merely documented — outside the type
   itself.

5. **Does anything return or accept the missing value as a value?**
   Detection: in the changed files, find returns of the language's missing value
   (`return null`, and a missing value paired with a "no error" result) — exempt
   the failure position of an error result and a legitimately optional return type
   declared as such.
   Violation: the missing value returned for a non-error result, or a function
   checking a parameter for the missing value instead of the value being guaranteed
   by construction.

6. **Does any call site pass the missing value as a non-error argument?**
   Detection: in the changed files, find call sites with the missing value as an
   argument (`(null,`, `, null)`) — exempt error positions, comparisons
   (`== null`, `is null`), and standard-library idioms where the missing
   value is the documented sentinel (a bodiless request, marshaling an empty
   collection).
   Violation: the missing value passed where a value is expected. Q5 catches the
   return side and Q2 catches the callee that defends; this catches the caller when
   the callee does neither and simply crashes later. Fix on the callee's side: make
   the missing value unrepresentable — a concrete non-optional parameter, a
   validating constructor that rejects it (see the UserService example above), or,
   for an optional collaborator, a Null Object default so the caller never has a
   reason to pass it (`newReporter(sink, null, null)` is the smell; R11).
