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
---
type: feature
description: why retries use capped full jitter; `Policy` API
---
Entry point: `Policy.Do`. Construction: `ParsePolicy` — validates the cap
against the base delay, so an unbounded backoff cannot exist.
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
names `attempts`/`backOff` carry it (`R3-storifying.md`); `Policy`'s godoc states
the WHY the code cannot (the incident) and carries the upward edge to the feature
doc; the doc points down with the greppable tokens `Policy.Do` and `ParsePolicy` —
no path, no line number — and is listed in the index; CLAUDE.md imports the index,
so the whole map is in context at session start. Grep `Policy` or open CLAUDE.md:
either way, the jitter incident is two hops away. And the index line has one
source of truth: it IS `retry-policy.md`'s `description`, copied verbatim — the
conformance gate (Q7) fails the moment the copy drifts.
