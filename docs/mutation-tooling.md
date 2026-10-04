---
type: architecture
description: why the Go binding's R7 runs gremlins and not mewt — the four requirements the rule puts on a mutation tool, both tools measured on the same leaf packages, the blind spots the hand check covers, and the three changes in mewt that would reopen the decision
status: stable
---
# Mutation Tooling for the Go Binding

R7's seventh falsifying question, "does a mutant survive a leaf type's tests?", names
one tool per language in the mutation-mechanics include that
[language-residue.md](language-residue.md) describes. For Go that tool is
go-gremlins. This page records why, against the one serious alternative, so the
choice is re-made on evidence rather than remembered.

## What the rule needs from the tool

The question is scoped to leaf packages and promises a run that fits in seconds to a
minute, so the hunter runs it after every fix. That scope puts four requirements on
the tool, in this order:

1. It never touches the checkout it hunts in. The hunter may be interrupted, and other
   processes (hooks, editors, worktrees) watch the same files.
2. One leaf package runs in about a minute, so the hunt-fix-rerun loop stays tight.
3. Survivors come out as a list with a location and the mutation applied, which is all
   the hunter needs to write the killing row.
4. It installs the way a Go repository installs its other tools, so the missing-tool
   path the mechanics describe (a `mutate` target or one `go install` line) is honest.

Richer output, re-testing one mutant by id, and a larger mutation catalogue are
welcome but rank below these four.

## The two tools, measured on the same code

Both ran over the four leaf files of the go-mini eval fixture that
[eval-fixture.md](eval-fixture.md) describes, on the tree as it stood on 2026-10-04:
deviceid, tenant, the string helpers and the placement picker.

| | go-gremlins 0.6.0 | mewt 4.0.0 (Trail of Bits) |
|---|---|---|
| Mutants generated | 28 | 208 |
| Wall time | about 5 seconds | 63 seconds |
| Survivors reported | 7 | 20 |
| Where it mutates | a copy of the module | the checkout, restored from its database afterwards |
| Pre-filter | coverage: uncovered mutants are never run | none; a severity skip within one line |
| Statuses | KILLED, LIVED, TIMED OUT, NOT COVERED, NOT VIABLE | Caught, Uncaught, Timeout, Skipped |
| Build failures | NOT VIABLE, excluded from efficacy | counted as Caught: 51 of 183 here |
| Survivor record | type, status, line, column | id, old and new text, test output; JSON and SARIF |
| Re-test one mutant | no | yes, by id |
| Install | `go install` | prebuilt binary (Linux x86_64, macOS arm64) or cargo; AGPL-3.0 |

mewt's survivor set is a superset of gremlins'. Every boundary row gremlins asked for,
mewt asked for too, and it added three real ones gremlins cannot see: an ordering row
for an equality check, a row on the far side of a constant, and the `<=` form of each
empty-string test. The rest of its extra survivors were argument swaps inside error
messages and an equivalent literal flip.

## Why gremlins stays

Requirements 1 and 2 decide it. mewt rewrites the real source file for every mutant and
restores it when the campaign ends, so an interrupted run leaves a mutated tree. And
without a coverage pre-filter its mutant count is seven times gremlins' on the same
code; a leaf package where gremlins runs 186 mutants in two minutes becomes an
hour-scale campaign, which breaks the promise that justifies the leaf-only scope.
Counting build failures as caught makes mewt's headline efficacy wrong by a quarter;
the rule reads the survivor list, not the rate, so this alone would not have decided
it, but any text that quoted the rate would need a caveat.

## The blind spots the hand check covers

gremlins never mutates an equality operator or a literal constant. The Go mechanics
say so, and Q7's hand check asks for a row at each boundary and one past it precisely
so the two findings above are reached by a reviewer who runs no tool. One adopting
repository also reports that expressions inside a `switch` case come back NOT
COVERED; that is recorded here as reported, not reproduced on the fixture.

## What would reopen the decision

Any one of these in a mewt release is reason to re-run the comparison above:

- mutating a copy of the tree, or a restore that survives an interrupted run;
- a coverage or test-selection pre-filter, or any change that brings a leaf package of
  a few hundred gremlins mutants under a minute;
- a status for mutants that fail to build, separate from caught.

A repository that adopts either tool wraps it in one task (`mutate`), so a change here
costs it one task edit and one documentation line.
