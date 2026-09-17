---
name: ldd-quickfix
description: Fix what is in scope — the files you are working on — through the quality gates (tests + lint + review → fix → repeat) until green
argument-hint: "[file_pattern | --all]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Skill(linter-driven-development:linter-driven-development)
---

Run the quality-gates loop over code that already exists and needs to pass: the files
of the PR you are working on, a set of review findings, a package you name. Design
(Phase 1) and TDD implementation (Phase 2) are skipped; Phases 3, 4 and 5 run over the
resolved scope until green.

⏱️ **Estimated Duration**: 2-5 minutes for a PR's worth of files. `--all` on a
repository that has never run ldd is a different job: expect the loop to run
long, and prefer `/ldd-analyze --all` first to see the size of it.

!`git status --porcelain`
!`git diff --stat HEAD`
!`git log --oneline "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo HEAD)"..HEAD`

**Resolve the scope first** — the first rung that applies, and only that rung:

1. **An argument names it** (`$ARGUMENTS`). A file pattern or a directory fixes those
   files — validate they exist. `--all`, or an explicit request to clean up the whole
   repository, fixes every `detected-language source` file. The whole repository is never touched
   without being asked.
2. **The working tree.** Files changed against `HEAD`: staged, unstaged and untracked.
3. **The current PR.** With a clean tree, the files changed on this branch since its
   base (the merge-base with `origin/main`, `main` or `master`, as the preamble above
   shows). This is the ceiling: never wider than the branch.
4. **Nothing.** Say "nothing in scope to fix", name the `--all` form and the
   file-pattern form, and stop. No lint-fixer, no refactoring, no review over an empty
   scope, no silent widening. A clean tree on a branch with no base is this rung, not
   an invitation to lint the repository.

Name the rung and list the files in the report's scope line. The lint scope is the set
of packages (directories) that contain those files; the review scope is the files.

**Use the Skill tool** to invoke `Skill(linter-driven-development:linter-driven-development)` with the
resolved scope, telling it Phases 1–2 are skipped:

**Phase 3 — TESTS + LINT over the scope** (via the `linter-driven-development:lint-fixer` agent, Agent tool,
isolated context, spawned with the package list)
- Discover project test/lint commands (`task test` / `make test` / `the repository's test command`;
  lint from Taskfile/Makefile or `the repository's lint command with its fix flag`)
- Run the discovered test command first; all tests must pass before the lint pass
  proceeds (a test failure is a fix target, not a skip)
- One lint run over the scope's packages; mechanical issues are `FIXED` in place
- Design-level failures come back as `ESCALATED:` lines, one per failure, with
  `file:line` and the owning rule
- Every escalation in scope is fixed by invoking @refactoring with its route (its
  `<routing_table>` maps linter failure → owning rule's Fix pattern; its six-step
  stopping criteria and its commit apply); package-size escalations follow
  @refactoring `<package_decomposition>`. Escalations are never fixed by hand from
  this command.
- Repeat until the agent reports `LINT STATUS: green` for the scope

**Phase 4 — REVIEW over the scope's diff** (via @pre-commit-review)
- @pre-commit-review orchestrates parallel `linter-driven-development:rule-hunter` agents + the
  `linter-driven-development:overabstraction-skeptic` against the diff; it reports, never edits, never widens
- Findings return categorized (Bugs / Design Debt / Readability Debt / Polish), all
  advisory
- 🔗 CLUSTER entries (≥2 rules converging on one anchor) are fixed design-first:
  @code-designing (cluster-scoped) produces one mini plan, @refactoring implements it —
  never member-by-member
- Fix bugs and user-accepted singleton findings via @refactoring, then re-invoke
  @pre-commit-review in INCREMENTAL mode

**Phase 5 — SHIP**: tests and lint green and the tree dirty → commit, then the ship
summary with the hash, the scope line, the lint-fixer's `FIXED:` / `ESCALATED:`
tallies and — when @refactoring ran — its `Stop check` block verbatim, six labelled
lines; without the block the refactoring did not finish and the summary is not final.

**Loop until**:
✅ Tests pass | ✅ `LINT STATUS: green` over the scope | ✅ @pre-commit-review INCREMENTAL delta clean (or findings explicitly deferred)

Use this when code is already written and needs to pass quality gates: your branch
before a PR, a reviewer's findings, one package you name. It goes straight to fixing
what is in scope — no design or TDD implementation, and nothing outside the scope.
