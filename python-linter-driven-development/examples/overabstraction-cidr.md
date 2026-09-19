# Over-Abstraction Case: The CIDRPresence Wrapper

Demonstrates: R1

A real refactoring where an extraction was tried, rejected, and replaced with two
cheaper alternatives. This is the case law for R1's over-abstraction trap: what a
correct refutation of a proposed type looks like.

## The setting

During the refactor of a K3s configuration function (`align_cidr_args`, originally 60
lines mixing string parsing, boolean flag tracking, and triplicated `match` arms), two
booleans tracked related state:

```python
is_cluster_cidr_set = False
is_server_cidr_set = False
# ... a parsing loop sets them ...
if is_cluster_cidr_set and is_server_cidr_set:
    return  # both set, nothing to do
```

Grouping them into a `CIDRConfig` domain type was a clear win (related data that
travels together, a query method that reads like English). The trap appeared one
step further: the temptation to wrap each boolean in its own type.

## The extraction that was tried

```python
# CIDRPresence — a wrapper that adds NO value
@dataclass(frozen=True)
class CIDRPresence:
    value: bool

    def is_set(self) -> bool:
        return self.value  # just unwraps the bool!


CIDR_PRESENT = CIDRPresence(True)


@dataclass
class CIDRConfig:
    cluster_cidr: CIDRPresence  # wrapped bool
    service_cidr: CIDRPresence  # wrapped bool

    def are_both_set(self) -> bool:
        return self.cluster_cidr.is_set() and self.service_cidr.is_set()
```

## Why it was rejected

1. **8 lines of code** for a trivial wrapper.
2. **One method** that just unwraps: `return self.value`.
3. **No type safety gained** — still just a bool underneath; nothing invalid is made
   unrepresentable, and `CIDRPresence(True)` admits exactly what `True` admits.
4. **Not more readable.** Compare `config.cluster_cidr.is_set()` (wrapper) with
   `config.cluster_cidr_set` (good naming). The honest question — is the method call
   *significantly* clearer? — answers itself: no.
5. **No validation, no logic, no invariants** — pure ceremony. On R1's scorecard this
   scores 0-1: LOW priority, do not create the type.
6. **Increases cognitive load** — one more class to understand, for nothing.

The rejection also identified the *real* need hiding under the proposal: **controlled
mutation**. Only the parsing code should be able to set these flags — and the wrapper
type does not deliver that (its fields were still freely settable). Naming the actual
need is what makes the cheaper alternatives findable.

## Cheaper alternative 1 — better naming

When the need is only clarity, rename and stop:

```python
@dataclass
class CIDRConfig:
    cluster_cidr_set: bool
    service_cidr_set: bool
```

`config.cluster_cidr_set` reads exactly as well as `config.cluster_cidr.is_set()`, at
zero ceremony. Acceptable when mutation discipline isn't a concern (small, disciplined
surface; short-lived value).

## Cheaper alternative 2 — private fields + accessors (chosen)

When the need is controlled mutation rather than validation or logic, Python's
spelling of private fields with read-only accessors is a frozen dataclass: every
field is readable, none is assignable after construction, and only the parser
builds one:

```python
@dataclass(frozen=True)
class CIDRConfig:
    """Which CIDR configurations are present. Built only by parse_cidr_config."""

    cluster_cidr_set: bool
    service_cidr_set: bool

    def are_both_set(self) -> bool:
        return self.cluster_cidr_set and self.service_cidr_set


def parse_cidr_config(args: Sequence[str]) -> CIDRConfig:
    ...  # the one place the flags are decided
```

Why this beat the wrapper:

- **Same safety** — `frozen=True` makes `config.cluster_cidr_set = True` raise
  `FrozenInstanceError` at run time and fail mypy before it; only the parser decides
  the values.
- **4 fewer lines** than the `CIDRPresence` approach, and one class instead of two.
- **Same readability** — `config.cluster_cidr_set` is just as clear as
  `config.cluster_cidr.is_set()`.
- **No wrapper ceremony** — the fields are what they are: bools.

## The decision, tabulated

| Approach | Types | Readability | Safety | Ceremony | Verdict |
|----------|-------|-------------|--------|----------|---------|
| `CIDRPresence` wrapper | 6 | Good | Low | High | ❌ Over-abstraction |
| Public bool fields (naming) | 5 | Good | Low | Low | ⚠️ Acceptable for disciplined scope |
| Private bools + accessors | 5 | Good | **High** | Low | ✅ Chosen |

## The decision questions

Before creating a wrapper type, ask:

1. Does it have >1 meaningful method with logic — not just unwrapping?
2. Does it enforce invariants or validation?
3. Is the need actually *controlled mutation*? → private fields + accessors, not a
   wrapper.
4. Is the method call **significantly** clearer than good naming?
5. Does it hide complex implementation?

Mostly NO → use primitives with good naming, or private fields when mutation must be
controlled. (Score it with R1's scorecard; this wrapper scores 0.)

## The skeptic's operating rule

**A refutation must always propose the cheaper alternative — never just "no".**

Rejecting `CIDRPresence` was legitimate only because the rejection came with a design
that met the real need (controlled mutation) at lower cost. A bare "don't create the
type" would have left the original defect — uncontrolled mutation of the flags — in
place. The skeptic's job is therefore two moves, always together: name the need the
proposal was groping toward, then meet it more cheaply — better naming when the need
is clarity, private fields + accessors when the need is controlled mutation, and a
real type (per R1) only when the need is validation or behavior.
