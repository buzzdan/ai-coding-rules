## Docstring Menus

**These are MENUS, not forms** (normative: R9's tiered comment-budget policy —
**1–5 prose lines** scaled to the symbol's role; blank lines, the See-edge, `Args:`,
`Returns:` and `Raises:` sections, and short doctests of 2–4 lines are free). The
menus price **public** API only — `_private` symbols default to no docstring at all
(R9's visibility default; special case: one very-high-value line), and carry no
ruff `D` obligation. The WHY is the default content; the tier caps how much of a
menu any one symbol can order:

- **Helper** (small method, plain constructor, obvious accessor) → 0–1 line, or
  nothing; a tiny doctest only if it clarifies.
- **Contract** (`parse` classmethod, self-validating type, ordinary public API) →
  2–3 lines; a dos/don'ts doctest is free and often earns its place.
- **Crossroads** (entry point, orchestrator, state machine, feature front door) →
  up to 5 lines: WHY, architectural context, use cases.

Overflow never stays inline — it moves to the feature doc; the
`See docs/<feature>.md` edge (kept whenever the doc exists) carries the pointer. A
crossroads that deserves more than 5 lines inline gets an expand recommendation in
the FEATURE report instead of extra lines — a human decides (R9's escape hatch).

What fills the chosen menu lines comes from the [Comment Value Toolbox](#comment-value-toolbox)
above — every prose line must deliver one of its values, in plain English (R9's
three-test standard).

**The summary line is the contract, not a restatement.** PEP 257's first line — one
sentence, ending in a period, on the line of the opening quotes — states what the
symbol promises (`"""A named, validated service port; it cannot exist out of
range."""`). It is exempt from the critic's restatement verdict when it does that,
and a finding when it repeats the name (`"""Get the user."""` on `get_user`). The
body, after one blank line, is where the WHY budget applies. The menus below use
the Google convention (`Args:`/`Returns:`/`Raises:`); match the repository's
convention when it declares one in `[tool.ruff.lint.pydocstyle]`. Where the
repository's `D` rules require a docstring, a WHAT-docstring is rewritten, never
deleted; on a `_private` name it is deleted.

### Module Docstring Menu

Pick only the lines this module or package needs:

```python
"""[High-level purpose of the module, one line].          <- always (one line)

[1-2 sentences: what problem this solves]                 <- usually

Main data flow:                                           <- only if non-obvious
  Input -> Validation -> Processing -> Output

Core types:                                               <- multi-type modules only
  - Type1: [key responsibility]

Design decisions:                                         <- only where rationale exists
  - [Key decision and why]

See docs/[feature].md for architecture and usage.         <- whenever the doc exists
"""
```

**The `__init__.py` hatch (R9):** when a package genuinely earns more than the
standard budget — flow sketch, core-types list, and design decisions all pulling
their weight — the package docstring lives in `__init__.py`, bounded at ~20–30
lines, and the modules inside keep to the standard tier budget.

### Class Docstring Menu

Pick per symbol kind (hints above):

```python
class TypeName:
    """[One-line domain meaning].                         <- always

    [WHY it exists: rationale, incident, constraint —     <- the default content
    context the code cannot carry]

    Constraints:                                          <- self-validating types
      - [validation rules, thread-safety guarantees]

    Use cases / flow:                                     <- logic-heavy types only
      [when to reach for it, or a short flow sketch]

    >>> Policy.parse("3x100ms").attempts                  <- parse classmethods:
    3                                                        dos/don'ts inputs
    >>> Policy.parse("0x")
    Traceback (most recent call last):
    ValueError: zero attempts

    See docs/[feature].md for the full picture.           <- whenever the doc exists
    """
```

### Function Docstring Menu

Only for non-obvious behavior; a small method or plain constructor gets one line, or
nothing:

```python
def function_name(input: InputType) -> OutputType:
    """[Does what] for [purpose].                         <- always, if documented at all

    [Non-obvious behavior, performance characteristics]   <- only when non-obvious

    Args:                                                 <- when a parameter needs more
      input: [what a valid value is, not its type]           than its name and annotation

    Raises:                                               <- the failure contract,
      ValueError: [when]                                     when callers must handle it

    See docs/[feature].md#section for the detailed flow.  <- whenever the doc exists
    """
```

### Doctest Template

```python
class UserId:
    """A validated user id.

    >>> UserId.parse("usr_123")
    UserId('usr_123')
    >>> UserId.parse("")
    Traceback (most recent call last):
    ValueError: empty user id
    """
```

Doctests run under `pytest --doctest-modules` (or the repository's doctest runner)
and show happy-path usage plus the one rejection that defines the contract. Keep
simple — complex scenarios belong in feature docs.
