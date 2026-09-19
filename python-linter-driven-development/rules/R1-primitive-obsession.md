# R1 — Primitive Obsession

## Principle

Domain concepts must not travel as raw `string`/`int`/`bool`/`[]T`. When a primitive
carries validation rules, behavior, or a domain name, it becomes a type with a
validating constructor and named methods. The inverse binds equally: a wrapper that
adds no validation, no logic, and no invariant is over-abstraction — score before you wrap.

## Why

A rule enforced on a primitive is enforced at every call site and owned by none: the
check gets duplicated, drifts, and is skipped exactly once — in the code path that
ships the bug. Logic trapped on primitives is also untestable in isolation: you must
construct whatever large object happens to hold the primitive. A domain type gives the
rule one owner (the constructor — see `R2-self-validating-types.md`), gives the
behavior a name, makes invalid values unrepresentable downstream, and turns the logic
into a leaf that unit-tests with literals. Where the extracted type then lives is
`R4-helper-placement.md`.

## Canonical example

The Port case, in Python. A service wraps a Kubernetes Service description and must
pick the management port: prefer the port named `weka-api`, else fall back to the
first valid port.

### Before

```python
def management_port(self) -> int:
    for p in self.spec.ports:
        if p.name == "weka-api" and 0 < p.port <= 65535:
            return p.port
    for p in self.spec.ports:
        if 0 < p.port <= 65535:
            return p.port
    return 0
```

Four defects in nine lines:

- The validity rule `0 < p.port <= 65535` is duplicated across the two loops — two
  copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic lives on the wire DTO, so it is testable only by constructing the whole
  service object around a Kubernetes fixture.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none".

### Stage 1 — self-validating types with constructors

```python
@dataclass(frozen=True)
class ServicePort:
    """The wire DTO: public fields, no rules, exactly what the API returned."""

    name: str
    port: int


@dataclass(frozen=True, slots=True)
class Port:
    """A named, validated service port; it cannot exist out of range."""

    name: str
    number: int

    def __post_init__(self) -> None:
        if not 0 < self.number <= 65535:
            raise ValueError(f"port {self.name!r}: {self.number} out of range 1-65535")


@dataclass(frozen=True, slots=True)
class Ports:
    """A collection of valid ports."""

    _items: tuple[Port, ...]

    @classmethod
    def parse(cls, wire: Iterable[ServicePort]) -> "Ports":
        # Drops invalid wire entries — a documented decision that mirrors the
        # original skip-and-fall-back behaviour: an invalid port was never chosen
        # before; now it never exists.
        items = []
        for w in wire:
            try:
                items.append(Port(w.name, w.port))
            except ValueError:
                continue
        return cls(tuple(items))

    def first_named(self, name: str) -> Port | None:
        return next((p for p in self._items if p.name == name), None)

    def first(self) -> Port | None:
        return self._items[0] if self._items else None

    def management(self) -> Port | None:
        # Stage 2 relocates this method — the "weka-api" preference is feature
        # policy, not networking vocabulary.
        return self.first_named("weka-api") or self.first()
```

The payoff, stated plainly: notice what was **not** written. There is no `is_valid()`
method and no validity loop anywhere. Self-validation does not move the
`0 < number <= 65535` check somewhere tidier — it **deletes the concept of a
maybe-invalid port from downstream logic**. Every `Port` inside a `Ports` is valid by
construction (`__post_init__` runs on every literal, so there is no path around it),
so "find the first valid port" collapses to "find the first port". And
`management()` returns `Port | None`, a declared absence — never a `0` sentinel that
smuggles validity back in-band. Absence that is exceptional would raise instead;
the Python rule is that `None` is a declared absence and never a disguised failure
(`R2-self-validating-types.md`).

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `first_named`, `first` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to a shared `networking` package
(rung 3 of `R4-helper-placement.md`). The wire adapter `Ports.parse` knows the
Kubernetes DTO, so it stays with the feature. The feature policy stays home as a
two-line storified method:

```python
def management_port(self) -> networking.Port | None:
    return self.ports.first_named(WEKA_API_PORT) or self.ports.first()
```

