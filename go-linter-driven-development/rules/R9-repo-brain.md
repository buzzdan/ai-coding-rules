# R9 — Repo Brain (Documentation Network)

## Principle

Documentation is a network ranked by the documentation ladder: storified code →
godoc comments → repo docs → the index, each fact placed at the lowest rung that can
carry it, higher rungs summarizing and pointing down, never duplicating. Two
invariants hold the network together: **reachability** (every doc is reachable from
the root: CLAUDE.md → index.md → doc — no orphans) and **bidirectionality** (code
points up at its feature doc; docs point down at code via greppable symbols; the
index points everywhere).

## Why

Each rung of the documentation ladder has its own drift economics. Rung 0 cannot
drift — the code *is* the behavior. Rung 1 drifts slowly: a godoc comment lives
beside its symbol and gets reviewed with every diff that touches it. Rung 2 drifts
on its own unless networked: nothing in a normal diff forces `docs/` open, so a
feature doc rots silently — *unless* an edge from the changed code names it and an
index line makes it findable. Rung 3 barely drifts because it is short and
regenerable. Placing a fact above its lowest viable rung therefore buys drift for
nothing; placing it below (cramming architecture into a comment) buries it where no
overview reader looks.

The network exists for cold starts. A fresh Claude session — or a new engineer —
enters the repo through one of three doors: a grep hit on a symbol, a file open, or
CLAUDE.md at session start. From any door, full context must be two hops away:
symbol → its godoc → the feature doc; CLAUDE.md → index.md → the feature doc. An
unlinked doc is an unread doc, and unread docs rot — orphaning is not a tidiness
problem, it is the mechanism by which documentation dies. Drift-detection depends on
the same wiring: only a **literal, greppable** edge can be mechanically verified
(Q2 below); a prose paraphrase of code structure can be wrong forever without
anyone noticing.

## Canonical example

A retry feature shipped months ago. The knowledge exists — and is unreachable.

### Before — the knowledge is there, the network is not

```
repo/
├── CLAUDE.md              # build commands only; no reference to docs/
├── docs/
│   └── retry-policy.md    # explains the jitter decision; nothing links to it
└── retry/
    └── policy.go
```

```go
package retry

type Policy struct { // exported, no doc comment
    maxAttempts int
    baseDelay   time.Duration
}

func (p Policy) Do(ctx context.Context, op Op) error {
    // loop over attempts and back off between failures
    for attempt := 1; attempt <= p.maxAttempts; attempt++ {
        if err := op(ctx); err == nil {
            return nil
        }
        delay := p.baseDelay * time.Duration(1<<attempt)
        sleepWithJitter(ctx, delay)
    }
    return ErrExhausted
}
```

```markdown
<!-- docs/retry-policy.md -->
The retry loop lives in retry/policy.go around line 40; it uses full jitter.
```

