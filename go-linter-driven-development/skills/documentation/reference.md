# Documentation Reference

Menus, templates, checklists, and worked examples for the @documentation skill.
Normative policy — the documentation ladder, network invariants, comment policy, edge
policy, index policy, root wiring, doc-root discovery — lives ONCE in
`../../rules/R9-repo-brain.md`; nothing here overrides it.

## Contents

- [Godoc Menus](#godoc-menus) — package, type, function menus; testable examples
- [Feature Doc Template](#feature-doc-template) — with `Related` edges and symbol-cited key players
- [The Index and Root Wiring](#the-index-and-root-wiring) — index.md, map of maps, CLAUDE.md/AGENTS.md snippets
- [Doc Roots and Monorepos](#doc-roots-and-monorepos)
- [Bootstrap Classification](#bootstrap-classification) — feature / architecture / guide / stale
- [Checklists](#checklists) — feature docs, code comments, quality gates
- [Guidelines](#guidelines) — bug-fix documentation, managing documentation size
- [Examples](#examples) — good vs bad worked examples

> The former "Documentation Layers" section (layer tables, decision tree, overlap
> rules, cross-reference conventions) now lives normatively in
> `../../rules/R9-repo-brain.md` — see its Design guidance (rung table, placement
> rule, edge conventions).

---

## Godoc Menus

**These are MENUS, not forms** (normative: R9's comment policy). The WHY is the
default content; every other section is picked only when it earns its place for THIS
symbol:

- **Parsing constructor** (`ParsePort`, `ParsePolicy`) → input dos/don'ts and a short
  example often earn their place: callers need the boundary contract.
- **Logic-heavy type** (orchestrator, state machine) → use cases or a flow sketch.
- **Small method, plain constructor, obvious accessor** → one line, or nothing.

The one near-constant: keep the `See docs/<feature>.md` edge whenever a feature doc
exists.

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
first, package paths when a location is genuinely needed, file paths and line numbers
never.

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
- **Unit tests**: [What's covered, approach]
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
| **stale** | cites symbols/packages that no longer resolve; describes removed behavior | advisory finding — don't index as-is |

When unsure between feature and architecture: one capability → feature; the seams
between capabilities → architecture. Stale is a finding, not a deletion — the user
decides whether to refresh it (FEATURE mode) or remove it.

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
- [ ] Exported symbols carry WHY — rationale, incident, constraint — never a restated
      identifier
- [ ] Menu sections included only where they earn their place for that symbol
      (relevance-scaled, per R9's comment policy)
- [ ] `See docs/<feature>.md` edge present wherever a feature doc exists
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
