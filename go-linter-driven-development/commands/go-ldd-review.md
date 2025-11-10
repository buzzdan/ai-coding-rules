---
name: go-ldd-review
description: Check if code is commit-ready (final verification, no auto-fix)
---

Run final verification checks **without** the auto-fix loop.

Execute these steps:

1. **Discover commands** from project docs (README, CLAUDE.md, Makefile, etc.)
2. **Run in parallel**:
   - Tests: Bash([PROJECT_TEST_COMMAND])
   - Linter: Bash([PROJECT_LINT_COMMAND])
   - Review: Task(subagent_type: "go-code-reviewer") with mode: full
3. **Generate commit readiness report**:
   - ✅/❌ Tests: [pass/fail] + coverage
   - ✅/❌ Linter: [clean/errors]
   - ✅/❌ Review: [clean/findings]
   - 📝 Files in scope: [list with +/- lines]
   - 💡 Suggested commit message

**Does NOT auto-fix anything** - just reports current state.

Use when you want to verify code is ready without making changes.
Equivalent to Phase 2 (Parallel Analysis) + Gate 2 (Final Verification) only.
