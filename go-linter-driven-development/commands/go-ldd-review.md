---
name: go-ldd-review
description: Check if code is commit-ready (final verification, no auto-fix)
argument-hint: "[file_pattern]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Task
  - Skill(go-linter-driven-development:pre-commit-review)
---

Run final verification checks **without** the auto-fix loop.

> **🔍 READ-ONLY COMMAND**
> This command performs verification only and makes NO changes to your code.
> For auto-fix capability, use `/go-ldd-quickfix` instead.

!`git status --porcelain`
!`git diff --stat`

Execute these steps:

1. **Discover commands** from project docs (README, CLAUDE.md, Makefile, etc.)
2. **Run in read-only mode**:
   - Tests: Bash([PROJECT_TEST_COMMAND])
   - Linter: Bash([PROJECT_LINT_COMMAND] **without `--fix`** — report only, e.g. `golangci-lint run`)
   - Review: invoke `Skill(go-linter-driven-development:pre-commit-review)` in FULL mode. It orchestrates parallel `rule-hunter` agents + the `overabstraction-skeptic` and reports — it never edits.
3. **Generate commit readiness report**:
   - ✅/❌ Tests: [pass/fail] + coverage
   - ✅/❌ Linter: [clean/errors]
   - ✅/⚠️ Review: [clean/findings — Bugs / Design Debt / Readability Debt / Polish]
   - 📝 Files in scope: [list with +/- lines]
   - 💡 Suggested commit message

**Does NOT auto-fix anything** — just reports current state. Every review finding is advisory.

Use when you want to verify code is ready without making changes. This is the Phase 4 review plus a plain tests/lint pass, with no auto-fix loop.
