# Dependency Rejection Case: Incremental Global Elimination

Demonstrates: R8
{{include "examples/language-note.md"}}
{{include "examples/dependency-rejection/intro.md"}}

## Which globals are the problem

{{include "examples/dependency-rejection/which-globals.md"}}

## Before — global chaos

{{include "examples/dependency-rejection/before.md"}}

And the testing nightmare the globals cause:

{{include "examples/dependency-rejection/before-tests.md"}}

## Step 1 — map the dependency chain

{{include "examples/dependency-rejection/dependency-chain.md"}}

## Step 2 — create the first clean island

The rejection move: the function stops *fetching* the value and starts *being given*
it — as a constructor-injected field on a new type.

{{include "examples/dependency-rejection/island-1.md"}}

## Step 3 — push the global up one level

{{include "examples/dependency-rejection/island-2.md"}}

## Step 4 — stop at the entry points

{{include "examples/dependency-rejection/entry-points.md"}}

## The test payoff

{{include "examples/dependency-rejection/test-payoff.md"}}

## Why sideways access resists testing

A global read is an input the test cannot supply through the code's own surface. To
control it, the test must write the shared variable — which serializes the whole
test binary around that variable, leaks values into unrelated tests, and still only
supports one value at a time. Constructor injection turns the same input into an
argument: each test builds its own instance, values never collide, and the
dependency is visible in the signature where reviewers and callers can see it.

## The incremental progression

```
Iteration 1: extract NATSClient        — global accesses 20 → 14, islands: 1
Iteration 2: extract OrderService      — global accesses 14 → 8,  islands: 2
Iteration 3: extract UserService       — global accesses 8 → 4,   islands: 3
Iteration 4: push to handler setup     — global accesses 4 → 2    ✅ done
```

Every iteration is a working, tested, deployable state. No big-bang refactoring —
if the work stops after iteration 2, the codebase is still strictly better than it
started.

## The decision points

1. **Bottom-up, not top-down.** Start at the deepest usage; each extraction is
   complete on its own. Top-down threading leaves half-injected layers that read
   globals underneath the new parameters.
{{include "examples/dependency-rejection/decision-points-middle.md"}}
4. **Rejection pairs with self-validation.** Once dependencies arrive through
   constructors, the constructor is the natural place to validate them
   (`../rules/R2-self-validating-types.md`) — the island trusts its fields
   thereafter.
