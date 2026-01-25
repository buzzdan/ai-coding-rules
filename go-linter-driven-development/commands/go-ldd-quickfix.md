---
name: go-ldd-quickfix
description: Run quality gates loop until all green (tests+linter+review → fix → repeat)
argument-hint: "[file_pattern]"
allowed-tools:
  - Skill(go-linter-driven-development:linter-driven-development)
  - mcp__ide__getDiagnostics
---

Execute the quality gates loop for already-implemented code that needs cleanup.

⏱️ **Estimated Duration**: 2-5 minutes (depends on number of issues found)

**Use the Skill tool** to invoke `Skill(go-linter-driven-development:linter-driven-development)` and run these phases:

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

**Phase 5**: Orchestrator Review (after linter clean)
- Check types with >15 methods (god object threshold)
- If found: Apply @refactoring for storification first
- Then apply @code-designing for composition (service extraction)
- Re-verify with linter

**Loop until**:
✅ Tests pass | ✅ Linter clean | ✅ Review clean | ✅ No god objects (≤15 methods per type)

Use this when code is already written but needs to pass quality gates.
Skip the implementation phase (Phase 1) and go straight to fixing issues.
