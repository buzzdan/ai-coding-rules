---
name: pre-commit-review
description: |
  ADVISORY validation of code against design principles that linters cannot enforce.
  Loaded by go-code-reviewer agent for design analysis guidance. Also invoked by @refactoring (after pattern application).
  Can be manually invoked for standalone code review.
  Categorizes findings as Design Debt, Readability Debt, or Polish Opportunities. Does NOT block commits.
---

<objective>
Expert design analysis that detects issues linters can't catch.
Returns detailed report to caller with categorized findings and fix recommendations.

**Pure Analysis & Reporting** - Generates report, doesn't fix anything or invoke skills.

**Reference**: See `reference.md` for complete detection checklist with examples.
**Examples**: See `examples.md` for real-world review scenarios.
</objective>

<quick_start>
1. **Read files** under review (all staged or specific files)
2. **Apply design principles** checklist from reference.md (LLM reasoning)
3. **Search usage patterns** with Grep tool
4. **Categorize findings**: Bugs, Design Debt, Readability Debt, Polish
5. **Generate structured report** with file:line locations and fix recommendations
6. **Return report** to caller (no fixes, no skill invocations)
</quick_start>

<input_output>
<input>
- Files to review (specific files or all staged changes)
- Review mode: `full` (first run) or `incremental` (subsequent runs)
- Previous findings (optional, for incremental mode)
- Context (invoked by refactoring, orchestrator, subagent, or user)
</input>

<output>
- Structured report with categorized findings
- Each finding: `file:line`, issue, why it matters, fix strategy, effort estimate
- Prioritized by impact and effort
- Format: Parseable for combined analysis (when invoked by orchestrator)
</output>
</input_output>

<invocation_modes>
<direct_skill_invocation context="User or Orchestrator">
- Full control, can invoke other skills
- Can make changes based on findings
- Interactive mode with user feedback
</direct_skill_invocation>

<subagent_mode context="Task tool with go-code-reviewer">
- Read-only analysis, returns report only
- Cannot invoke other skills
- Used for parallel execution by orchestrator
- Designed for speed and focused analysis
</subagent_mode>
</invocation_modes>

<who_invokes>
1. **go-code-reviewer agent** - Loads this skill for design analysis guidance during parallel quality analysis
2. **@refactoring skill** - After applying patterns, validates design quality remains high
3. **User** - Manual code review before commit
</who_invokes>

