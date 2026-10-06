A retry feature shipped months ago. The knowledge exists — and is unreachable.

### Before — the knowledge is there, the network is not

```
repo/
├── CLAUDE.md              # build commands only; no reference to docs/
├── docs/
│   └── retry-policy.md    # explains the jitter decision; nothing links to it
└── src/retry/
    └── policy.ts
```

```typescript
export class Policy {                                   // exported, no JSDoc
  constructor(
    private readonly maxAttempts: number,
    private readonly baseDelayMs: number,
  ) {}

  async do(op: () => Promise<void>): Promise<void> {
    // loop over attempts and back off between failures
    for (let attempt = 1; attempt <= this.maxAttempts; attempt += 1) {
      try {
        await op()
        return
      } catch (error) {
        rethrowUnlessTransient(error)
        await sleepWithJitter(this.baseDelayMs * 2 ** attempt)
      }
    }
    throw new RetriesExhausted()
  }
}
```

```markdown
<!-- docs/retry-policy.md -->
The retry loop lives in src/retry/policy.ts around line 12; it uses full jitter.
```

Four breaks, one per rung: the in-body comment narrates WHAT the next lines do
(a rung-0 failure — the block wants to be an extracted, named method, which is
`R3-storifying.md`'s territory); `Policy` is a naked export, so a grep hit on it
dead-ends with zero context and `jsdoc/require-jsdoc` fires where the repository
configures it (rung 1); `docs/retry-policy.md` is an orphan — no index lists it, no
JSDoc cites it, and it cites code by **file path and line number**, coordinates that
the next refactor invalidates (rung 2); and CLAUDE.md imports nothing, so a fresh
session starts blind (rung 3).

### After — the same knowledge, networked

```
repo/
├── CLAUDE.md              # @docs/index.md
├── docs/
│   ├── index.md           # one line per doc, grouped by topic
│   └── retry-policy.md    # points down at symbols, not files
└── src/retry/
    └── policy.ts
```

```typescript
/**
 * A capped exponential-backoff retry policy with full jitter.
 *
 * Jitter is deliberate: synchronized clients retrying in lockstep re-overloaded
 * the upstream API after every blip.
 * See docs/retry-policy.md for the incident and the cap math.
 */
export class Policy {
  private constructor(
    readonly maxAttempts: number,
    readonly baseDelayMs: number,
  ) {}

  static parse(maxAttempts: number, baseDelayMs: number): Policy {
    if (maxAttempts < 1 || baseDelayMs <= 0) {
      throw new PolicyError('retry policy: attempts must be positive and the base delay non-zero')
    }
    return new Policy(maxAttempts, baseDelayMs)
  }

  /** Run op until it succeeds or the attempts are exhausted. */
  async do(op: () => Promise<void>): Promise<void> {
    for (const attempt of this.attempts()) {
      try {
        await op()
        return
      } catch (error) {
        rethrowUnlessTransient(error)
        await this.backOff(attempt)
      }
    }
    throw new RetriesExhausted()
  }
}
```

```markdown
<!-- docs/retry-policy.md -->
---
type: feature
description: why retries use capped full jitter; `Policy` API
---
Entry point: `Policy.do`. Construction: `Policy.parse` — validates the cap against
the base delay, so an unbounded backoff cannot exist.
```

```markdown
<!-- docs/index.md -->
---
okf_version: "0.2"
---
# Repo map

**Resilience**
- [retry-policy.md](retry-policy.md) — why retries use capped full jitter; `Policy` API
```

```markdown
<!-- CLAUDE.md -->
@docs/index.md
```

Every break healed at its rung: storifying killed the WHAT-comment — the extracted
private methods `attempts`/`backOff` carry it (`R3-storifying.md`); `Policy`'s JSDoc
opens with the one-line summary, states the WHY the code cannot (the incident) in its
body, and carries the upward edge to the feature doc on its own trailing line — no
`@param` tags restating `number`; the doc points down with the greppable tokens
`Policy.do` and `Policy.parse` — no path, no line number — and is listed in the index;
CLAUDE.md imports the index, so the whole map is in context at session start. Grep
`Policy` or open CLAUDE.md: either way, the jitter incident is two hops away. And the
index line has one source of truth: it IS `retry-policy.md`'s `description`, copied
verbatim — the conformance gate (Q7) fails the moment the copy drifts.
