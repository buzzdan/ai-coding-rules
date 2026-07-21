---
name: documentation
description: |
  The repo-brain author/maintainer: writes behavior-focused documentation and wires it
  into the documentation network defined by rules/R9-repo-brain.md.
  FEATURE mode (default): after feature implementation or bug fixes — invoked by
  @linter-driven-development (Phase 5) — to document HOW THE PRODUCT BEHAVES and wire
  it into the network.
  BOOTSTRAP mode: on request ("set up docs", "create an index", "make this repo
  AI-navigable", /wire-repo-brain) or when FEATURE mode finds no doc root — discovers
  the doc root, builds index.md, wires CLAUDE.md, wires missing code→docs edges,
  reports gaps.
  NOT a changelog - documents current behavior, not change history.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Edit
  - Agent
---

<objective>
Author and maintain the repo brain: a documentation network where any entry point — a
grep hit on a symbol, a file open, CLAUDE.md at session start — reaches full context
within two hops. Everything normative (the documentation ladder, both network
invariants, the comment policy, the edge policy, the index policy, root wiring,
doc-root discovery) lives ONCE in `../../rules/R9-repo-brain.md`; this skill is the
actor that applies it. Templates live in `reference.md` — they are menus, never forms.
</objective>

<philosophy>
**The 5-Year Reader Test**: someone reading this in 5 years doesn't care that "we
fixed a bug where X happened" — they want to know how X works NOW. This holds for
comments as much as docs: a PR number, review item, or "the previous behavior"
narration in a godoc is provenance, not behavior (R9's floor names it a failure
mode).

**Behavior over history**: document what the product DOES, not what changed. A bug fix
updates the affected section to describe correct behavior; it never appends a "Fixed:"
entry (worked examples in reference.md, "Bug Fix Documentation").

**Conciseness over completeness**: a focused doc that gets read beats an exhaustive
doc that gets skipped.

**Plain words over clever words**: everyday English, short sentences, one idea per
sentence. Not all readers are native English speakers — a doc that needs a
dictionary fails even when it is true (R9's plain-English test; applies to godocs
and feature docs alike).
</philosophy>

<mode_selection>
**FEATURE** is the default: run it after a feature or bug fix lands (ldd Phase 5).
Switch to **BOOTSTRAP** when the user asks to wire a repo ("set up docs", "create an
index", "make this repo AI-navigable") or when FEATURE step 1 finds no doc root.
Skip entirely for individual commits and internal refactors that change no behavior —
unless an R9 Q6 check shows a doc citing the reshaped code.
</mode_selection>

<feature_mode>
1. **Scope**: establish what shipped — the feature's commits/diff, which packages and
   entry points it touches.
2. **Place each fact on the documentation ladder**: apply R9's rung table and
   placement rule (`../../rules/R9-repo-brain.md`, Design guidance). Before writing
   any comment, first check whether a rename or extraction makes it unnecessary.
3. **Rung 1 — godoc**: write/refresh doc comments per R9's comment policy — every
   comment must pass R9's three-test standard BEFORE it is written (toolbox-value,
   tier budget, plain English), with content picked FROM the Comment Value Toolbox
   (catalog in reference.md) for the symbol's tier: 1–5 prose lines, helper /
   contract / crossroads; overflow moves to the feature doc. Keep the
   `See docs/<feature>.md` edge wherever a feature doc exists. A package that
   earns more moves its godoc to `doc.go` (R9's ~20–30 line bound). A crossroads
   that deserves richer inline godoc stays within budget and gets an expand
   recommendation in the report — never extra lines. Add testable examples
   (`Example_*`) for complex/core types.
4. **Rung 2 — feature doc**: create/update `<docroot>/<feature>.md` from the
   reference.md template: `Related` edges to sibling docs; key players as
   `Symbol | Role | Package`; entry points cite symbols — never file paths or line
   numbers (R9 edge policy). Bug fix → update the existing doc's affected section;
   do not create a new doc.
5. **Rung 3 — the map**: add/refresh the doc's one line in `index.md`; verify root
   wiring (`@<docroot>/index.md` import in CLAUDE.md, AGENTS.md fallback).
6. **Self-check**: run R9's falsifying-question detections on the touched scope —
   Q1–Q3 mechanically (orphans, broken edges in both directions, unwired root),
   Q4–Q6 over the diff (WHAT-comments, naked exported API, silently-changed doc).
   The detection commands live in R9; never restate them. Fix every hit before
   reporting.
7. **Comment critique**: spawn the `comment-critic` agent (Agent tool) on the full diff —
   not just the comments this run wrote; in-body comments left by earlier phases
   are in scope too. Its spawn prompt MUST contain: (a) R9's comment-policy
   section pasted verbatim (toolbox kinds, three-test standard, tiers, budget
   accounting); (b) reference.md's Comment Value Toolbox catalog pasted verbatim;
   (c) the diff scope. Apply every non-KEEP verdict (this skill is the rung-1
   fixer): DELETE and TRIM as returned; REWRITE using the critic's proposal;
   `DELETE → route R3` verdicts are deleted here and reported as R3 leads for the
   caller — never fixed here (extraction is @refactoring's move). Then re-spawn
   the critic ONCE to confirm clean; a still-dirty re-critique is reported as-is,
   never looped further.
8. **Report** in the FEATURE output format below.
</feature_mode>

<bootstrap_mode>
1. **Discover doc root(s)** per R9's discovery order (`.ai/` → `.ainav/` → `docs/`;
   create `docs/` if none exists). Monorepo → one doc root + index per sub-project.
2. **Inventory existing docs** and classify each: feature / architecture / guide /
   stale (classification table in reference.md).
3. **Build or rebuild `index.md`**: a short reference guide — grouped by topic, one
   line per doc; past ~300 lines it becomes a map of maps with short sub-indexes
   (R9 index policy; templates in reference.md).
4. **Wire the root**: add the `@<docroot>/index.md` import to CLAUDE.md (create a
   minimal CLAUDE.md section if none exists); AGENTS.md has no import syntax — use
   the plain-reference fallback. Snippets in reference.md.
5. **Wire missing upward edges**: for each indexed (non-stale) doc with no code-side
   edge, add ONE line — `// See <docroot>/<file>.md ...` — to the front-door anchor's
   existing doc comment (anchor heuristic in reference.md), then confirm the package
   still vets. Wiring only: never rewrite the comment around it, never wire a stale
   doc (its ⚠️ index flag is the finding), and skip — as a reported gap — any doc
   whose anchor you cannot identify with confidence.
6. **Confirm and report**: re-run R9 Q1–Q3 as confirmation — a Q1 hit (a doc with no
   index line) means step 3 didn't land and a Q3 hit means step 4 didn't; repair
   either before reporting, and verify every edge added in step 5 resolves. The
   ADVISORY findings list carries Q2 hits plus rung-2 gaps (two-signal criterion in
   reference.md) and any doc left unwired in step 5. Bootstrap wires and maps; it
   NEVER mass-generates content docs — those are written incrementally by FEATURE
   mode.
</bootstrap_mode>

<output_format>
FEATURE mode:
```
DOCUMENTATION COMPLETE — FEATURE mode
Feature: <name>

Artifacts:
- <docroot>/<feature>.md (created/updated)
- godoc: <symbols touched, grouped by package>
- testable examples: <Example_* functions>
- index.md: <line added/refreshed>

Network edges added:
- code→docs: <symbol> → <docroot>/<feature>.md
- docs→code: <doc> → <symbols/packages cited>
- root: @<docroot>/index.md in CLAUDE.md (verified/added)

R9 self-check: Q1–Q3 clean · Q4–Q6 clean over diff
  (or per hit: <Qn>: <evidence> — fixed by <R9 fix-pattern move>)

Comment critic: <N> reviewed — <D> deleted · <T> trimmed · <R> rewritten ·
  clean on re-critique (or: <remaining verdicts, reported as-is>)
  R3 leads (in-body extraction candidates, for the caller): <file:line, ...> (omit when none)

Expand recommendations (optional — omit the section when none):
- <Symbol> — consider expanding its godoc inline beyond the doc reference:
  <one-line rationale>
```

BOOTSTRAP mode:
```
BOOTSTRAP COMPLETE
Doc root(s): <discovered/created; per sub-project if monorepo>
Index: <docroot>/index.md built — <N> docs, <M> groups; map of maps: <yes/no>
Root wiring: CLAUDE.md @import <added/verified> (or AGENTS.md plain reference)
Upward edges: <K> wired — <doc> ← <anchor symbol> (<package>), ...

Advisory findings (reported, not fixed — FEATURE mode writes content):
- unwired: <doc> — indexed, but no confident front-door anchor; needs a human call
- broken edge: <source> → <target> (unresolved)
- gap: <package> — <dangling code→docs edge | entry points with no citing doc>
- stale: <doc> — indexed with ⚠️ flag; cites unresolved <symbol>; not edge-wired
```
</output_format>

<success_criteria>
- Every fact sits at its lowest viable rung of the documentation ladder; nothing
  duplicated across rungs (R9 placement rule).
- New/updated docs joined the network: indexed, root-wired, edges in both directions.
- FEATURE: the R9 self-check ran and every hit was fixed before reporting.
- FEATURE: the comment-critic ran over the full diff, every non-KEEP verdict was
  applied (R3 routes reported, not fixed), and the one re-critique confirmed clean
  — or the remainder is reported as-is.
- BOOTSTRAP: root(s) + index + root wiring exist; every confidently-anchorable doc
  has an upward edge; gaps reported; zero content docs generated.
- All prose passes the 5-year reader test; zero changelog-style entries.
</success_criteria>

<constraints>
This skill MUST NOT:
- Restate R9 content — the documentation ladder, invariants, and policies are cited,
  never copied.
- Append change history to docs — current behavior only, always.
- Mass-generate content docs in BOOTSTRAP mode — advisory gap report only.
- Fill templates for their own sake — reference.md's templates are menus; R9's
  comment policy decides what earns its place.
- Spawn anything other than `comment-critic`, loop the critique more than one
  fix-and-recheck round, or fix `DELETE → route R3` verdicts itself (extraction
  belongs to @refactoring).
</constraints>
