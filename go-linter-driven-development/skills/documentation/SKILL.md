---
name: documentation
description: |
  The repo-brain author/maintainer: writes behavior-focused documentation and wires it
  into the documentation network defined by rules/R9-repo-brain.md.
  FEATURE mode (default): after feature implementation or bug fixes — invoked by
  @linter-driven-development (Phase 5) — to document HOW THE PRODUCT BEHAVES and wire
  it into the network.
  BOOTSTRAP mode: on request ("set up docs", "create an index", "make this repo
  AI-navigable") or when FEATURE mode finds no doc root — discovers the doc root,
  builds index.md, wires CLAUDE.md, reports gaps.
  NOT a changelog - documents current behavior, not change history.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Edit
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
fixed a bug where X happened" — they want to know how X works NOW.

**Behavior over history**: document what the product DOES, not what changed. A bug fix
updates the affected section to describe correct behavior; it never appends a "Fixed:"
entry (worked examples in reference.md, "Bug Fix Documentation").

**Conciseness over completeness**: a focused doc that gets read beats an exhaustive
doc that gets skipped.
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
3. **Rung 1 — godoc**: write/refresh doc comments per R9's relevance-scaled comment
   policy, keeping the `See docs/<feature>.md` edge wherever a feature doc exists.
   Pick from reference.md's godoc menus only what earns its place for THIS symbol.
   Add testable examples (`Example_*`) for complex/core types.
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
7. **Report** in the FEATURE output format below.
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
5. **Confirm and report**: re-run R9 Q1–Q3 as confirmation — Q3 failing here means
   step 4 didn't land; repair it before reporting. The ADVISORY findings list
   carries Q1/Q2 hits plus rung-2 gaps (two-signal criterion in reference.md).
   Bootstrap wires and maps; it NEVER mass-generates content docs — those are
   written incrementally by FEATURE mode.
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
```

BOOTSTRAP mode:
```
BOOTSTRAP COMPLETE
Doc root(s): <discovered/created; per sub-project if monorepo>
Index: <docroot>/index.md built — <N> docs, <M> groups; map of maps: <yes/no>
Root wiring: CLAUDE.md @import <added/verified> (or AGENTS.md plain reference)

Advisory findings (reported, not fixed — FEATURE mode writes content):
- orphan: <doc> — no index line, no code-side edge
- broken edge: <source> → <target> (unresolved)
- gap: <package> — <dangling code→docs edge | entry points with no citing doc>
- stale: <doc> — indexed with ⚠️ flag; cites unresolved <symbol>
```
</output_format>

<success_criteria>
- Every fact sits at its lowest viable rung of the documentation ladder; nothing
  duplicated across rungs (R9 placement rule).
- New/updated docs joined the network: indexed, root-wired, edges in both directions.
- FEATURE: the R9 self-check ran and every hit was fixed before reporting.
- BOOTSTRAP: root(s) + index + wiring exist; gaps reported; zero content docs
  generated.
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
</constraints>
