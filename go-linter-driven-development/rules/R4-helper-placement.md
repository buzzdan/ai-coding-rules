# R4 — Helper Visibility & Placement

## Principle

Every extraction raises a second question: where does the helper live? The answer is
decided by two axes — juiciness (the scorecard in `R1-primitive-obsession.md`; cite
it, never re-derive it) and scope (feature-specific versus domain-generic). Three
rungs: unexported in place, feature sub-package, shared domain package. Never test
privates, and never export a helper into its parent package just so a test can reach
it.

## Why

Wrong placement rots in both directions. Helpers exported into the parent package for
testability pollute its API — callers see symbols that exist only for tests, and the
package's real surface becomes unreadable. Juicy helpers buried as unexported code
either go untested or push the team into testing privates, breaking the
public-API-only discipline (`R7-test-placement.md`). And role-named dumping grounds
(`util`, `helpers`, `common`) accrete unrelated code that nobody can find, name, or
own. Placement is what lets extraction deliver its promise: isolated, literal-input
unit tests against a legitimate public API.

## Canonical example

From the Port case (`R1-primitive-obsession.md` carries the full three-stage study).
After extraction, `Port`/`Ports`/`FirstNamed`/`First` say nothing about Kubernetes or
Weka: juicy (range validation, collection queries) and domain-generic → rung 3,
`internal/pkg/networking`. The feature keeps a four-line storified policy method:

```go
func (s kubeService) managementPort() (networking.Port, bool) {
    if p, ok := s.ports.FirstNamed(kubeWekaAPIPort); ok { return p, true }
    return s.ports.First()
}
```

Only the domain-generic parts were promoted: the `"weka-api"` constant is feature
policy and stays in the feature. A shared package that knows one feature's port names
is not shared vocabulary — it is leaked policy.

The rung-1 contrast — a trivial helper that stays put:

```go
// Trivial: one caller, no domain vocabulary, no rules of its own.
// Stays unexported; covered through the parent's public API.
func parseK3SArgument(arg string) (key, value string, ok bool) {
    parts := strings.SplitN(arg, "=", 2)
    if len(parts) != 2 {
        return "", "", false
    }
    return parts[0], parts[1], true
}
```

There is no urge to test this directly — and that absence is the point: the promotion
signal (below) never fires.

## Design guidance

### The placement ladder

1. **Trivial helper** → unexported, same package, tested only through the parent's
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
- Multi-rule extraction sequencing: `../skills/refactoring/reference.md`. Forward
  design of the promoted package: @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Is a symbol exported only so tests can reach it?**
   Detection: for each newly exported func/type,
   `grep -rn '<Symbol>' --include='*.go' . | grep -v _test.go` — count non-test
   references outside its defining file.
   Violation: zero production call sites outside the package while `*_test.go`
   references exist — it was exported for tests; demote (rung 1) or promote
   (rung 2/3).

2. **Are unexported helpers tested directly?**
   Detection: `grep -rL '^package .*_test$' --include='*_test.go' .` to find
   internal test packages, then grep those files for calls to lowercase functions
   defined in the package.
   Violation: any direct test of a private helper — that urge is the promotion
   signal; give the helper its own package instead.

3. **Does a new shared package have a role name?**
   Detection: `ls internal/pkg pkg 2>/dev/null | grep -iE '^(util|utils|helpers|helper|common|shared|misc)$'`
   Violation: any hit — packages are named for a domain vocabulary, never a role.

4. **Is a new shared package a single noun rather than a vocabulary?**
   Detection: `grep -c '^type [A-Z]' internal/pkg/<name>/*.go` and ask whether
   plausible domain siblings exist under the name.
   Violation: a package named after its one type (`kubeport`) with no room for
   siblings — fold into a vocabulary package (`networking`) or keep at rung 1/2.

5. **Did feature policy leak into a shared package?**
   Detection: grep the shared package for feature-owned literals and constants, e.g.
   `grep -rn '"weka-' internal/pkg/`.
   Violation: any feature-specific literal or preference decision inside a
   domain-generic package — policy stays in the feature (Stage 2 of
   `R1-primitive-obsession.md`).
