# Maxims — the layer above the rules

Rules (`rules/R1–R12`) are **compiled judgment**: each has a detection command, a
violation criterion, and a fix pattern — an agent can convict with evidence. A maxim
is the **question that generates such answers** in situations no rule anticipated.
"Tell, don't ask" existed before R11; R11 is what it looks like compiled for
kind-conditionals. This file holds the questions — both the ones already compiled
(with pointers to their rules) and the ones still uncompiled, waiting to earn
detection commands.

## The contract: maxims propose, evidence disposes

Maxims live where the plugin exercises **judgment**; they are banned where it must
produce **evidence**:

- **@code-designing** interrogates the plan with these questions — design happens
  before a diff exists, so questions are the only tool available there.
- **@refactoring's escalation path** uses them as vocabulary for *why* code resists
  ("every caller asks this struct three questions and then decides — the design
  wants Tell-Don't-Ask").
- **The over-abstraction skeptic** cites the abstraction-economics maxims by name in
  its verdicts.
- **Rule hunters NEVER cite maxims.** A finding exists only as a rule violation with
  `file:line` evidence. A maxim may generate a hypothesis; only a rule's detection
  command can convict. This is what keeps the review credible.

**Graduation:** when a maxim keeps generating findings that no rule can express, that
is the signal to compile it — write the R-file, give it falsifying questions with
detection commands, and move its entry here from *uncompiled* to *compiled*. R11 and
R4's feature-envy question are graduates of exactly this path.

---

## Behavior and ownership

### Tell, don't ask
— Andy Hunt & Dave Thomas, *The Pragmatic Programmer*

**Ask:** what will the caller *do* with the value it is requesting — and does that
decision belong on the type that owns the value?

**Compiled into:** `rules/R11-conditional-dispatch.md` (asking what a value *is*),
`rules/R4-helper-placement.md` Q6 (feature envy — asking for data to decide with).

### Talk to your friends, not your friends' friends
— The Law of Demeter (Karl Lieberherr)

**Ask:** is this caller navigating a path (`a.B().C().D()`) it has no business
knowing? First apply Tell-Don't-Ask — moving the *behavior* usually dissolves the
chain. What survives is data egress at a boundary, where a one-shot adapter mapping
is the honest form.

**Compiled into:** `rules/R4-helper-placement.md` — Q6 (feature envy) plus the
message-chain and middle-man bullets in its Fix pattern (Hide Delegate subordinated
to Tell-Don't-Ask; Remove Middle Man as the per-method ceremony verdict; the
domain-type embedding trap). Uncompiled residue: detection commands for
forward-heavy types and boundary-crossing chains — graduates to an R4 falsifying
question if the hunter keeps stumbling over them.

## State and construction

### Make illegal states unrepresentable
— Yaron Minsky

**Ask:** can this type hold a value its methods would have to defend against? Delete
the possibility, not the symptom.

**Compiled into:** `rules/R2-self-validating-types.md`, and its aliasing corollary
`rules/R12-mutation-discipline.md` (a leaked internal reference re-legalizes the
illegal state).

### Parse, don't validate
— Alexis King

**Ask:** does this check produce a *more-typed value* (`ParseX(raw) (X, error)`), or
just a boolean the next caller must remember? Validation that returns proof is
parsing; validation that returns advice is a latent re-check.

**Compiled into:** `rules/R2-self-validating-types.md`; `rules/R3-storifying.md`
Split Phase (phase 1 as the parse).

### Make the zero value useful
— Rob Pike, Go Proverbs

**Ask:** could `var x T` just work (`bytes.Buffer`, `sync.Mutex`)? Held in
deliberate tension with R2: **mechanism types** earn zero-value usefulness;
**validated domain types** earn constructors — a type that needs invariants cannot
also promise a useful zero. Decide which family a new type is in; don't split the
difference.

**Uncompiled** — lives here as a design-time question.

## Abstraction economics

### Every indirection must earn its keep
— this plugin's own synthesis (the generalized juiciness test)

**Ask:** what does this indirection *own* — a validation, a decision, a second
production implementation, a deleted duplication, a real race, a real escaping
alias? If the answer is nothing, it is ceremony: delete it.

**Compiled into:** every inverse trap in the rule set — one principle at six
granularities: type (R1's scorecard and ceremony wrappers), interface (R6's
earned-interface test), method (R4's middle-man bullet), dispatch (R11's unearned
abstractions), guard (R10's decorative mutexes), copy (R12's ceremony copies). The
`overabstraction-skeptic` is its enforcement agent. Nuance: the R1 scorecard is the
*prospective* form (score before the type is born); the inverse traps are the
*retrospective* form (this indirection exists — does it still own anything?).

### Duplication is far cheaper than the wrong abstraction
— Sandi Metz

**Ask:** is this extraction *earning* its indirection today, with the callers in
hand — or is it a bet on imagined futures?

**Compiled into:** the `overabstraction-skeptic` agent (its bias statement is this
maxim), `rules/R1-primitive-obsession.md`'s inverse trap and scorecard.

### You aren't gonna need it (YAGNI)
— Extreme Programming

**Ask:** does anything *present* require this flexibility?

**Compiled into:** `rules/R6-test-only-interfaces.md` (an interface is earned by a
second production implementation, never by "for the future").

### Three strikes and you refactor
— Don Roberts, via *Refactoring*

**Ask:** how many real occurrences exist *right now*? One is an instance, two is a
coincidence, three is a pattern.

**Compiled into:** `rules/R1-primitive-obsession.md` scorecard usage points.

### A little copying is better than a little dependency
— Rob Pike, Go Proverbs

**Ask:** does sharing these four lines couple two features that would otherwise
evolve independently? Promotion to a shared package is a *dependency*, and
dependencies cost more than duplication until the third strike.

**Compiled into:** partially the skeptic + `rules/R4-helper-placement.md`'s ladder.
Uncompiled residue: the explicit copy-first default for tiny cross-feature helpers.

### The bigger the interface, the weaker the abstraction
— Rob Pike, Go Proverbs

**Ask:** could this interface be one method (`io.Reader`)? Would a consumer with
half the methods still satisfy every caller?

**Compiled into:** partially `rules/R6-test-only-interfaces.md` ("small and
cohesive"). Uncompiled residue: earned interfaces that accrete methods.

## Process and economics

### Make the change easy, then make the easy change
— Kent Beck

**Ask:** does the code's current shape fight the change in hand? Reshape first, in
its own commit — bounded by what the change touches.

**Compiled into:** @linter-driven-development `<phase_1_5_prepare>` and
@refactoring `<preparatory_mode>`.

### If a test is hard to write, the design is wrong
— Steve Freeman & Nat Pryce, *Growing Object-Oriented Software*

**Ask:** what is the test's pain telling you? Huge fixtures → the unit is too big;
global mutation → a seam is missing; mocks everywhere → the boundaries are wrong.
Never silence test pain with test machinery.

**Compiled into:** the RED-friction escape hatch (@linter-driven-development
Phase 2), `rules/R6-test-only-interfaces.md`, `rules/R7-test-placement.md`.

### If it hurts, do it more often
— Martin Fowler

**Ask:** is this pain a batch-size problem? Deferred checks compound; per-cycle
checks stay trivial.

**Compiled into:** the five-phase cadence itself — package-scoped lint every
RED→GREEN→REFACTOR cycle instead of one bulk reckoning at the end.

### Premature optimization is the root of all evil
— Donald Knuth

**Ask:** is there a profile? Clarity first; optimize the measured 3%, never the
imagined 30%. (R12's ceremony-copy inverse is one instance: don't "optimize" *or*
"defend" without evidence of need.)

**Uncompiled** — no rule owns profile-first optimization discipline yet.

## Clarity and knowledge

### Clear is better than clever
— Rob Pike, Go Proverbs

**Ask:** will a reader get this in 10–15 seconds? Cleverness is a cost paid by every
future reader.

**Compiled into:** `rules/R3-storifying.md` and the plugin's readability philosophy.

### Once and only once
— Kent Beck (and DRY: "every piece of knowledge has a single, unambiguous,
authoritative representation" — Hunt & Thomas)

**Ask:** how many places own this fact? Note it is about *knowledge*, not lines:
two similar-looking blocks encoding different decisions are not duplication, and
one decision spread across five switches is (R11) — count owners, not text.

**Compiled into:** `rules/R1-primitive-obsession.md` Q2,
`rules/R11-conditional-dispatch.md`, and this plugin's own architecture contract
("one fact per fact").

## Architecture

### Depend in the direction of stability
— Robert C. Martin

**Ask:** which side of this boundary changes more often — and does the arrow point
from volatile to stable? A move that makes a stable package import a volatile
consumer is wrong even when it looks cleaner.

**Compiled into:** `rules/R8-no-globals.md` (downward imports),
`examples/switch-to-polymorphism.md`'s dependency-direction rejection (via
`rules/R11-conditional-dispatch.md`).
