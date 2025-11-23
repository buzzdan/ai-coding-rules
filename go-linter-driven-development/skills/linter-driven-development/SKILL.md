---
name: linter-driven-development
description: |
  WHEN: User requests Go code work (implement, fix, add, refactor) or mentions @ldd in a Go project.
  Orchestrates complete workflow (Phases 1-5): design → test → implement → lint → fix → documentation.
  Auto-triggers parallel quality analysis and iterative fix loop until code is commit-ready.
---

<objective>
Meta orchestrator for Go implementation workflow: design → test → lint → refactor → review → commit.
Use for any commit: features, bug fixes, refactors.

**Reference**: See `reference.md` for agent prompt templates, example reports, and output formats.
</objective>

<essential_principles>
**Auto-Pilot Behavior**: This skill triggers automatically when Go code work is detected. After permission is granted, announce: **"Using go-ldd workflow for this Go code work"** and proceed to pre-flight check.

**Trigger Conditions**:
- User requests Go code work (implement, fix, add, refactor, update, change, modify, etc.)
- User mentions "ldd" or "@ldd" (shorthand for linter-driven-development)
- Working directory contains Go project (go.mod or .go files)
</essential_principles>

<quick_start>
**Immediate Action**: Run Pre-Flight Check, then execute phases sequentially until commit-ready.

1. **Pre-Flight**: Verify Go project, find test/lint commands, identify plan context
2. **Phase 1**: Design types (if needed) → Write tests → Implement code
3. **Phase 2**: Run quality-analyzer agent → Route based on status
4. **Phase 3**: Fix loop until CLEAN_STATE
5. **Phase 4**: Documentation
6. **Phase 5**: Present commit summary with options
</quick_start>

<workflow>

<pre_flight_check>
**ALWAYS RUN FIRST**

<step name="confirm_intent">
Look for keywords: "implement", "ready", "execute", "do", "start", "continue", "next", "build", "create", "step 1", "task 2", or explicit "@linter-driven-development", "@ldd", "ldd"
</step>

<step name="verify_go_project">
Check that `go.mod` exists in the project root or parent directories.
</step>

<step name="find_commands">
**Search locations** (in order):
1. Project docs: `README.md`, `CLAUDE.md`, `agents.md`
2. Build configs: `Makefile`, `Taskfile.yaml`, `.golangci.yaml`
3. Git repository root for workspace-level commands

**Extract commands**:
- **Test command**: `go test`, `make test`, `task test`
- **Lint command**: `golangci-lint run --fix`, `make lint`, `task lintwithfix`
- **Fallbacks**: `go test ./...` and `golangci-lint run --fix`
</step>

<step name="identify_plan">
Scan conversation history (last 50 messages) for step-by-step plan and which step to implement.
</step>

<decision_tree>
<decision condition="All conditions met" action="Announce 'Engaging autopilot mode for [description]' → Phase 1" />
<decision condition="Unclear intent" action="Ask for confirmation" />
<decision condition="No plan found" action="Suggest creating plan first (offer @code-designing)" />
<decision condition="Not Go project" action="Explain limitation" />
</decision_tree>
</pre_flight_check>

<phase name="1" title="Implementation Foundation">
**Design Architecture** (if new types/functions needed):
- Invoke @code-designing skill
- Output: Type design plan with self-validating domain types

**Write Tests First**:
- Invoke @testing skill for guidance
- Write table-driven tests or testify suites
- Target: 100% coverage on new leaf types

**Implement Code**:
- Follow coding principles from coding_rules.md
- Keep functions <50 LOC, max 2 nesting levels
- Use self-validating types, prevent primitive obsession
</phase>

<phase name="2" title="Quality Analysis">
**Invoke quality-analyzer agent** for parallel quality analysis.
See `reference.md` → "Agent Prompt Templates" for full prompt.

