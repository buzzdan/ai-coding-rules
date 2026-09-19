# R4 — Helper Visibility & Placement

## Principle

Every extraction raises a second question: where does the helper live? The answer is
decided by two axes — juiciness (the scorecard in `R1-primitive-obsession.md`; cite
it, never re-derive it) and scope (feature-specific versus domain-generic). Three
rungs: underscore-prefixed in place, feature sub-package, shared domain package. Never test
privates, and never export a helper into its parent package just so a test can reach
it.

## Why

Wrong placement rots in both directions. Helpers exported into the parent package for
testability pollute its API — callers see symbols that exist only for tests, and the
package's real surface becomes unreadable. Juicy helpers buried as underscore-prefixed code
either go untested or push the team into testing privates, breaking the
public-API-only discipline (`R7-test-placement.md`). And role-named dumping grounds
(`util`, `helpers`, `common`) accrete unrelated code that nobody can find, name, or
own. Placement is what lets extraction deliver its promise: isolated, literal-input
unit tests against a legitimate public API.

## Canonical example

From the Port case (`R1-primitive-obsession.md` carries the full three-stage study).
After extraction, `Port`/`Ports`/`first_named`/`first` say nothing about Kubernetes
or Weka: juicy (range validation, collection queries) and domain-generic → rung 3,
a shared `networking` package. The feature keeps a two-line storified policy method:

```python
def management_port(self) -> networking.Port | None:
    return self.ports.first_named(WEKA_API_PORT) or self.ports.first()
```

Only the domain-generic parts were promoted: the `WEKA_API_PORT` constant is feature
policy and stays in the feature. A shared package that knows one feature's port names
is not shared vocabulary — it is leaked policy.

The rung-1 contrast — a trivial helper that stays put:

```python
def _parse_k3s_argument(arg: str) -> tuple[str, str] | None:
    """One caller, no domain vocabulary, no rules of its own: stays private."""
    key, sep, value = arg.partition("=")
    return (key, value) if sep else None
```

There is no urge to test this directly — and that absence is the point: the promotion
signal (below) never fires. The rungs in Python: rung 1 is a leading-underscore name
in the same module, covered through the module's public API; rung 2 is the feature
package (a directory with `__init__.py` that re-exports the public names in
`__all__`); rung 3 is a shared package under the project's source root, named for a
domain vocabulary. There is no `internal/` convention — the underscore and `__all__`
carry visibility.

## Design guidance

### The placement ladder

1. **Trivial helper** → underscore-prefixed, same package, tested only through the parent's
   public API.
2. **Juicy + feature-scoped** → vertical-slice feature sub-package (e.g. `kubefwd/`)
   *if the feature has enough substance to be a package*; types exported there. See
   `R5-vertical-slice.md`.
3. **Juicy + domain-generic** → shared domain-named library package:
   `internal/pkg/<domain>` (default) or `pkg/<domain>` (public). Granularity: a
   package is a domain *vocabulary* (`networking`), not a single noun (`kubeport`),
   never a role (`util`/`helpers`/`common`).

"Juicy" is the verdict of R1's scorecard — `R1-primitive-obsession.md` is its only
home.

### The promotion signal

**The urge to unit-test a helper directly means it deserves its own package.** Never
act on that urge by testing privates, and never by exporting the helper into the
parent. The urge is data: it says the helper has enough behavior to be a unit of its
own — so give it a real home (rung 2 or 3) where its exported API is legitimately
testable with literal inputs.

### The reuse objection

"Nobody else uses it, so it can't justify a package." Wrong premise: reuse is not the
only justification for extraction — isolated testability and readability count on
their own. And the pollution worry it hides is solved by *placement*, not by inlining
the logic back: a helper in its own domain package pollutes nothing.

### Granularity

Name shared packages after a domain vocabulary with room for siblings: `networking`
can grow `Port`, `Ports`, addresses, CIDRs. A single-noun package (`kubeport`) is a
vocabulary of one — fold it into the vocabulary it belongs to. A role name (`util`,
`helpers`, `common`) describes no domain at all and is never acceptable.

## Fix pattern

- **Demote (rung 1)**: a helper exported from its parent only so tests can reach it →
  unexport it, delete the direct tests, cover it through the parent's public API.
- **Promote to feature sub-package (rung 2)**: a juicy, feature-scoped helper being
  tested through awkward big-object setups → move it into the feature's
  vertical-slice sub-package (`R5-vertical-slice.md`), export it there, test its
  public API directly.
- **Promote to domain package (rung 3)**: a juicy, domain-generic helper → create or
  extend `internal/pkg/<domain>`; move the generic types; leave feature policy home
  as a thin storified method (see Stage 2 of `R1-primitive-obsession.md`'s canonical
  example).