<detection_capabilities>
**What Reviewer Detects (That Linters Can't):**
- Primitive obsession (with juiciness scoring)
- Unstorified functions (mixed abstraction levels)
- Missing domain concepts (implicit types that should be explicit)
- Non-self-validating types (defensive code in methods)
- Poor comment quality (explaining what instead of why)
- File structure issues (too long, too many types)
- Generic package extraction opportunities
- Design bugs (nil deref, ignored errors, resource leaks)
- Test quality (weak assertions, missing use cases, mock overuse, conditionals in tests)

**Division of Labor:**
- **Linter handles**: Complexity metrics, line counts, formatting, syntax
- **Reviewer handles**: Design patterns, domain modeling, conceptual issues

See [reference.md](./reference.md) for complete detection checklist with examples.
</detection_capabilities>

<workflow>

<full_review_mode context="First Run">
1. Read all files under review (using Read tool)
2. Apply design principles checklist from reference.md (LLM reasoning)
3. Search for usage patterns across codebase (using Grep tool)
4. Categorize findings:
   - Bugs (nil deref, ignored errors, resource leaks)
   - Design Debt (types, architecture, validation)
   - Readability Debt (abstraction, flow, clarity)
   - Polish (naming, docs, minor improvements)
5. Generate structured report with recommendations
6. Return report to caller (doesn't invoke other skills or make fixes)
</full_review_mode>

<incremental_review_mode context="Subsequent Runs">
Used after fixes have been applied to verify resolution and detect new issues.

1. Read ONLY changed files since last review (using git diff)
2. Compare against previous findings:
   - Mark resolved issues as Fixed
   - Identify issues that still exist
3. Analyze changed code for NEW issues introduced by fixes
4. Generate delta report:
   - Fixed: Issues from previous run that are now resolved
   - Remaining: Issues that still need attention
   - New: Issues introduced by recent changes
5. Return concise delta report (not full analysis)

**When to Use Incremental Mode:**
- After @refactoring skill applies fixes
- During iterative fix loop in Phase 4 of autopilot workflow
- User requests re-review after making changes

**Benefits:**
- Faster execution (only analyzes changed files)
- Clear feedback on what was fixed vs what remains
- Detects regressions introduced by fixes
</incremental_review_mode>

</workflow>

<detection_approach>
**LLM-Powered Analysis** (not AST parsing or metrics calculation):

The reviewer reads code like a senior developer and applies design principles:
- Reads files with Read tool
- Searches patterns with Grep tool (find usages, duplications)
- Applies checklist from reference.md using LLM reasoning
- Pattern matches against anti-patterns
- Counts occurrences and calculates juiciness scores
- Generates findings with specific locations and fix guidance
</detection_approach>

<report_format>

<full_report context="First Run">
```
📊 CODE REVIEW REPORT
Scope: [files reviewed]
Mode: FULL

SUMMARY

Total findings: 18
🐛 Bugs: 2 (fix immediately)
🔴 Design Debt: 5 (fix before commit)
🟡 Readability Debt: 8 (improves maintainability)
🟢 Polish: 3 (nice to have)

Estimated fix effort: 3.5 hours

[Detailed findings by category]
[Recommendations by priority]
[Skills to use for fixes]
```
</full_report>

<incremental_report context="Subsequent Runs">
```
📊 CODE REVIEW DELTA REPORT
Scope: [changed files only]
Mode: INCREMENTAL

SUMMARY

✅ Fixed: 4 (resolved from previous run)
⚠️ Remaining: 2 (still need attention)
🆕 New: 1 (introduced by recent changes)

[Detailed delta findings]
```
</incremental_report>

<structured_output context="For Orchestrator Parsing">
When invoked as subagent for combined analysis, output follows strict format:

```
🐛 BUGS
────────────────────────────────────────────────
file:line | Issue description | Why it matters | Fix strategy | Effort: [Trivial/Moderate/Significant]

🔴 DESIGN DEBT
────────────────────────────────────────────────
file:line | Issue description | Why it matters | Fix strategy | Effort: [Trivial/Moderate/Significant]

🟡 READABILITY DEBT
────────────────────────────────────────────────
file:line | Issue description | Why it matters | Fix strategy | Effort: [Trivial/Moderate/Significant]

🟢 POLISH
────────────────────────────────────────────────
file:line | Issue description | Why it matters | Fix strategy | Effort: [Trivial/Moderate/Significant]
```

**Effort Estimates:**
- **Trivial**: <5 minutes (extract constant, rename variable)
- **Moderate**: 5-20 minutes (extract function, storifying, create simple type)
- **Significant**: >20 minutes (architectural refactoring, complex type extraction)

**file:line Format:** Must be exact for orchestrator to correlate with linter errors
- Example: `pkg/parser.go:45`
- NOT: `parser.go line 45` or `pkg/parser.go (line 45)`
</structured_output>

</report_format>

<constraints>
This skill MUST NOT:
- Invoke other skills (@refactoring, @code-designing, @testing)
- Fix anything or make code changes
- Make decisions on behalf of user
- Parse AST or calculate complexity metrics (linter does this)
- Run linter (caller does this)
- Iterate or loop (caller decides whether to re-invoke)
- Block commits (findings are advisory)
</constraints>

<integration>

<invoked_by_refactoring>
Refactoring completes → invoke reviewer → analyze report:
- Bugs found? → Fix immediately, re-run linter
- Design debt found? → Apply another refactoring pattern
- All clean? → Return success to orchestrator
</invoked_by_refactoring>

<invoked_by_go_code_reviewer>
During Phase 2 (Parallel Quality Analysis):
1. go-code-reviewer agent automatically loads this skill for guidance
2. Agent applies detection checklist from this skill
3. Agent returns structured report to quality-analyzer
4. quality-analyzer combines with linter/test results
5. Orchestrator routes based on combined findings
</invoked_by_go_code_reviewer>

<invoked_by_user>
Manual review request:
1. User invokes: @pre-commit-review on path/to/file.go
2. Receive detailed report
3. User decides how to proceed
4. User may invoke @refactoring or @code-designing for fixes
</invoked_by_user>

</integration>

<review_scope>
**Primary Scope**: Changed code in commit
- All modified lines
- All new files
- Specific focus on design principle adherence

**Secondary Scope**: Context around changes
- Entire files containing modifications
- Flag patterns/issues outside commit scope (in BROADER CONTEXT section)
- Suggest broader refactoring opportunities if valuable
</review_scope>

<advisory_nature>
**This review does NOT block commits.**

Purpose:
- Provide visibility into design quality
- Offer concrete improvement suggestions with examples
- Help maintain coding principles
- Guide refactoring decisions

Caller (or user) decides:
- Commit as-is (accept debt knowingly)
- Fix critical debt before commit (bugs, major design issues)
- Fix all debt before commit (comprehensive cleanup)
- Expand scope to broader refactor (when broader context issues found)
</advisory_nature>

<finding_categories>

<bugs severity="critical">
**Will cause runtime failures or correctness issues**
- Nil dereferences, ignored errors, resource leaks
- Invalid nil returns, race conditions
- Fix immediately before any other work
</bugs>

<design_debt severity="high">
**Will cause pain when extending/modifying code**
- Primitive obsession, missing domain types
- Non-self-validating types
- Wrong architecture (horizontal vs vertical)
- Fix before commit recommended
</design_debt>

<readability_debt severity="medium">
**Makes code harder to understand and work with**
- Mixed abstraction levels, not storified
- Functions too long or complex
- Poor naming, unclear intent
- Fix improves team productivity
</readability_debt>

<polish severity="low">
**Minor improvements for consistency and quality**
- Non-idiomatic naming, missing examples
- Comment improvements, minor refactoring
- Low priority, nice to have
</polish>

See [reference.md](./reference.md) for detailed principles and examples for each category.
</finding_categories>

<success_criteria>
**Code Quality Analysis Performed:**
- [ ] Read every function - does it read like a story? (single abstraction level)
- [ ] Checked all functions for mixed abstraction levels (storifying needed?)
- [ ] Evaluated primitives for primitive obsession (juiciness test applied)
- [ ] Assessed types for self-validation (defensive code in methods?)
- [ ] Reviewed comment quality (explaining WHY not WHAT?)
- [ ] Checked file structure (too long? too many types?)
- [ ] Searched for missing domain concepts (implicit types that should be explicit)
- [ ] Validated test quality (weak assertions? conditionals in tests? mock overuse?)
- [ ] Scanned for design bugs (nil deref, ignored errors, resource leaks)

**Report Quality:**
- [ ] All findings categorized by severity (Bugs, Design Debt, Readability Debt, Polish)
- [ ] Each finding includes: file:line, issue, why it matters, fix strategy, effort estimate
- [ ] Structured format parseable by orchestrator
- [ ] Clear distinction between bugs (fix immediately) and advisory findings
- [ ] Incremental mode accurately tracks fixed, remaining, and new issues
</success_criteria>
