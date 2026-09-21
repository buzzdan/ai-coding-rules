---
type: feature
description: the coding-rules handbook — the standalone document a team reads without the plugin, how it is generated from the same rules, what a binding writes for it, and how to consume and measure it
---
# The Coding-Rules Handbook

## Problem & Solution
**Problem**: not every team that shares these rules develops with the plugin. The
hand-written coding rules that preceded the plugin fell behind it: no Anti-IF, no
mutation discipline, no earned-interface test, no composition ladder. A second
hand-written copy would fall behind again.

**Solution**: `coding-rules/<lang>.md` is generated from the plugin's own sources by
`tools/ldd-gen`, in the same run as the plugin directory. Most of it is extraction,
not summary: the Principle paragraph of each rule, the move names from each Fix
pattern, the headlines of the falsifying questions, and the maxims' "Ask" lines are
read from `core/` and the binding at generation time. What the binding writes for
the handbook alone is one short example per rule, the language's house rules and a
few mechanics rows. `task check` fails when the file on disk differs from the
rendering, the same as for a plugin directory.

## Shape

| Section | Source |
|---|---|
| Mindset | nine maxims, chosen in the template, each rendered from its `**Ask:**` paragraph in `core/maxims.md` |
| The twelve rules | per rule: the `## Principle` of `core/rules/Rn-*.md` through the binding's scalars; the binding's `handbook/Rn/example.md`, a before-and-after with an optional `> **In <Lang>:**` aside for the language's position, else the core default under `core/includes/handbook/Rn/`, the same shape in pseudocode closed by a `> **Spelling:**` aside that names the per-language form; the move names from the rule's Fix pattern |
| House rules | first the shared rules `H1…`, each stated once in `core/includes/handbook/Hn/rule.md`, with the language's spelling aside and `**Review:**` line in the binding's `handbook/Hn/spelling.md` (a neutral core default stands in where a binding has none); then the binding's `handbook/house-rules.md`, the rules that exist only in that language (`G1…` for Go, `P1…` for Python), each a heading, a short principle and one `**Review:**` line |
| Self-review | two or three question headlines per rule, chosen by number in the template from the binding's `rules/Rn/falsifying-questions.md`, plus every house rule's review line |
| Mechanics | the profile's test, lint, lint-fix, suppression and doc-form scalars, plus the binding's `handbook/mechanics.md` rows |

The template is `core/handbook/coding-rules.md`; the constructs it may use and what
each renders are in the "The handbook" section of `core/README.md`. Move names are
core text and identical in every rendering, so a reviewer citing "Separate Failure
from Absence" is understood across languages. The house-rule numbers and the
`In <Lang>` asides are where the languages differ on purpose. A house rule two
bindings both end up writing is the signal it is core doctrine: it moves to a shared
`H` rule, stated once under `core/includes/handbook/` with a spelling aside per
binding, and the further step, when the plugin's reviewers should hunt it, is a
numbered rule with detection commands. Suppressions (H1) and errors (H2) took the
first step; the Python bucket-module rule (the old P3) was already R5's Principle and
went back into the Python R5 aside.

## The residue gate

A rendered handbook shows each Principle without the same-language example that
sits beside it in the plugin, which is where a sentence still reasoning from Go
shows: R1 once listed Go's type names, R8 said `main`, R12 said slices and maps.
So the generator treats every handbook for a binding other than Go as a gate: the
render fails on any hit of the residue scanner's hard or soft tokens in the
rendered text, naming the line, except for the asides `docs/language-residue.md`
keeps as the general term in every language (`interface`, `struct`). The fix is
always a neutral rewording of the core sentence, or of the binding's own include
when the hit is there; never a suppression. The Go handbook is exempt because the
scanner's tokens name Go.

## Consuming it

Copy `coding-rules/go.md`, `coding-rules/python.md` or, for a language without a
binding, `coding-rules/generic.md` into the project, or reference it from a pinned release
tag, and import it from `CLAUDE.md` or `AGENTS.md` with an `@` line. It stands alone:
no plugin, no agents, no detection commands. The file opens with a marker comment
saying it is generated; the generator refuses to overwrite a file at the handbook
path that lacks that marker, so a hand-edited copy in a consuming repository is safe
from a stray `task generate` and simply falls behind.

## Adding a handbook to a binding

Set `handbook: coding-rules/<lang>.md` in the binding's `profile.yaml` and write
`handbook/R1/example.md` to `handbook/R12/example.md`, `handbook/house-rules.md` and
`handbook/mechanics.md` under `lang/<lang>/`. The examples have a core default, the
pseudocode under `core/includes/handbook/`, so a language binding that leaves one out renders
pseudocode where its readers expect their language: write all twelve. The house rules
and the mechanics rows have no core default, and a missing one fails the render with
the include name. The shared house rules render from core defaults, and a binding
adds `handbook/Hn/spelling.md` to replace the neutral spelling note with its own and
to word the review question in its terms.

All three bindings render a handbook. The generic binding's, `coding-rules/generic.md`,
is the core defaults end to end: the pseudocode examples, the neutral spelling
asides for H1 and H2, and, from `lang/generic/handbook/`, the two house rules that
exist because no binding knows the repository's language (`A1`, the repository's
tooling is the tooling; `A2`, spell the shape in the repository's idiom) and the
mechanics rows about discovering the commands. It is the document for a team whose
language has no binding, and the reference rendering of what core says on its own.

## Measuring it

The behavioral evals ([eval-harness.md](eval-harness.md)) measure the plugin on
go-mini. The handbook's value is the same question with a different scaffold: the
same case prompts, the handbook in the fixture's `CLAUDE.md` and no plugin
installed, graded by the same graders and the plugin's own whole-repository review.
Three numbers per case then say what the document buys: bare model, handbook only,
full plugin. That scaffold lives in the evals repository and is not written yet.
