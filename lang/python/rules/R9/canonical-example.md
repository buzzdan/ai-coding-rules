A retry feature shipped months ago. The knowledge exists — and is unreachable.

### Before — the knowledge is there, the network is not

```
repo/
├── CLAUDE.md              # build commands only; no reference to docs/
├── docs/
│   └── retry-policy.md    # explains the jitter decision; nothing links to it
└── retry/
    └── policy.py
```

```python
class Policy:                                       # public, no docstring
    def __init__(self, max_attempts: int, base_delay: timedelta) -> None:
        self._max_attempts = max_attempts
        self._base_delay = base_delay

    def do(self, op: Callable[[], None]) -> None:
        # loop over attempts and back off between failures
        for attempt in range(1, self._max_attempts + 1):
            try:
                op()
                return
            except TransientError:
                delay = self._base_delay * (1 << attempt)
                sleep_with_jitter(delay)
        raise RetriesExhausted()
```

```markdown
<!-- docs/retry-policy.md -->
The retry loop lives in retry/policy.py around line 12; it uses full jitter.
```

Four breaks, one per rung: the in-body comment narrates WHAT the next lines do
(a rung-0 failure — the block wants to be an extracted, named function, which is
`R3-storifying.md`'s territory); `Policy` is a naked public class, so a grep hit
on it dead-ends with zero context and ruff's `D101` fires (rung 1);
`docs/retry-policy.md` is an orphan — no index lists it, no docstring cites it, and it
cites code by **file path and line number**, coordinates that the next refactor
invalidates (rung 2); and CLAUDE.md imports nothing, so a fresh session starts blind
(rung 3).

### After — the same knowledge, networked

```
repo/
├── CLAUDE.md              # @docs/index.md
├── docs/
│   ├── index.md           # one line per doc, grouped by topic
│   └── retry-policy.md    # points down at symbols, not files
└── retry/
    └── policy.py
```

```python
@dataclass(frozen=True)
class Policy:
    """A capped exponential-backoff retry policy with full jitter.

    Jitter is deliberate: synchronized clients retrying in lockstep re-overloaded
    the upstream API after every blip.
    See docs/retry-policy.md for the incident and the cap math.
    """

    max_attempts: int
    base_delay: timedelta

    def __post_init__(self) -> None:
        if self.max_attempts < 1 or self.base_delay <= timedelta(0):
            raise ValueError("retry policy: attempts must be positive and the base delay non-zero")

    def do(self, op: Callable[[], None]) -> None:
        """Run op until it succeeds or the attempts are exhausted."""
        for attempt in self._attempts():
            try:
                op()
                return
            except TransientError:
                self._back_off(attempt)
        raise RetriesExhausted()
```

```markdown
<!-- docs/retry-policy.md -->
---
type: feature
description: why retries use capped full jitter; `Policy` API
---
Entry point: `Policy.do`. Construction validates the cap against the base delay
in `Policy`, so an unbounded backoff cannot exist.
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
names `_attempts`/`_back_off` carry it (`R3-storifying.md`); `Policy`'s docstring
opens with the one-line summary PEP 257 asks for, states the WHY the code cannot
(the incident) in its body, and carries the upward edge to the feature doc on its own
trailing line; the doc points down with the greppable tokens `Policy.do` and
`Policy` — no path, no line number — and is listed in the index; CLAUDE.md imports
the index, so the whole map is in context at session start. Grep `Policy` or open
CLAUDE.md: either way, the jitter incident is two hops away. And the index line has
one source of truth: it IS `retry-policy.md`'s `description`, copied verbatim — the
conformance gate (Q7) fails the moment the copy drifts.
