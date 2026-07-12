---
name: go-ldd-quickfix
description: Run quality gates loop until all green (tests+linter+review → fix → repeat)
argument-hint: "[file_pattern]"
allowed-tools:
  - Skill(go-linter-driven-development:linter-driven-development)
---

Execute the quality-gates loop for already-implemented code that needs cleanup.

⏱️ **Estimated Duration**: 2-5 minutes (depends on number of issues found)

**Use the Skill tool** to invoke `Skill(go-linter-driven-development:linter-driven-development)`. Because the code already exists, it skips the design and TDD-implementation phases (Phases 1–2) and runs the quality gates until green:

**Phase 3 — TESTS + FULL LINT** (via the `lint-fixer` agent, Task, isolated context)
- Discover project test/lint commands (`task test` / `make test` / `go test ./...`; lint from Taskfile/Makefile or `golangci-lint run --fix`)
- Run the discovered test command first; all tests must pass before the lint pass proceeds (a test failure is a fix target, not a skip)
- One full-repo lint run; mechanical issues are `FIXED` in place
- Design-level failures come back `ESCALATED` with a rule route
- Route each escalation through @refactoring (its `<routing_table>` maps linter failure → owning rule's Fix pattern); package-size escalations follow @refactoring `<package_decomposition>`
- Repeat until the agent reports `LINT STATUS: green`

**Phase 4 — REVIEW** (via @pre-commit-review, per completed slice)
- @pre-commit-review orchestrates parallel `rule-hunter` agents + the `overabstraction-skeptic` against the diff; it reports, never edits
- Findings return categorized (Bugs / Design Debt / Readability Debt / Polish), all advisory
- 🔗 CLUSTER entries (≥2 rules converging on one anchor) are fixed design-first: @code-designing (cluster-scoped) produces one mini plan, @refactoring implements it — never member-by-member
- Fix bugs and user-accepted singleton findings via @refactoring, then re-invoke @pre-commit-review in INCREMENTAL mode

**Loop until**:
✅ Tests pass | ✅ `LINT STATUS: green` | ✅ @pre-commit-review INCREMENTAL delta clean (or findings explicitly deferred)

Use this when code is already written but needs to pass quality gates. It goes straight to fixing issues — no design or TDD implementation.
