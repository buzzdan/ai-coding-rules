---
name: go-ldd-review
description: Check if code is commit-ready (final verification, no auto-fix)
argument-hint: "[file_pattern | --all]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Agent
  - Skill(go-linter-driven-development:pre-commit-review)
---

Run final verification checks **without** the auto-fix loop.

> **🔍 READ-ONLY COMMAND**
> This command performs verification only and makes NO changes to your code.
> For auto-fix capability, use `/go-ldd-quickfix` instead.

!`git status --porcelain`
!`git diff --stat HEAD`
!`git log --oneline "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo HEAD)"..HEAD`

**Resolve the scope first** — the first rung that applies, and only that rung:

1. **An argument names it.** A file pattern reviews those files. `--all` — or an explicit
   request to audit the whole repository — reviews every `*.go` file. The whole
   repository is never reviewed without being asked for.
2. **The working tree.** Files changed against `HEAD`: staged, unstaged and untracked.
3. **The current PR.** With a clean tree, the files changed on this branch since its base
   (the merge-base with `origin/main`, `main` or `master`, as the preamble above shows).
   This is the ceiling: never wider than the branch.
4. **Nothing.** Say "nothing to review", name the `--all` form for a whole-repository
   audit, and stop. No hunters, no verdict over an empty scope, no silent widening.

Name the rung in the report's scope line.

Execute these steps:

1. **Discover commands** from project docs (README, CLAUDE.md, Makefile, etc.)
2. **Run in read-only mode**:
   - Tests: Bash([PROJECT_TEST_COMMAND])
   - Linter: Bash([PROJECT_LINT_COMMAND] **without `--fix`** — report only, e.g. `golangci-lint run`)
   - Review: invoke `Skill(go-linter-driven-development:pre-commit-review)` in FULL mode over the resolved
     scope, passing it the file list. It orchestrates parallel `rule-hunter` agents + the
     `overabstraction-skeptic` and reports — it never edits, and it never widens the scope.
3. **Generate commit readiness report**:
   - ✅/❌ Tests: [pass/fail] + coverage
   - ✅/❌ Linter: [clean/errors]
   - ✅/⚠️ Review: [clean/findings — Bugs / Design Debt / Readability Debt / Polish]
   - 📝 Files in scope: [rung — list with +/- lines]
   - 💡 Suggested commit message

**Does NOT auto-fix anything** — just reports current state. Every review finding is advisory.

Use when you want to verify code is ready without making changes. This is the Phase 4 review plus a plain tests/lint pass, with no auto-fix loop.
