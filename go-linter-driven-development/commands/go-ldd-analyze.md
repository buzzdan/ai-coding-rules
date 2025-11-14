---
name: go-ldd-analyze
description: Run quality analysis only - invoke quality-analyzer agent and display combined report without auto-fixing
---

Run comprehensive quality analysis with intelligent combining of test results, linter findings, and code review feedback.

**This command does NOT auto-fix anything** - it provides read-only analysis with overlapping issue detection and root cause analysis.

Execute these steps:

## Step 1: Discover Project Commands

Search project documentation to find test and lint commands:

1. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lintwithfix:` tasks)
   - `.golangci.yaml` (linter configuration)

2. **Extract commands**:
   - **Test command**: Look for patterns like:
     - `go test ./... -v -cover`
     - `make test`
     - `task test`
   - **Lint command**: Look for patterns like:
     - `golangci-lint run --fix`
     - `golangci-lint run --config .golangci.yaml --new-from-rev=origin/dev --fix ./...`
     - `make lint`
     - `task lintwithfix`

3. **Fallback to defaults** if not found:
   - Test: `go test ./...`
   - Lint: `golangci-lint run --fix`

## Step 2: Identify Changed Files

Use git to find files that have changed:

```bash
git diff --name-only --diff-filter=ACMR HEAD | grep '\.go$'
```

If no git repository or no changes, analyze all `.go` files in the project (excluding vendor/, testdata/).

## Step 3: Invoke Quality Analyzer Agent

Call the quality-analyzer agent with discovered commands and files:

```
Task(subagent_type: "quality-analyzer")

Prompt:
"Analyze code quality for this Go project.

Mode: full

Project commands:
- Test: [discovered test command]
- Lint: [discovered lint command]

Files to analyze:
[list of changed .go files, one per line]

Run all quality gates in parallel and return combined analysis."
```

## Step 4: Display Report

The agent will return a structured report with one of four statuses:

**TOOLS_UNAVAILABLE**: Display the report and suggest installing missing tools
**TEST_FAILURE**: Display test failures and suggest fixing them before quality analysis
**ISSUES_FOUND**: Display combined report with overlapping issues analysis and prioritized fix order
**CLEAN_STATE**: Display success message - all quality gates passed

## Report Format

The agent returns:
- ✅/❌ **Tests**: Pass/fail status with coverage
- ✅/❌ **Linter**: Clean/errors count
- ✅/⚠️ **Review**: Clean/findings (bugs, design debt, readability debt, polish)
- 🎯 **Overlapping Issues**: Multiple issues at same file:line with root cause analysis
- 📋 **Isolated Issues**: Single issues that don't overlap
- 🔢 **Prioritized Fix Order**: Which issues to tackle first based on impact

## Example Usage

```bash
/go-ldd-analyze
```

This will:
1. Discover test and lint commands from your project docs
2. Find changed Go files from git
3. Run tests, linter, and code review in parallel
4. Display intelligent combined analysis with overlapping issue detection

## Use Cases

- ✅ Quick quality check before committing
- ✅ Understand what issues exist without making changes
- ✅ Get intelligent combined view of tests + linter + review findings
- ✅ See overlapping issues with root cause analysis
- ✅ Identify high-impact fixes (multiple issues at same location)

## Comparison with Other Commands

| Command | Purpose | Auto-Fix | Agent |
|---------|---------|----------|-------|
| `/go-ldd-autopilot` | Complete workflow (Phase 1-6) | ✅ Yes | No |
| `/go-ldd-quickfix` | Quality gates loop with auto-fix | ✅ Yes | No |
| `/go-ldd-review` | Final verification, no auto-fix | ❌ No | No |
| `/go-ldd-analyze` | Quality analysis with intelligent combining | ❌ No | ✅ Yes |
| `/go-ldd-status` | Show workflow status | N/A | No |

## Key Benefits

1. **Parallel Execution**: Runs tests, linter, and code review simultaneously
2. **Intelligent Combining**: Identifies overlapping issues at same file:line
3. **Root Cause Analysis**: Explains why multiple issues occur at same location
4. **Prioritized Fixes**: Suggests fix order based on impact (issues resolved)
5. **Read-Only**: No auto-fix, just analysis and reporting
6. **Autonomous**: Discovers commands automatically from project docs

## Notes

- This command is equivalent to running the quality-analyzer agent standalone
- For auto-fix capability, use `/go-ldd-quickfix` instead
- For final commit-ready verification, use `/go-ldd-review` instead
- For complete workflow with implementation, use `/go-ldd-autopilot` instead
