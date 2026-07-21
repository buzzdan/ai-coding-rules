---
name: go-ldd-prepare
description: Preparatory refactoring — reshape the code a planned change will touch, so the feature lands add-only
argument-hint: "<what you're about to build> [files]"
allowed-tools:
  - Skill(go-linter-driven-development:refactoring)
  - Skill(go-linter-driven-development:code-designing)
  - Skill(go-linter-driven-development:testing)
  - Agent
---

Run standalone preparatory refactoring (Fowler: "make the change easy, then make the
easy change") for a change you're about to implement — without entering the full
five-phase workflow.

⏱️ **Estimated Duration**: 2–10 minutes (zero findings is the common case and takes seconds)

**Input**: a description of the impending change ("add an SMS channel to alerts",
"extend the exporter with histogram support"), optionally scoped to files. No
description → ask for one; preparation without a change in hand is just cleanup and
belongs to `/go-ldd-quickfix`.

**Steps** (the gate definitions live in @linter-driven-development
`<phase_1_5_prepare>` — apply them from there, never from memory):

1. **Locate touch points**: from the change description, identify the files,
   functions, and packages the change will extend or integrate with (grep for the
   named concepts; when ambiguous, invoke @code-designing briefly to sketch the
   landing zone).
2. **Survey**: run the rule detection greps (`../rules/R*.md` Falsifying questions)
   scoped to the touch points.
3. **Gate autonomously**: MULTIPLY → SAFE → BOUNDED → SKEPTICIZED, per
   @linter-driven-development `<phase_1_5_prepare>`. No user questions — the gates
   decide; deferred findings are reported, not asked about.
4. **Apply survivors** via `Skill(go-linter-driven-development:refactoring)` in
   `<preparatory_mode>`: characterization tests first on uncovered paths, full suite
   green after every move, prep work in its own commit(s).
5. **Emit the PREPARATION LOG** and state the landing shape ("adding the SMS channel
   is now one new file + one ParseChannel case").

Use this before starting work on a known change. For fixing code that already fails
gates, use `/go-ldd-quickfix`; for a read-only assessment, `/go-ldd-analyze`.
