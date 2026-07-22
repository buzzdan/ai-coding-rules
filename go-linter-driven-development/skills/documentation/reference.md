# Documentation Reference

Menus, templates, checklists, and worked examples for the @documentation skill.
Normative policy — the documentation ladder, network invariants, comment policy, edge
policy, index policy, root wiring, doc-root discovery — lives ONCE in
`../../rules/R9-repo-brain.md`; nothing here overrides it.

## Contents

- [Comment Value Toolbox](#comment-value-toolbox) — the growable catalog of ways a comment delivers value
- [Godoc Menus](#godoc-menus) — package, type, function menus; testable examples
- [Feature Doc Template](#feature-doc-template) — with `Related` edges and symbol-cited key players
- [The Index and Root Wiring](#the-index-and-root-wiring) — index.md, map of maps, CLAUDE.md/AGENTS.md snippets
- [Doc Roots and Monorepos](#doc-roots-and-monorepos)
- [Bootstrap Classification](#bootstrap-classification) — feature / architecture / guide / stale; rung-2 gap criterion; upward-edge anchor heuristic
- [Checklists](#checklists) — feature docs, code comments, quality gates
- [Guidelines](#guidelines) — bug-fix documentation, managing documentation size
- [Examples](#examples) — good vs bad worked examples

> The former "Documentation Layers" section (layer tables, decision tree, overlap
> rules, cross-reference conventions) now lives normatively in
> `../../rules/R9-repo-brain.md` — see its Design guidance (rung table, placement
> rule, edge conventions).

---

## Comment Value Toolbox

The catalog behind R9's toolbox-value test. The normative list of kinds lives in
R9's comment policy; **this catalog is the growable half** — when a new kind of
valuable comment proves itself, add it here with a worked example. Two consumers:
the writer picks from this toolbox when composing a comment (step 3), and the
`comment-critic` cites the specific toolbox item a rewrite should deliver ("swap
narrated implementation for the boundary contract this parsing constructor
needs").

Each entry: when it earns its place, and what it looks like.

### WHY, not WHAT

Rationale, incident, or constraint the code cannot carry. The default value — when
in doubt, this is the one to reach for.

```go
// ❌ ParseAddress parses an address string.            (restates the name)
// ✅ ParseAddress rejects ports below 1024: the collector runs unprivileged.
```

### Wider context

Where this sits architecturally; what depends on it. Earns its place on crossroads
symbols — the reader landing here from a grep needs to know what they're standing
on.

```go
// ❌ Queue is a queue used by the system.               (generic filler)
// ✅ Every exporter ships through this queue — backpressure starts here.
```

### Important use cases / flows

When to reach for this symbol instead of its neighbors. Earns its place when the
choice is not obvious from the names alone.

```go
// ✅ Use Snapshot for reads during a rebalance; direct reads block until it ends.
```

### Boundary contract

Dos/don'ts, valid inputs, error behavior. Earns its place on parsing constructors
and any API whose caller needs the contract before the first call.

```go
// ✅ Accepts "3x100ms"-style specs. Zero attempts and negative delays are rejected.
```

### Guarantees

Thread safety, nil handling, invariants — promises the signature cannot express.

```go
// ✅ Safe for concurrent use; callbacks run outside the lock.
```

### Network edge

The `See docs/<feature>.md` line wiring a critical point into the repo brain.
Near-constant: keep it whenever a feature doc exists (R9 edge policy). Free under
the budget.

```go
// ✅ See docs/retry-policy.md for the incident and the cap math.
```

### What never earns a line: provenance and decoder-ring references

The anti-toolbox. PR numbers, review items, "the previous behavior" narration,
"matching what <old system> did" — change history, not behavior. The 5-year
reader test (R9's floor): a reader five years out cares how the product behaves
NOW, never which PR or review round produced it. Rewrite history as
present-tense rationale; keep an incident/ticket reference only when it IS the
rationale for a constraint.

```go
// ❌ ...must be rejected, matching the legacy backend ("more than one TLS
//    option passed"), REST v2 (which forwarded the conflict), and the CLI's
//    own client-side mutual exclusion. Silently resolving by precedence —
//    the previous behavior — picks a TLS mode the caller didn't ask for
//    (PR #481 review item 5a).

// ✅ Passing more than one TLS option is rejected (422): silently picking
//    one of them could apply a TLS mode the caller did not ask for.
```

**Decoder-ring references** are the same failure in a different costume:
plan/decision/test-plan IDs ("T-04-02", "D-07"), requirement tags
("REQ-SVC-01"), spec section refs ("spec §4"). They fail even when the token
resolves inside a repo doc — a reader without the decoder ring gets nothing.
The fact goes in the comment as plain prose; the doc gets ONE trailing
See-edge; the ID stays in the doc.

```go
// ❌ userResponse is the flat REST response shape for a user account
//    (spec §4). It deliberately has NO field for the password hash — the
//    response omission is structural (T-04-02), not a zero-value
//    coincidence ... additive to the {uid} addressing scheme (D-06/D-07).

// ✅ userResponse is the flat REST response shape for a user account.
//    It has no field for the password hash or the API token, so a response
//    can never leak them.
//    See docs/accounts-api.md.
```

### What never earns a line: restated repo idiom

A comment justifying a convention the repo already applies everywhere: a
pointer field meaning "omitted vs explicit zero", the standard error-wrapping
style, the usual table-driven test shape. Each use site inherits the
convention silently; the explanation lives once at rung 2 (coding standards).
If every site carried it, the real content would drown — and the one genuine
WHY nearby would read as more boilerplate.

```go
// ❌ // Enabled is a pointer so an omitted field is distinguishable from an
//    // explicit false.
//    Enabled *bool `json:"enabled,omitempty"`

// ✅ Enabled *bool `json:"enabled,omitempty"`
```

Test before crediting a WHY: grep the repo for the same pattern. If it appears
across packages with no comment, this comment restates an idiom — cut it.

---

## Godoc Menus

**These are MENUS, not forms** (normative: R9's tiered comment-budget policy —
**1–5 prose lines** scaled to the symbol's role; blank `//` lines, the See-edge, and
short inline examples of 2–4 lines are free). The WHY is the default content; the
tier caps how much of a menu any one symbol can order:

- **Helper** (small method, plain constructor, obvious accessor) → 0–1 line, or
  nothing; a tiny example only if it clarifies.
- **Contract** (parsing constructor like `ParsePort`, self-validating type, ordinary
  exported API) → 2–3 lines; a dos/don'ts example is free and often earns its place.
- **Crossroads** (entry point, orchestrator, state machine, feature front door) →
  up to 5 lines: WHY, architectural context, use cases.

Overflow never stays inline — it moves to the feature doc; the
`See docs/<feature>.md` edge (kept whenever the doc exists) carries the pointer. A
crossroads that deserves more than 5 lines inline gets an expand recommendation in
the FEATURE report instead of extra lines — a human decides (R9's escape hatch).

What fills the chosen menu lines comes from the [Comment Value Toolbox](#comment-value-toolbox)
above — every prose line must deliver one of its values, in plain English (R9's
three-test standard).

### Package Godoc Menu

Pick only the lines this package needs:

```go
// Package [name] provides [high-level purpose].          <- always (one line)
//
// [1-2 sentences: what problem this solves]              <- usually
//
// Main data flow:                                        <- only if non-obvious
//   Input -> Validation -> Processing -> Output
//
// Core types:                                            <- multi-type packages only
//   - Type1: [key responsibility]
//
// Design decisions:                                      <- only where rationale exists
//   - [Key decision and why]
//
// See docs/[feature].md for architecture and usage.      <- whenever the doc exists
package name
```

**The `doc.go` hatch (R9):** when a package genuinely earns more than the standard
budget — flow sketch, core-types list, and design decisions all pulling their
weight — move the package godoc to a dedicated `doc.go`, bounded at ~20–30 lines.
A package comment inline in a regular file stays within the standard tier budget.

### Type Godoc Menu

Pick per symbol kind (hints above):

```go
// TypeName is [one-line domain meaning].                 <- always
//
// [WHY it exists: rationale, incident, constraint —      <- the default content
//  context the code cannot carry]
//
// Constraints:                                           <- self-validating types
//   - [validation rules, thread-safety guarantees]
//
// Use cases / flow:                                      <- logic-heavy types only
//   [when to reach for it, or a short flow sketch]
//
// Example:                                               <- parsing constructors:
//   p, err := ParsePolicy("3x100ms")  // valid              dos/don'ts inputs
//   _, err = ParsePolicy("0x")        // rejected: zero attempts
//
// See docs/[feature].md for the full picture.            <- whenever the doc exists
type TypeName struct {
    // ...
}
```

### Function Godoc Menu

Only for non-obvious behavior; a small method or plain constructor gets one line, or
nothing:

```go
// FunctionName [does what] for [purpose].                <- always, if documented at all
//
// [Error conditions, non-obvious behavior,               <- only when non-obvious
//  performance characteristics]
//
// See docs/[feature].md#section for the detailed flow.   <- whenever the doc exists
func FunctionName(ctx context.Context, input InputType) (OutputType, error) {
    // ...
}
```

### Testable Example Template

```go
// Example_TypeName demonstrates typical usage of TypeName.
func Example_TypeName() {
    id, _ := NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_TypeName_validation shows validation behavior.
func Example_TypeName_validation() {
    _, err := NewUserID("")
    fmt.Println(err != nil)
    // Output: true
}
```

Testable examples show happy-path usage. Keep simple — complex scenarios belong in
feature docs.

---

## Feature Doc Template

The sections are a menu too: a small feature may need only Problem & Solution, Entry
Points, and Related. All code citations follow R9's edge policy: exported symbols
first — the shortest token that greps uniquely, package-qualified only on ambiguity;
package or directory paths when a location is genuinely needed (directories for
symbol-less artifacts like examples/, paired with the symbols they demonstrate);
file paths and line numbers never.

```markdown
# [Feature Name]

## Problem & Solution
**Problem**: [What user/system problem does this solve?]

**Solution**: [High-level approach taken]

## Entry Points
Where execution begins — the front door to this feature, cited by symbol:
- `POST /api/users` → `UserHandler.Create` — creates new user
- `UserCreatedEvent` → `NotificationListener.OnUserCreated` — triggers welcome email
- `cli user create` → `CreateUserCommand.Run` — CLI entry point

## Key Players
The main actors that make this feature work (entry points + key players only — the
doc maps the front doors, per R9's edge policy):

| Symbol | Role | Package |
|--------|------|---------|
| `UserService` | Orchestrates user operations | `user/` |
| `UserRepository` | Persists user data | `user/` |
| `UserID` | Self-validating identifier | `user/` |

## Architecture

### Design Decisions
- **Why [decision]**: [Rationale — connects to coding principles]
- **Why [pattern]**: [Rationale]

### Data Flow
[Step-by-step description]
Input → Validation → Processing → Storage → Output

### Integration Points
- **Consumed by**: [What uses this feature]
- **Depends on**: [What this feature uses]

## Usage

### Basic Usage
[Common case with real, runnable code]

### Advanced Scenarios
[Edge cases — only if they exist]

## Testing Strategy
- **Unit tests**: [What's covered, approach — cite the test package or its suite
  entry point, never individual test functions (R9 edge policy)]
- **Integration tests**: [What's covered, approach]

## Future Considerations
- [Known limitations, potential extensions]

## Related
Edges to sibling docs:
- [auth.md](auth.md) — how sessions authenticate created users
- [notifications.md](notifications.md) — welcome-email delivery
```

---

## The Index and Root Wiring

### index.md Template

A short reference guide: grouped by topic, ONE line per doc (size and style are
normative in R9's index policy):

```markdown
# Repo Map

**Resilience**
- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; `Policy` API

**Users**
- [user-management.md](user-management.md) — user lifecycle; `UserService`, `UserID`
- [notifications.md](notifications.md) — welcome and alert delivery; `Notifier`
```

### Map of Maps (past ~300 lines)

The root index shrinks to links to short topic or sub-project sub-indexes (R9):

```markdown
# Repo Map

- [Resilience](resilience/index.md) — retries, circuit breaking, timeouts
- [Users](users/index.md) — identity, sessions, notifications
```

Each sub-index follows the one-line-per-doc form above.

### CLAUDE.md Wiring Snippet

```markdown
## Documentation
@docs/index.md
```

The `@` import puts the map in context at session start. AGENTS.md has no import
syntax — fall back to a plain reference:

```markdown
## Documentation
Start at docs/index.md — the map of all repo docs.
```

---

## Doc Roots and Monorepos

- Discovery order is normative in R9: `.ai/` → `.ainav/` → `docs/` (create `docs/` if
  none exists).
- `.ai/` and `.ainav/` are AI-navigation conventions — when a repo already uses one,
  it IS the doc root; do not create a parallel `docs/`.
- Monorepo: each sub-project (own `go.mod` or equivalent boundary) gets its own doc
  root + `index.md`; the repo-root index links the sub-indexes (map-of-maps form
  above).
- Nesting inside a doc root is allowed as long as the index (or a sub-index) covers
  every file — R9's reachability invariant.

---

## Bootstrap Classification

Classify each inventoried doc; the class decides its index line and grouping:

| Class | Signals | Index treatment |
|-------|---------|-----------------|
| **feature** | describes one capability's behavior; cites its symbols | group under its topic |
| **architecture** | cross-feature structure, system-wide patterns | its own "Architecture" group |
| **guide** | setup, how-to, onboarding, runbooks | "Guides" group |
| **stale** | cites symbols/packages that no longer resolve; describes removed behavior | index with a FLAGGED line (below); the flag is the advisory finding |

**Stale never means unindexed** — R9's Q1 reachability invariant always wins. A stale
doc gets a flagged index line naming the unresolved symbol:

```markdown
- [auth.md](auth.md) — ⚠️ stale: cites unresolved `TokenVerifier`
```

The flag names the unresolved symbol; it cannot tell an aspirational doc (written
ahead of the code) from a doc for deleted code — choosing refresh (FEATURE mode) /
remove / keep-as-roadmap is the user's call, made from the advisory report.
Bootstrap never decides.

When unsure between feature and architecture: one capability → feature; the seams
between capabilities → architecture.

### Rung-2 Gap Criterion (BOOTSTRAP)

FEATURE mode anchors R9 Q5 on the diff; bootstrap has no diff. Report a rung-2 gap
on exactly two greppable signals — nothing fuzzier:

- **(a) Dangling intent**: a live code→docs edge points at a missing doc — the edge
  is evidence a doc was intended (surfaces from the Q2 code→docs grep).
- **(b) Undocumented front door**: a package with entry points has no doc citing any
  of its exported symbols.

### Upward-Edge Anchor Heuristic (BOOTSTRAP step 5)

Each indexed doc gets at most ONE upward edge (low density — R9 edge policy). The
anchor is the doc's front door, chosen in this order:

1. **The doc's central exported symbol** — the type or constructor the doc most
   centrally describes: usually the first symbol its index line cites, or the type
   in the doc's title (`spanlogger-api.md` → the `SpanLogger` type).
2. **The package godoc** — when the doc spans a whole package rather than one
   symbol (`versioning.md` → `package version`'s doc comment).
3. **No confident anchor** → do not guess. Report the doc as `unwired` in the
   advisory findings; a wrong edge is worse than a missing one (it survives Q2 —
   it resolves — while pointing readers somewhere unhelpful).

Mechanics: append the edge as the final line of the anchor's EXISTING doc comment —
`// See <docroot>/<file>.md for <three-to-six-word reason>.` Never restructure the
comment around it; never create a doc comment solely to host an edge (a naked symbol
is a Q5 finding for FEATURE mode, not a wiring target); confirm the package still
vets after the edit.

---

## Checklists

### Feature Documentation Checklist

- [ ] Clear problem statement and high-level solution approach
- [ ] Entry points listed, cited by symbol (e.g. `POST /users` → `UserHandler.Create`)
- [ ] Key players table with Symbol, Role, and Package — no file paths, no line numbers
- [ ] Design decisions explained with rationale, connected to coding principles
- [ ] Data flow and integration points documented
- [ ] Usage examples are runnable and copy-pasteable
- [ ] `Related` section carries edges to sibling docs
- [ ] Doc has its one line in `index.md`, and at least one code-side edge names it

### Code Comments Checklist

- [ ] Every comment survived the placement test: would a rename or extraction make it
      unnecessary? (R9 placement rule)
- [ ] Every prose line delivers a Comment Value Toolbox item (floor), and the comment
      carries the highest-value items for its symbol's tier (ceiling) — R9's
      toolbox-value test
- [ ] Plain English throughout: everyday words, short sentences, no unexplained
      acronyms or insider jargon — written for a fresh graduate whose first
      language may not be English (R9's plain-English/empathy test)
- [ ] Every comment is self-standing: understandable BEFORE reading the code, no
      forward references to other comments (R9's empathy test, second half)
- [ ] No repo-idiom restating: a convention the repo applies everywhere is never
      re-justified at a use site (documented once at rung 2)
- [ ] No decoder-ring references: no plan/decision/test-plan IDs, requirement
      tags, or spec section refs — facts as prose, the doc via one See-edge
- [ ] Exported symbols carry WHY — rationale, incident, constraint — never a restated
      identifier
- [ ] Every doc comment fits its tier budget — helper 0–1 / contract 2–3 /
      crossroads ≤5 prose lines (R9's tiered comment policy); overflow moved to the
      feature doc, `doc.go` (~20–30 lines) used for package docs that earn it
- [ ] Menu sections included only where they earn their place for that symbol,
      within the tier budget
- [ ] Crossroads that deserve richer inline godoc got an expand recommendation in
      the report — never extra lines beyond budget
- [ ] `See docs/<feature>.md` edge present wherever a feature doc exists — on its
      own trailing line, never woven into the summary sentence
- [ ] Testable examples: at least one `Example_*` per complex/core type; runnable;
      happy path only; `// Output:` comments included

### Quality Gates

**Clarity Test**
- Can someone unfamiliar with the code read this and understand the feature?
- Are design decisions explained, not just described?

**AI Test**
- Can AI use this to fix a bug without reading all implementation code?
- Are integration points, invariants, and assumptions explicit?

**Maintenance Test**
- If the feature needs extension, is it clear where to add code?
- Are limitations and future considerations noted?

**Example Test**
- Can examples be copy-pasted and run with minimal setup?
- Do they demonstrate real-world usage patterns?

---

## Guidelines

### Bug Fix Documentation

Bug fixes should NEVER add changelog-style entries. Instead, update existing docs to
reflect correct behavior.

**Approach:**
1. Find the existing documentation for the affected behavior
2. Update it to describe the CORRECT behavior
3. If no docs exist, write behavior docs as if the bug never happened

**Example — Email Validation Bug:**
```
❌ DON'T ADD:
## Bug Fixes
- Fixed: Email validation now correctly rejects addresses without TLD

✅ DO UPDATE existing "Validation" section:
## Validation
Email addresses must include a valid TLD (e.g., .com, .org).
Invalid formats return ErrInvalidEmail with descriptive message.
```

**Example — Parser Edge Case:**
```
❌ DON'T ADD:
## v1.2.3 Changes
- Fixed edge case where empty input caused panic

✅ DO UPDATE existing "Input Handling" section:
## Input Handling
Empty input returns ErrEmptyInput. All inputs are validated before parsing.
```

**Why this matters:** someone reading docs in 5 years wants to know "How does
validation work?" — they don't care that it was broken once.

### Managing Documentation Size

Two distinct size rules — don't conflate them:
- **A single doc past ~500 lines** → split it into a folder (below).
- **`index.md` past ~300 lines** → map of maps (R9's index policy; form above).

**Split signals:** doc exceeds ~500 lines; multiple distinct topics competing for
attention; hard to find specific information.

**Folder structure for a large feature:**
```
docs/
├── index.md               # root map — links feature-name/index.md
└── feature-name/
    ├── index.md           # sub-index: one line per sub-doc
    ├── architecture.md    # detailed architecture, diagrams
    └── usage.md           # examples and patterns
```

The sub-index follows the same one-line-per-doc form; the root index links it, so
every sub-doc stays two hops from CLAUDE.md (R9's reachability invariant).

**When NOT to split:** the feature is cohesive and flows logically; splitting would
create orphaned fragments; sub-docs would be too thin to stand alone.

---

## Examples

### Anti-Patterns

#### ❌ Changelog-Style Entries
```markdown
## v1.2.3 Changes
- Fixed bug where validation allowed empty strings
- Updated error messages for clarity
```
*Why bad?*: readers need current behavior, not history.

#### ✅ Behavior-Focused Documentation
```markdown
## Validation
- Input must be non-empty string matching pattern `^[a-z]+$`
- Invalid input returns ErrInvalidInput with descriptive message
- Empty input is explicitly rejected (not silently ignored)
```

---

#### ❌ Over-Budget Godoc (depth at the wrong rung)
```go
// Scheduler coordinates periodic report generation across tenants.
// It was introduced after the v2 incident where per-tenant cron jobs
// drifted and overlapped, causing duplicate report emails.
// The scheduler holds a min-heap of next-run times and wakes on the
// earliest deadline. Each tick it drains all due tenants, submits
// them to the worker pool, and re-heaps with jittered next-run times.
// Jitter is +/-10% to avoid thundering herd on shared storage.
// Thread safety: all public methods lock the internal mutex; callbacks
// run outside the lock. Do not call Schedule from inside a callback.
// See docs/report-scheduling.md.
type Scheduler struct { /* ... */ }
```
*Why bad?*: nine prose lines — the heap mechanics and tick flow are implementation
narration (rung-2 material at best) drowning the two facts a reader at this symbol
actually needs. Reviewers scroll past comments like this, then miss the one that
matters.

#### ✅ Trimmed to Tier (crossroads: ≤5 prose lines)
```go
// Scheduler coordinates periodic report generation across tenants.
// It exists because independent per-tenant cron jobs drifted and overlapped
// (duplicate report emails — the v2 incident); one coordinator with jittered
// next-run times replaced them.
// Do not call Schedule from inside a callback — callbacks run outside the lock.
// See docs/report-scheduling.md for the tick flow and jitter math.
type Scheduler struct { /* ... */ }
```
*The overflow moved, not died*: tick flow, heap mechanics, and jitter math now live
in `docs/report-scheduling.md`; the comment keeps the WHY, the one caller-facing
constraint, and the edge that points at the depth.

---

#### ❌ Implementation Details Without Context
```markdown
## Implementation
The CreateUser function calls validateEmail and then repo.Save.
It returns an error if validation fails.
```
*Why bad?*: describes WHAT code does without WHY.

#### ✅ Context-Rich Explanation
```markdown
## Design Decision: Validation Before Persistence
CreateUser validates email format before database operations to:
1. Fail fast — avoid unnecessary database round-trips
2. Provide clear error messages — users get immediate feedback
3. Maintain data quality — only valid emails in database

Email validation is separate from UserID validation because emails
may need external verification (MX record checks) in the future,
while UserIDs are purely format-based.
```

---

#### ❌ Feature List Without Purpose
```markdown
## Components
- UserID type
- Email type
- UserService
```
*Why bad?*: no explanation of relationships or rationale.

#### ✅ Purpose-Driven Structure
```markdown
## Architecture

### Type Safety Layer (Primitive Obsession Prevention)
- **UserID**: self-validating identifier (prevents empty/malformed IDs)
- **Email**: self-validating email (prevents invalid formats, RFC 5322)

These types ensure validation happens once at construction, not repeatedly
throughout the codebase.

### Business Logic Layer
- **UserService**: orchestrates user operations — depends on Repository for
  persistence and Notifier for communication; contains no infrastructure code.

This vertical slice structure keeps all user logic contained in one package:
"group by feature and role, not technical layer."
```

---

#### ❌ Code Dump as "Example"
```markdown
## Usage
See the user package tests for usage examples.
```
*Why bad?*: forces the reader to hunt through test code.

#### ✅ Inline Runnable Example
```go
// Create validated types
id, err := user.NewUserID("usr_12345")
if err != nil {
    panic(err) // invalid ID format
}

email, err := user.NewEmail("alice@example.com")
if err != nil {
    panic(err) // invalid email format
}

// Create and use the service
svc, _ := user.NewUserService(repo, notifier)
err = svc.CreateUser(ctx, user.User{ID: id, Email: email, Name: "Alice"})
```

### Common Documentation Scenarios

**New domain type** — document why it exists (what primitive obsession it prevents),
what it validates, how to construct it, where it's used.

**New service/orchestrator** — document what business operations it provides, what
dependencies it requires (and why), integration points.

**New integration point** — document what external system is integrated and why, how
data flows in/out, error handling and retry/fallback behavior.

**Refactored architecture** — document what problem the refactor solved, what changed
architecturally, why this approach was chosen.

### AI-Friendly Documentation Patterns

**For feature extensions** — established patterns, natural extension points,
constraints to maintain:
```markdown
## Extension Points
- **New validation rules**: add to the NewUserID constructor
- **New storage backends**: implement the Repository interface
- **New notification channels**: implement the Notifier interface
```

**For understanding data flow** — entry points, transformation steps, outcomes:
```markdown
## Data Flow
1. HTTP handler receives POST /users → CreateUserRequest
2. Request validation → NewUserID, NewEmail (self-validating types)
3. UserService.CreateUser → validates business rules
4. Repository.Save → persists to database
5. Notifier.SendWelcome → sends welcome email (async)
6. Returns: User struct or validation/business error
```

**Design invariants** — document invariants that must be maintained:
```markdown
## Design Invariants
- UserID must always be non-empty after construction
- Email validation follows RFC 5322
- UserService assumes repository is never nil (validated in constructor)
```
