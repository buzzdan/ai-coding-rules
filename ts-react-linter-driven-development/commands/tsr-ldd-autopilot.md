---
name: tsr-ldd-autopilot
description: Start complete linter-driven autopilot workflow (Phases 1-5, incl. the autonomous PREPARE sub-phase 1.5)
argument-hint: "[what to build or fix]"
allowed-tools:
  - Skill(ts-react-linter-driven-development:linter-driven-development)
---

**Use the Skill tool** to invoke `Skill(ts-react-linter-driven-development:linter-driven-development)` to run the complete workflow — Phases 1–5 plus the autonomous PREPARE sub-phase (1.5) — from design through commit-ready.

**The request** is `$ARGUMENTS` when given — "fix the retry bug in the API client", "add
rate limiting to the upload handler" — else the request already in the conversation.
Hand it to the skill as the change to deliver. With no argument and no request in the
conversation, ask what to build before pre-flight; never start the workflow over an
empty request.

⏱️ **Estimated Duration**: 5-15 minutes (depends on feature complexity and issues found)

The skill runs, in order:
1. **Pre-Flight** — verify TypeScript + React project, discover test/lint commands, list the behaviors to deliver
2. **Phase 1 DESIGN** — @code-designing produces a DESIGN PLAN for your approval (no code before OK)
3. **Phase 1.5 PREPARE** — autonomous preparatory refactoring: survey the plan's touch points, four gates decide (multiply/safe/bounded/skeptic), reshape via @refactoring in its own commit(s) — no pause for approval
4. **Phase 2 IMPLEMENT** — per behavior: RED (one failing test) → GREEN (minimum code) → REFACTOR (package-scoped lint + rule greps → @refactoring)
5. **Phase 3 FULL LINT** — one full-repo run via the `ts-react-linter-driven-development:lint-fixer` agent (isolated context); mechanical fixes done, design failures escalated back to Phase 2's REFACTOR via @refactoring
6. **Phase 4 REVIEW** — per completed slice, @pre-commit-review orchestrates parallel `ts-react-linter-driven-development:rule-hunter` agents + the `overabstraction-skeptic`; advisory findings only
7. **Phase 5 SHIP** — @documentation, the commit of the green slice, then a ship summary with its hash; you decide only about deferred advisory findings

This is the full workflow — use for implementing features or fixes from start to finish.