The agent automatically:
- Executes tests, linter, and code review in parallel (40-50% faster)
- Identifies overlapping issues with root cause analysis
- Returns structured report with prioritized fixes

<routing>
<route status="TEST_FAILURE" action="Enter Test Focus Mode (fix tests, retry)" />
<route status="CLEAN_STATE" action="Skip to Phase 4 (Documentation)" />
<route status="ISSUES_FOUND" action="Continue to Phase 3 (Fix Loop)" />
<route status="TOOLS_UNAVAILABLE" action="Report error, ask user to install tools" />
</routing>

<test_focus_mode>
Loop until tests pass:
1. Analyze failure root cause
2. Apply fix to implementation or tests
3. Re-run quality-analyzer (mode: "full")
4. Check status → continue or exit loop

Max 10 iterations. If stuck, ask user for guidance.
</test_focus_mode>
</phase>

<phase name="3" title="Iterative Fix Loop">
**For each prioritized fix** (from agent's report):

1. **Apply Fix**:
   - Invoke @refactoring skill with file, function, issues, and root cause
   - @refactoring applies patterns: early returns, extract function, storifying, extract type, switch extraction, extract constant

2. **Verify Fix** (Incremental Mode):
   - Re-run quality-analyzer with `mode: incremental`
   - See `reference.md` → "Agent Prompt Templates" for prompt
   - Agent returns delta report: fixed, remaining, new issues

3. **Route Based on Status**:
   - `TEST_FAILURE` → Enter Test Focus Mode
   - `CLEAN_STATE` → Break loop, go to Phase 4
   - `ISSUES_FOUND` → Continue to next fix (or retry if no progress)

4. **Safety Limits**:
   - Max 10 iterations per fix loop
   - If stuck after 3 attempts → show status, ask user

**Loop until agent returns CLEAN_STATE**.
</phase>

<phase name="4" title="Documentation">
Invoke @documentation skill:
1. Add/update package-level godoc
2. Add/update type and function documentation (WHY not WHAT)
3. Add godoc testable examples (Example_* functions)
4. If last plan step → add feature documentation to docs/

**Verify**: Run `go doc -all ./...` and ensure examples compile.
</phase>

<phase name="5" title="Commit Ready">
Generate comprehensive summary. See `reference.md` → "Commit Readiness Output Format" for template.

Present user with options:
1. Commit as-is
2. Fix design debt only, then commit
3. Fix design + readability debt, then commit
4. Fix all findings, then commit
5. Refactor entire file, then commit
</phase>

</workflow>

<workflow_control>
<control aspect="Phases" behavior="Sequential: 1 → 2 → 3 → 4 → 5" />
<control aspect="Routing" behavior="Agent status determines path" />
<control aspect="Parallelism" behavior="Phase 2 runs 3 tools simultaneously" />
<control aspect="Incremental" behavior="After first run, agent analyzes only changed files" />
</workflow_control>

<integration>
**Skills invoked**:
- @code-designing (Phase 1, if needed)
- @testing (Phase 1)
- @refactoring (Phase 3)
- @documentation (Phase 4)

**Agents invoked**:
- `go-linter-driven-development:quality-analyzer` (Phase 2 and Phase 3 verification)
  - Internally delegates to `go-linter-driven-development:go-code-reviewer` for design analysis

**After committing**:
- Feature complete → Already documented in Phase 4
- More work needed → Run this workflow again for next commit
</integration>

<success_criteria>
Workflow is complete when ALL of the following are true:

- [ ] Pre-flight check passed (Go project verified, commands discovered)
- [ ] Phase 1 complete (tests written, code implemented)
- [ ] Quality-analyzer returns `CLEAN_STATE`:
  - [ ] Tests pass
  - [ ] Linter passes (0 errors)
  - [ ] Code review clean (0 findings)
- [ ] Phase 4 complete (documentation added/updated)
- [ ] Commit summary presented to user with options
- [ ] User has chosen commit action (or deferred)
</success_criteria>
