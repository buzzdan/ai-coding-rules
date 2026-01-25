---
name: go-ldd-autopilot
description: Start complete linter-driven autopilot workflow (Phase 1-5)
argument-hint: ""
allowed-tools:
  - Skill(go-linter-driven-development:linter-driven-development)
  - mcp__ide__getDiagnostics
---

**Use the Skill tool** to invoke `Skill(go-linter-driven-development:linter-driven-development)` to run the complete autopilot workflow from design through commit-ready.

⏱️ **Estimated Duration**: 5-15 minutes (depends on feature complexity and issues found)

The skill will automatically:
1. Run Pre-Flight Check (detect intent, find commands, verify Go project)
2. Execute all 5 phases with 2 quality gates
3. Use parallel analysis (tests + linter + go-code-reviewer agent)
4. Generate intelligent combined reports
5. Auto-fix all issues iteratively
6. Prepare commit-ready summary

This is the full workflow - use for implementing features or fixes from start to finish.
