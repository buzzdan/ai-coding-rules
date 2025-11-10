---
name: go-ldd-quickfix
description: Run quality gates loop until all green (tests+linter+review → fix → repeat)
---

Execute the quality gates loop for already-implemented code that needs cleanup.

Run these phases from @linter-driven-development skill:

**Phase 2**: Parallel Analysis
- Discover project test/lint commands
- Launch 3 tools simultaneously: tests, linter, go-code-reviewer agent
- Wait for all results

**Phase 3**: Intelligent Combined Report
- Merge findings from linter + review
- Identify overlapping issues at same file:line
- Analyze root causes
- Generate unified fix strategies
- Prioritize: Impact × Effort × Risk

**Phase 4**: Iterative Fix Loop
- Apply fixes using @refactoring skill (auto, no confirmation)
- Re-verify with parallel analysis (incremental review mode)
- Repeat until all green

**Loop until**:
✅ Tests pass | ✅ Linter clean | ✅ Review clean

Use this when code is already written but needs to pass quality gates.
Skip the implementation phase (Phase 1) and go straight to fixing issues.