Teaching point: **promote only the domain-generic parts.** The `WEKA_API_PORT`
constant is feature policy and stays in the feature — a shared package that knows
one feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `management_port()` meant constructing the service around a full
Kubernetes fixture — building a cluster object to check a range predicate. After,
the logic is a leaf and its rung-0 unit tests (the composition ladder's bottom rung —
see @testing) are tuple literals against `networking.Ports`; no big-object
construction:

```python
def test_first_named_prefers_the_named_port() -> None:
    api = Port("weka-api", 14000)
    web = Port("http", 80)

    assert Ports((web, api)).first_named("weka-api") == api


def test_port_rejects_out_of_range() -> None:
    with pytest.raises(ValueError, match="out of range"):
        Port("weka-api", 70000)
```

### The opposite failure: don't over-extract

```python
# ❌ Ceremony, not a type: no rule, no behaviour — every int is as valid as any other.
ReplicaCount = NewType("ReplicaCount", int)


class Name(str):  # ❌ the only "method" unwraps
    def as_str(self) -> str:
        return str(self)
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the `int`; if you want a name, a well-named
variable or a private helper in the same module is the whole answer
(`R4-helper-placement.md`, rung 1). `NewType` is erased at run time and admits every
literal, so it earns nothing on the invariant line either. Deep worked rejection
with the cheaper alternatives: `../examples/overabstraction-cidr.md`.

## Design guidance

A primitive should become a type when it has validation rules, has behavior attached,
represents a domain concept, is used in multiple places, or when passing an invalid
value would be a bug. When the call is not obvious, score it.

### Juiciness scoring

This scorecard lives here and only here — other rules and skills cite it, never
restate it.

**Behavioral (rich behavior):**
- Complex validation (regex, ranges, business rules): +3
- Multiple meaningful methods (≥2): +2
- State transitions/transformations: +2
- Format conversions: +1

**Structural (organizing complexity):**
- Parsing unstructured data into fields: +3
- Grouping related data that travels together: +2
- Making implicit structure explicit: +2
- Replacing an untyped map: +2

**Usage (simplifies code):**
- Used in 5+ places: +2
- Used in 3-4 places: +1
- Significantly simplifies calling code: +1
- Makes tests cleaner: +1

**Invariant and vocabulary (what the type owns for the compiler and the reader):**
- Makes an invalid state unrepresentable — once a value exists it is valid for its
  whole lifetime, so a sentinel, a defensive re-check or a second validating copy
  downstream is deleted. Earned only when the whole lifetime holds: the construction
  path (`R2-self-validating-types.md`: underscore-prefixed fields behind a validating
  constructor, the default-constructed value either valid or never escaping, no in-package literal
  around the constructor) and the paths after it (`R12-mutation-discipline.md`: no
  setter without the constructor's checks, no internal slice or map escaping by
  reference). A bare alias of the primitive admits every literal and its default value
  and earns nothing: +2
- Gives the story a noun it needs — a loop, a flag pair or a repeated predicate at
  the call sites is really an operation on this concept and becomes a named method: +2

Both score 0 for a wrapper whose every literal is as valid as any other and whose
only method unwraps; that is the trap below, not a type.

**Verdict:**
- Score ≥4: HIGH priority — clear win, create the type.
- Score 2-3: MEDIUM priority — judgment call, present to the user.
- Score 0-1: LOW priority — do not create the type; that is over-engineering.

### The over-abstraction trap

The failure mode symmetric to primitive obsession is wrapping a primitive that has
nothing to own: no validation, no invariant, one method that merely unwraps. The
honest test: is `x.Field.IsSet()` *significantly* clearer than a well-named field or
accessor? If the real need is controlled mutation rather than validation or logic,
private fields with accessors beat a wrapper type. Deep worked case — the tried
extraction, the rejection rationale, and the cheaper alternatives:
`../examples/overabstraction-cidr.md`.

### Placement

A juicy type must also land in the right package — feature-scoped versus
domain-generic. That decision is `R4-helper-placement.md`; the canonical example's
Stage 2 shows it applied.

## Fix pattern

- **Replace Primitive with Domain Type**: introduce `ParseX(raw)`, returning the value
  or an error (`R2-self-validating-types.md`); migrate call sites so raw values cross into `X`
  exactly once, at the boundary.
- **Extract Collection Type**: when logic loops over `[]primitive` or `[]DTO`, wrap
  the slice (`type Ports []Port`) and move the loop into a named query method.
- **Replace Sentinel with comma-ok**: `return 0` / `return ""` meaning
  absence/invalidity → an explicit absence result, or an error.
- **Name enum strings**: `if status == "READY"` → `type Status string` with
  `const StatusReady Status = "READY"`. The same move owns a string *assigned* from a
  fixed set of literals: `scheme := "http"; if tls { scheme = "https" }` written in two
  functions is a two-value enum with no name, and the fix is `type Scheme string`, its
  two constants, and one constructor from the flag (`SchemeFor(tls bool) Scheme`) —
  never a private helper that returns the same bare string, which dedupes the
  decision and keeps the primitive.
- **Introduce Parameter Object** (Fowler): the same group of parameters traveling
  through multiple signatures (`host string, port int, useTLS bool`) becomes one
  type — that is the scorecard's "grouping related data that travels together" made
  concrete. Prefer passing the whole object over re-exploding its fields at the next
  call (Preserve Whole Object).
- **Over-abstraction found instead?** Apply the cheaper alternative — better naming,
  or private fields + accessors — per `../examples/overabstraction-cidr.md`.
- Multi-rule refactoring procedure (sequencing extraction with storifying):
  `../skills/refactoring/reference.md`. Forward design of the new types:
  @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: `grep -nE '^\s*(el)?if .*\b[a-zA-Z_.]+ (==|!=) ""|^\s*(el)?if .*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]|^\s*(el)?if not [a-zA-Z_.]+:' $(git diff --name-only -- '*.py')`
   — the check often sits second in a compound condition (`if failed or days <= 0
   or days > 365`), so the pattern reads the whole `if` line, not its first clause;
   `if not host:` is Python's emptiness check and counts.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `__post_init__`, a
   `parse` classmethod or a pydantic validator.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, grep its normalized form across the
   package, e.g. `grep -rn '0 < .* <= 65535' --include='*.py' .` — count hits (a
   chained comparison and its `and`-joined twin, `0 < p and p <= 65535`, are one
   predicate).
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/matches over `list[str]`,
   string-literal status comparisons, format logic on a `str` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detection: `grep -rnE '== "[A-Z_]+"|case "[a-z_]+":' --include='*.py' .` for
   enum-shaped comparisons and `match` arms on raw strings;
   `grep -rnE '^\s*[a-z]\w* = "[a-z]+"$' --include='*.py' .` for a literal assigned
   to a variable, then read whether the same variable takes a second literal under a
   condition (`scheme = "http"; if tls: scheme = "https"`) and whether that pair
   appears in more than one function; inspect the diff for loops whose body
   interprets a primitive. A `Literal["email", "slack"]` annotation names the set
   but carries no behavior; it scores like the bare string.
   Violation: behavior attached to a bare primitive where a named method on a type
   (a `StrEnum` with methods, a frozen dataclass) would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: `grep -nE 'return (0|""|-1|None)\s*(#.*)?$' $(git diff --name-only -- '*.py')`,
   then read each hit's signature: the hit is a sentinel when the return annotation
   promises a real value (`-> Device`, `-> int`) and the body returns `None`, `0` or
   `""` for the missing case. mypy reports that `None` as `return-value`, so a
   `# type: ignore[return-value]` on the line is the same hit, silenced. A
   `-> X | None` signature is a declared absence and is not this question, as long
   as the `None` means "not there" and never "it failed" (R2 Q5 owns that line). A
   trailing comment (`return 0  # sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires `X | None` for a normal absence,
   or an exception for a failure; never `tuple[X, bool]`.

5. **Do the same parameters travel together across signatures?**
   Detection: for each changed function with ≥3 parameters, grep the package for the
   same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'def .*host: str.*port: int' --include='*.py' .`; ruff `PLR0913`
   (too many arguments) marks the candidates.
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detection: count its methods (`grep -cE '^    def ' <file>` between the `class`
   line and the next top-level statement) and check whether any method does more
   than unwrap or rename the primitive; score it with the scorecard above. A
   `NewType`, or a `class Name(str)` with no `__post_init__`, no validator and no
   method, scores 0 on the invariant line: it admits every literal.
   Violation: Score 0-1, or the only method is `return str(self)` —
   over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).
