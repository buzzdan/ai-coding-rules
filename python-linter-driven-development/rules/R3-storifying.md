# R3 — Storifying (Single Level of Abstraction)

## Principle

A top-level function reads like a story: every step is a named call at the same
conceptual level, and the whole flow is graspable at a glance. Method calls never mix
with string/index manipulation in the same body. A comment that names a block of code
is a function name waiting to be extracted.

## Why

Mixed abstraction levels bury the business flow: the reader must mentally execute
low-level details to reconstruct what the function *means*, and the linter measures
that cost as cognitive complexity. Steps that are inlined instead of named cannot be
tested independently — the only test surface is the whole tangle, with its I/O and
state attached. Storifying does two things at once: the orchestration becomes a
readable, low-complexity narration, and the extracted steps become named units that
either stay as focused helpers or graduate into leaf types
(`R1-primitive-obsession.md`) with 100% unit coverage. Most of a codebase's logic
should end up in those leaves; the story functions above them should be thin.

## Canonical example

Production-shaped code. `upsert_iface_addr_host` must pick usable IPv4 and IPv6
addresses from a network interface and align config state with them.

### Before

```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    try:
        addrs = iface.addrs()
    except OSError as err:
        raise ConfigError(f"network addr: {err}") from err
    ip4_added = False
    ip6_added = False
    for a in addrs:
        if not isinstance(a, IPNetwork) or not a.ip.is_global:
            continue
        if a.ip.version == 6:  # validate IP6
            if ip6_added:  # already added. skip
                continue
            if not self.parse_ip6(a):
                raise ConfigError(f"IP6 {self.ip6!r} address is not valid")
            ip6_added = True
            continue
        if ip4_added:
            continue  # already added. skip
        if not self.parse_ip4(a):
            raise ConfigError(f"IP4 {self.ip4!r} address is not valid")
        ip4_added = True
    if not ip4_added and not ip6_added:
        raise ConfigError(f"IP address is not valid. IP4: {self.ip4!r}, IP6: {self.ip6!r}")
```

Twenty-four lines, cognitive complexity 18: an `isinstance` test, boolean flags
tracking loop state, three nesting levels, `continue`-driven control flow — and the
actual policy (collect one IPv4 and one IPv6, then reconcile with config) is nowhere
stated. The comments `# validate IP6` and `# already added. skip` are naming blocks
that want to be functions. `parse_ip4`/`parse_ip6` mutate `self` — the name hides
the side effect.

### After

```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    try:
        addrs = iface.addrs()
    except OSError as err:
        raise ConfigError(f"network addr: {err}") from err

    ip_config = IPConfig.collect(addrs)

    self.align_ips(ip_config)
```

Read aloud: get addresses → collect them into an IPConfig → align config with what
was collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals; its `collect`
classmethod is a comprehension over the global addresses, first IPv4 and first IPv6
picked with `next(...)`, so the two boolean flags have no reason to exist. The
mutating helpers were renamed `align_ipv4`/`align_ipv6` — "align" admits the side
effect that "parse" hid. Full worked study, including the leaf type and the test
payoff: `../examples/storify-leaf-type.md`.

## Design guidance

- **One conceptual level per function.** A function states *what* happens; the *how*
  lives one level down behind a named call. If you can explain the flow in 3–5 steps,
  the code should be those 3–5 calls.
- **Comments naming blocks are extraction orders.** `// validate input`,
  `// build query`, `// already added. skip` — extract a function and name it after
  the comment; the comment then disappears because the name carries it.
- **Extracted steps want owners.** When an extracted step operates on data it could
  own, don't leave it a free function — make it a method on a type (a leaf,
  `R1-primitive-obsession.md`); where that type then lives is
  `R4-helper-placement.md`. Storifying is how leaf types are discovered.
- **Boolean flags tracking loop state** (`addrIP4Added`, `isClusterCIDRSet`) signal a
  collection or domain type waiting to absorb the loop.
- **Honest naming.** A name must reveal side effects: `align`/`upsert`/`set` mutate;
  `parse`/`validate`/`is` must not. A `validateX` that mutates is a storifying bug
  even if the flow reads well.
- **Size and shape limits**: functions under 50 LOC, at most 2 nesting levels; deeply
  nested if/else becomes early returns or extracted functions.

## Fix pattern

- **Extract Function named after the comment**: each commented block becomes a call;
  the story is what remains.
- **Extract Leaf Type**: when extracted steps share data (loop flags, accumulated
  state), move them onto a new type — see `../examples/storify-leaf-type.md` for the
  full move, and `R1-primitive-obsession.md` to score whether the type is warranted.
- **Replace Nesting with Early Returns**: invert conditions, return early, flatten to
  ≤2 levels.
- **Split Phase** (Fowler): when one function interleaves decoding/parsing with
  computation — wire fields and business decisions in the same body — split it into
  phase 1, which parses input into an intermediate domain structure, and phase 2,
  which computes over that structure alone. The intermediate type is a leaf
  candidate (score per `R1-primitive-obsession.md`); when phase 1 validates, it is a
  `ParseX` constructor and the move collapses into `R2-self-validating-types.md`.
  Split Phase differs from Extract Function: extraction names a step in place, Split
  Phase introduces a data structure *between* the steps so each phase can change —
  and be tested — without the other.
- **Honest Rename**: mutating helpers get mutating names (`parseIP4` → `alignIPv4`).
- Multi-rule sequencing (storify first or extract first, and when to stop):
  `../skills/refactoring/reference.md`. Forward design of the new types:
  @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does any changed function exceed the size/shape limits?**
   Detection: run the complexity rules (ruff `C901`; `PLR0912` branches, `PLR0915`
   statements, `PLR0911` returns; `PLR1702` nesting where the repository enables
   preview rules) on the changed files; or count —
   `awk '/^(    )?def /,/^$/' <file>` per function for LOC, eyeball nesting depth.
   Violation: > 50 LOC or > 2 nesting levels — the function is doing more than
   narrating.

2. **Does one body mix abstraction levels?**
   Detection: read each changed function and list its statements' altitudes: a named
   method/function call is high; string slicing, `.split()`/`.partition()`, index
   arithmetic, `isinstance` checks, and protocol details (`json.loads`, header
   parsing) are low.
   Violation: both altitudes in the same body — e.g. `line.split(",", 2)` three lines
   from a business decision. Cite the two lines.

3. **Do block comments narrate sections inside a function body?**
   Detection: `grep -nE '^\s+# ' <file>` within function bodies (not the docstring
   under the `def`, not a `# noqa` or `# ty: ignore` directive).
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function named after the comment. Quote each
   comment's text with its line: the comment is the evidence and the function's name.

4. **Do boolean flags track state across a loop?**
   Detection: `grep -nE '^\s+[a-z_]+ = (False|True)$' <changed files>` near `for`
   and `while` loops; look for flags set inside the loop and read after it, and for
   a `for`/`else` whose `break` is the flag in disguise.
   Violation: flag-driven loops — a collection/domain type should absorb the loop
   (see `../examples/storify-leaf-type.md`).

5. **Does any function name lie about side effects?**
   Detection: for each `parse_*`/`validate_*`/`is_*`/`get_*` function in the diff
   and each `@property`, check the body for assignments to `self.` attributes or to
   a parameter's attributes or elements.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation; a mutating `@property` is the same finding with a
   worse disguise.