Four breaks, one per rung: the in-body comment narrates WHAT the next lines do
(a rung-0 failure — the block wants to be an extracted, named function, which is
`R3-storifying.md`'s territory); `Policy` is a naked exported type, so a grep hit
on it dead-ends with zero context (rung 1); `docs/retry-policy.md` is an orphan —
no index lists it, no comment cites it, and it cites code by **file path and line
number**, coordinates that the next refactor invalidates (rung 2); and CLAUDE.md
imports nothing, so a fresh session starts blind (rung 3).

### After — the same knowledge, networked

```
repo/
├── CLAUDE.md              # @docs/index.md
├── docs/
│   ├── index.md           # one line per doc, grouped by topic
│   └── retry-policy.md    # points down at symbols, not files
└── retry/
    └── policy.go
```

```go
// Policy is a capped exponential-backoff retry policy with full jitter.
// Jitter is deliberate: synchronized clients retrying in lockstep re-overloaded
// the upstream API after every blip. See docs/retry-policy.md for the incident
// and the cap math.
type Policy struct {
    maxAttempts int
    baseDelay   time.Duration
}

func ParsePolicy(maxAttempts int, baseDelay time.Duration) (Policy, error) {
    if maxAttempts < 1 || baseDelay <= 0 {
        return Policy{}, ErrInvalidPolicy
    }
    return Policy{maxAttempts: maxAttempts, baseDelay: baseDelay}, nil
}

func (p Policy) Do(ctx context.Context, op Op) error {
    for attempt := range p.attempts() {
        if err := op(ctx); err == nil {
            return nil
        }
        p.backOff(ctx, attempt)
    }
    return ErrExhausted
}
```

```markdown
<!-- docs/retry-policy.md -->
Entry point: `Policy.Do`. Construction: `ParsePolicy` — validates the cap
against the base delay, so an unbounded backoff cannot exist.
```

```markdown
<!-- docs/index.md -->
# Repo map

**Resilience**
- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; `Policy` API
```

```markdown
<!-- CLAUDE.md -->
@docs/index.md
```

Every break healed at its rung: storifying killed the WHAT-comment — the extracted
names `attempts`/`backOff` carry it (`R3-storifying.md`); `Policy`'s godoc states
the WHY the code cannot (the incident) and carries the upward edge to the feature
doc; the doc points down with the greppable tokens `Policy.Do` and `ParsePolicy` —
no path, no line number — and is listed in the index; CLAUDE.md imports the index,
so the whole map is in context at session start. Grep `Policy` or open CLAUDE.md:
either way, the jitter incident is two hops away.

## Design guidance

Forward guidance — what @documentation applies when writing docs after a feature.

### The documentation ladder

| Rung | Layer | Drift | Owns |
|---|---|---|---|
| 0 | Storified code | none — it IS the behavior | the story; names carry context (owned by `R3-storifying.md`, cited not restated) |
| 1 | Code comments (godoc) | low — lives beside the code, reviewed with diffs | the WHY within a tiered 1–5 prose-line budget (policy below); network edges: `See docs/<feature>.md` |
| 2 | Repo docs | medium — drifts unless networked | feature/architecture docs in the doc root; point back down via greppable symbol references (edge policy below) |
| 3 | The map | minimal — short and regenerable | `index.md` in the doc root: one line per doc, grouped by topic; wired into CLAUDE.md / AGENTS.md |

(The rung metaphor deliberately mirrors the testing composition ladder in @testing:
lowest rung that can carry it, always.)

**Placement rule:** document each fact at the lowest rung of the documentation
ladder that can carry it; higher rungs summarize and point down, never duplicate.
Good overlap: the index says "capped-jitter retries", the feature doc explains the
cap math, the godoc states the incident — each level adds detail. Bad overlap: the
same paragraph pasted at two rungs; it *will* drift. Before writing any comment,
first ask whether a rename or extraction (`R3-storifying.md`) makes it unnecessary —
rung 0 beats rung 1.

### Comment policy (rung 1 — tiered budget)

The WHY is the default content of a doc comment, and it lives inside a hard budget:
**1–5 prose lines**, scaled to the symbol's importance. Not all symbols are born
equal — the budget forces each comment to carry only the most important facts *for
that symbol*; everything else moves up to the feature doc (rung 2), where depth is
cheap, and the `See docs/<feature>.md` edge carries the pointer. This is the
placement rule made operational at write time.

**The Comment Value Toolbox** — a comment earns its lines by delivering one or
more of these values (the growable catalog with worked examples lives in
@documentation's reference.md; this list is the normative set of kinds):

- **WHY, not WHAT** — rationale, incident, constraint the code cannot carry
- **Wider context** — where this sits architecturally; what depends on it
- **Important use cases / flows** — when to reach for it
- **Boundary contract** — dos/don'ts, valid inputs, error behavior
- **Guarantees** — thread safety, nil handling, invariants
- **Network edge** — `See docs/<feature>.md` wiring a critical point into the
  repo brain

**The three-test standard** — every comment (and every rung-2 doc, for test 3)
must pass all three; @documentation applies them at write time and its
comment-critic agent enforces them adversarially after writing:

1. **Toolbox-value test**, two-sided:
   - *Floor (delete test):* a prose line that delivers none of the toolbox values
     is trash — cut it. Named failure modes: restated identifiers, generic filler
     ("provides validation functionality"), narrated implementation, menu sections
     filled without earning their place, **restated repo idiom** — a comment
     justifying a convention the repo already applies everywhere (a pointer field
     meaning "omitted vs explicit zero", the standard error-wrapping style); the
     convention is documented once at rung 2 (coding standards), never
     re-explained at each use site — and **provenance and decoder-ring
     references** — PR numbers, review items, plan/decision/test-plan IDs
     ("T-04-02", "D-07"), requirement tags ("REQ-SVC-01"), spec section refs
     ("spec §4"), "the previous behavior" narration, "matching what
     <old system> did". A decoder-ring token fails even when it resolves inside a
     repo doc: the reader gets the fact as plain prose and the doc through the
     one See-edge — never through a code they must look up.
     The floor's lens is the 5-year reader test: a reader five years out cares how
     the product behaves NOW, never which PR or review round produced it. History
     is rewritten as present-tense rationale ("silently picking one of the TLS
     options could apply a mode the caller did not ask for"), and an
     incident/ticket reference survives only when it IS the rationale for a
     constraint — never as provenance.
   - *Ceiling (smart choice):* the comment as a whole must carry the
     highest-value toolbox items for that symbol's tier within its budget. A
     crossroads whose five lines are all boundary trivia while the architectural
     WHY is missing fails, even though each line individually "adds something".
2. **Budget test** — the comment fits its tier budget (accounting and tiers
   below).
3. **Plain-English test (the empathy test)** — write for a fresh graduate whose
   first language may not be English: everyday words, short sentences, one idea
   per sentence. A comment that needs a dictionary fails even when true and
   within budget. Failure modes: fancy vocabulary where a common word exists
   ("utilize" → "use", "leverages" → "uses"), stacked clauses, academic phrasing,
   and unexplained acronyms or insider jargon ("DTO", "tristate") — in the
   comment AND in the symbol name it documents.
   The test has a second half, **self-standing**: the comment must be
   understandable BEFORE reading the code. If the reader must read the code — or
   another comment ("see X's doc comment for why") — to understand this comment,
   it has negative value. State the fact in place; forward references to other
   comments fail.

**Budget accounting** — prose lines count; these are free:

- blank `//` separator lines
- the `See docs/<feature>.md` network-edge line — free ONLY as its own trailing
  line; a doc reference woven into a prose sentence is not an edge, it is clutter
  in that sentence's line count
- short inline example lines, bounded at 2–4 lines — anything bigger belongs in an
  `Example_*` testable example

**Role-based tiers** — judge the tier from the symbol's role in the code:

| Tier | Role signals | Budget | Typical content |
|---|---|---|---|
| **Helper** | small method, plain constructor, obvious accessor | 0–1 prose line | one-line summary; tiny example only if it clarifies |
| **Contract** | parsing constructor (`ParsePolicy`, `ParsePort`), self-validating type, ordinary exported API | 2–3 prose lines | WHY + boundary contract; dos/don'ts example (free) |
| **Crossroads** | entry point, orchestrator, state machine, feature front door | up to 5 prose lines | WHY, architectural context, use cases + See-edge |

**Two bounded escape hatches:**

- **Package docs in `doc.go`**: a package that genuinely earns more (data-flow
  sketch, core-types list, design decisions all pulling their weight) moves its
  package godoc to a dedicated `doc.go`, bounded at ~20–30 lines. A package comment
  inline in a regular file stays within the standard budget.
- **Crossroads expand recommendation**: the writer never self-exceeds the 5-line
  cap. When a critical crossroads would benefit from richer inline godoc beyond the
  doc reference, write within budget and append an optional, end-of-report
  recommendation — `consider expanding <Symbol>'s godoc inline — <rationale>` —
  for a human to decide later (@documentation's report carries it).

Never fill a template for its own sake — @documentation's templates are menus to
pick from, not forms to fill, and the tier budget caps how much of a menu any one
symbol can order. The one near-constant is the network edge: keep the
`See docs/<feature>.md` reference whenever a feature doc exists.

Boundary with `R3-storifying.md`, stated precisely: block comments *inside*
function bodies are R3's (its Q3 — each is an extraction candidate, and the fix is
a function named after the comment); doc comments *on* exported symbols are this
rule's (Q4 below — they must carry why/context, not restate the identifier).

### Edge conventions

- **Code → docs** (rung 1 → rung 2): a literal relative path in the comment —
  `See docs/retry-policy.md` — always on its own trailing line, never braided
  into the summary sentence (the first sentence stays clean: "Package accounts
  registers the /accounts REST endpoints.", then the See-line). Paths to docs
  are fine; docs move rarely and Q2 verifies them mechanically.
- **Docs → code** (rung 2 → rungs 0–1): cite by **exported symbol** (`Policy`,
  `ParsePolicy`); a **package or directory path** (`retry/`) only when a location
  is genuinely needed; **file paths never, line numbers never** — they are the most
  churn-prone coordinates in the repo (`R5-vertical-slice.md`'s slice reshaping
  renames and splits files as a matter of course). A renamed exported symbol is a
  deliberate, repo-wide-grep act, and a symbol is one grep or IDE-jump from its
  file — symbols are the stable coordinates. Cite the **shortest token that greps
  uniquely**: bare symbol by default; package-qualify only when the bare name is
  ambiguous under repo-wide grep. Headers especially — a header is a landmark, not
  a coordinate dump.
- **Symbol-less artifacts** (examples/, scripts/, testdata/, configs) are cited by
  **directory**, paired with the exported symbols the artifact demonstrates when
  any exist — a bare directory link loses drift detection; the paired symbols
  restore it.
- **Test references** cite the test **package** (`the logger/ package tests`),
  optionally its suite entry point (`TestSpanLoggerAPISuite`) — never individual
  test functions. Test functions have no external callers and no deprecation
  pressure, making them the repo's least stable symbols. Name one only when the
  doc's point is that specific test's design.
- **Every docs→code edge is a literal, greppable token** — never a prose paraphrase
  of code structure. Greppable edges make drift mechanically detectable (Q2);
  paraphrases fail silently.
- **Edge density stays low**: entry points and key players only. The doc maps the
  front doors; it does not mirror the tree. ASCII trees are welcome as orientation
  devices at **package/directory granularity** — a directories-only tree is just a
  set of package-path citations; file-level leaf entries are the violation. Prune
  the leaves, keep the tree.

### The index (rung 3) and the root

- `index.md` lives in the doc root and MUST stay short: a concise reference guide,
  **one line per doc**, grouped by topic. It is the map, not a doc.
- Past ~300 lines it becomes a **map of maps**: the root index shrinks to links to
  short topic or sub-project sub-indexes. This keeps the imported root cheap and
  every doc still two hops from CLAUDE.md.
- **Root wiring**: CLAUDE.md embeds the map via an `@<docroot>/index.md` import
  (e.g. `@docs/index.md`) so it is in context at session start. AGENTS.md is the
  fallback host where CLAUDE.md is not used.

### Doc root discovery and monorepos

- Discovery order: `.ai/` → `.ainav/` → `docs/`. Use the first that exists; create
  `docs/` if none does.
- Monorepo: each sub-project (its own `go.mod` or equivalent sub-project boundary)
  gets its own doc root and index; the repo-root index links the sub-indexes.
- Nesting inside a doc root is allowed; the index (or a sub-index) covers every
  file in it.

## Fix pattern

- **Push the fact down a rung**: delete the comment; make a rename or extraction
  carry the knowledge instead (`R3-storifying.md`). The cheapest doc is a name.
- **Convert WHAT to WHY or delete**: rewrite the doc comment to carry context the
  code cannot (rationale, incident, constraint, contract) — or remove it; a comment
  that restates the identifier is negative-value.
- **Rewire orphan doc**: add its one line to `index.md` *and* add a code-side edge
  (`See docs/<feature>.md`) from the package or type it describes — both invariants,
  reachability and bidirectionality, in one move.
- **Wire the root**: add or repair the `@<docroot>/index.md` import in CLAUDE.md
  (AGENTS.md has no import syntax — use a plain reference line).
- **Update the stale doc with the behavior change**: rewrite the affected section to
  describe current behavior — never append a changelog entry (the
  behavior-not-history discipline lives in @documentation).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.
Determine the doc root first (discovery order above); `<docroot>` below is that
directory.

1. **Is any doc an orphan?**
   Detection: `find <docroot> -name '*.md' ! -name 'index.md'` versus the link
   targets extracted from `index.md` and any sub-indexes, e.g.
   `grep -oE '\]\([^)]+\.md\)' <docroot>/index.md`.
   Violation: a doc file no index references — unreachable from the root, so
   unread, so rotting. Cite the file and the index that should list it.

2. **Is any edge broken — in either direction?**
   Detection, code→docs: `grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' --include='*.go' .`
   plus `.md`-to-`.md` links inside `<docroot>`; `test -f` each target.
   Detection, docs→code: for each backticked symbol a doc cites,
   `grep -rn "type <Sym>\|func <Sym>" --include='*.go' .` (for methods, grep the
   method name); for a cited package or directory path, `test -d` it.
   Violation: any unresolved target in either direction. Additionally, a doc citing
   a **file path or line number** is itself a violation of the edge policy —
   detection: `grep -nE '\.go(:[0-9]+)?|line [0-9]+' <docroot>/*.md | grep -v '://'`
   (the `://` filter exempts URLs, e.g. pkg.go.dev links) — regardless of whether
   the coordinate currently resolves.
   Two exemptions: an index line carrying the ⚠️ stale flag (cites an unresolved
   `Symbol`) is a recorded finding, not a broken edge — the decision to refresh,
   remove, or keep it is the user's. And backticks are a resolvability contract —
   a future/roadmap symbol is written in prose or explicitly marked *(planned)*,
   and *(planned)*-marked citations are exempt from resolution.

3. **Is the root unwired?**
   Detection: `grep -l 'index.md' CLAUDE.md AGENTS.md 2>/dev/null`.
   Violation: no hit — the map exists but is not in context at session start;
   the `@<docroot>/index.md` import is missing.

4. **Does a doc comment on an exported symbol state WHAT instead of WHY?**
   Detection: for each exported declaration in the diff
   (`grep -nE '^(type|func) [A-Z]' <changed files>`), read its doc comment and
   compare its tokens against the identifier and the first lines of the body — a
   comment whose content is recoverable from the name or the code adds nothing.
   Violation: the comment restates the identifier (`// Policy is a policy`) or
   narrates the implementation, instead of carrying rationale, constraints, or
   context the code cannot. Boundary: block comments *inside* function bodies are
   NOT this question — they are `R3-storifying.md` Q3 (extraction candidates).

5. **Is new exported API naked, or a feature-sized change undocumented at rung 2?**
   Detection: in the diff, `grep -nE '^(type|func) [A-Z]'` on added lines and check
   each for a preceding `//` doc comment; separately, compare new packages or entry
   points in the diff against `<docroot>` contents.
   Violation: a new exported type or package with no doc comment; or a
   feature-sized diff (new package, new entry point) with no doc-root entry —
   the knowledge shipped without joining the network.

6. **Did behavior change silently under an existing doc?** *(advisory)*
   Detection: map the diff's changed packages to docs that cite their symbols or
   package paths (grep `<docroot>` for the package name and its exported symbols);
   check whether any such doc is in the diff.
   Violation (advisory): a package with a citing feature doc changed and the doc
   did not — flag it with the doc's path as evidence; the fix is updating the
   affected section, never appending history.