- **Split policy from vocabulary during promotion**: feature constants and preference
  logic stay in the feature; only the domain-generic types and queries move.
- **Move Method to the Envied Type** (Fowler: Feature Envy → Move Function): a
  function that reads another type's data more than its own belongs on that type —
  move it there, then place the enriched type on the ladder as usual. If the envied
  type is foreign (another module's DTO), wrap it first (`R1-primitive-obsession.md`)
  and hang the behavior on the wrapper.
- **A message chain is a placement signal, not a wrapper order** (Fowler: Message
  Chains). Before "fixing" `order.Customer().Address().City()` by adding a
  `CustomerCity()` forwarder, ask what the caller *does* with the endpoint (Tell,
  Don't Ask — `../maxims.md`): a decision or computation → that behavior moves onto
  the chain's owner (Move Method to the Envied Type, above), where the chain
  collapses into a one-hop walk of the type's own composition — which was never the
  problem. Only data egress at a boundary (rendering, serialization, wire mapping)
  legitimately keeps the chain, and there it lives as a one-shot mapping inside the
  adapter, not scattered through domain code.
- **A type speaks for its parts only when it has something to add** (Fowler: Middle
  Man). A method whose entire body is `return o.x.Method()` — no decision, no
  combination, no invariant — is R1's ceremony verdict applied per method: the
  indirection owns nothing, so it goes. A type whose surface is mostly such forwards
  is a worse copy of its field's API — delete the forwards and hand callers the part
  (`o.Customer()`), keeping only delegations that carry a rule (`ShippingAddress()`
  choosing gift recipient over buyer earns its place; `CustomerEmail()` does not).
  The accelerant: embedding or inheriting a domain type manufactures this smell in
  one line by promoting the entire foreign API onto the outer type — embed or inherit
  for genuine is-a, never to save typing `o.customer.`.
- Multi-rule extraction sequencing: `../skills/refactoring/reference.md`. Forward
  design of the promoted package: @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Is a symbol public only so tests can reach it?**
   Detection: for each newly public function/class (no leading underscore, or newly
   listed in `__all__`),
   `grep -rn '<Symbol>' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` —
   count non-test references outside its defining module.
   Violation: zero production call sites outside the package while test files
   reference it — it was made public for tests; demote (rung 1) or promote
   (rung 2/3).

2. **Are `_private` helpers tested directly?**
   Detection: `grep -rnE 'import _[a-z]|from [a-z_.]+ import .*\b_[a-z_]+|\._[a-z_]+\(' --include='test_*.py' --include='*_test.py' .`
   — an import of a `_private` name, or a call through `obj._helper(...)` in a test
   body. `monkeypatch.setattr(mod, "_helper", ...)` is the same reach with a
   different verb.
   Violation: any direct test of a private helper — that urge is the promotion
   signal; give the helper its own module or package instead. The underscore is a
   convention, not a wall: the test runs, and that is why the question is asked.

3. **Does a new shared package have a role name?**
   Detection: `find . -name '*.py' -not -path '*/.venv/*' | grep -iE '/(util|utils|helpers|helper|common|shared|misc)(\.py|/__init__\.py)$'`
   Violation: any hit — `utils.py` and `common.py` are the Python spelling of the
   role-named package; modules are named for a domain vocabulary, never a role.

4. **Is a new shared package a single noun rather than a vocabulary?**
   Detection: `grep -cE '^class [A-Z]' <package>/*.py` and ask whether plausible
   domain siblings exist under the name.
   Violation: a package named after its one type (`kubeport/`) with no room for
   siblings — fold into a vocabulary package (`networking/`) or keep at rung 1/2.

5. **Did feature policy leak into a shared package?**
   Detection: grep the shared package for feature-owned literals and constants, e.g.
   `grep -rn '"weka-' <shared package>/`.
   Violation: any feature-specific literal or preference decision inside a
   domain-generic package — policy stays in the feature (Stage 2 of
   `R1-primitive-obsession.md`).

6. **Does a changed function envy another type's data?**
   Detection: for each changed function/method, count attribute accesses per value:
   `grep -oE '\bself\.[a-zA-Z_]+' <func body> | sort | uniq -c` versus the same
   count for its most-touched parameter (`grep -oE '\b<param>\.[a-zA-Z_]+'`).
   Violation: accesses on one foreign value outnumber accesses on `self` (or on all
   local data, for a free function) and the foreign type is yours to extend — Move
   Method to the Envied Type, then re-place via the ladder. A function that merely
   *reads* a foreign DTO once to adapt it at a boundary is not envy.
