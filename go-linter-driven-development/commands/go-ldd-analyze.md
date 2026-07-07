---
name: go-ldd-analyze
description: Run quality analysis only - tests + plain lint + hunter/skeptic review, combined report, no auto-fix
argument-hint: "[file_pattern]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Task
  - Skill(go-linter-driven-development:pre-commit-review)
---

Run comprehensive quality analysis: tests, a report-only linter pass, and the
hunter/skeptic design review — combined into one report, with NO changes to your code.

> **🔍 READ-ONLY COMMAND**
> This command performs analysis only and makes NO changes to your code.
> For auto-fix capability, use `/go-ldd-quickfix` instead.

Execute these steps:

## Step 1: Discover Project Commands

Search project documentation to find test and lint commands:

1. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lint:` tasks)
   - `.golangci.yaml` (linter configuration)

2. **Extract commands**:
   - **Test command**: `go test ./... -cover`, `make test`, `task test`
   - **Lint command (report-only)**: this command must NOT fix. Strip any `--fix`
     flag and run the linter in report mode: `golangci-lint run` (or the project's
     lint command with `--fix` removed).

3. **Fallback to defaults** if not found:
   - Test: `go test ./...`
   - Lint: `golangci-lint run` (no `--fix`)

## Step 2: Identify Files to Analyze

!`git status --porcelain`
!`git diff --name-only --diff-filter=ACMR HEAD`

**If arguments provided** (`$ARGUMENTS`):
- Use as file pattern (e.g., `./pkg/parser/*.go`, `./pkg/parser/`)
- Validate files exist with glob/ls

**Otherwise** (default behavior):
- Use git to find changed files:
  ```bash
  git diff --name-only --diff-filter=ACMR HEAD | grep '\.go$'
  ```
- If no git repository or no changes, analyze all `.go` files in the project (excluding vendor/, testdata/)

## Step 3: Run the Three Quality Gates (report-only)

1. **Tests**: `Bash([discovered test command])`
2. **Linter (report-only)**: `Bash([discovered lint command, no --fix])` — surfaces
   what needs refactoring without changing anything. (The `lint-fixer` agent, which
   auto-fixes, is intentionally NOT used here — this command never edits.)
3. **Design review**: invoke `Skill(go-linter-driven-development:pre-commit-review)`
   in FULL mode over the file scope. It grep-prefilters the diff against rules R1–R10,
   spawns one parallel `rule-hunter` per rule with hits, runs the
   `overabstraction-skeptic` over every type/package-extraction proposal, and returns
   evidence-backed findings. It reports — it never edits.

## Step 4: Display Combined Report

Merge the three gates into one report:

- ✅/❌ **Tests**: pass/fail status with coverage
- ✅/❌ **Linter**: clean / error count (with file:line and the failing linter)
- ✅/⚠️ **Review**: clean / findings, categorized as the pre-commit-review report returns them:
  - 🐛 **Bugs** — fail at runtime regardless of rule (incl. R10 goroutine leaks and unguarded concurrent writes)
  - 🔴 **Design Debt** — R1, R2, R4, R5, R6, R7, R8, R10's non-crash findings (advisory)
  - 🟡 **Readability Debt** — R3, R9, unclear naming
  - 🟢 **Polish** — minor idiomatic improvements, the skeptic's cheaper alternatives
- 🎯 **Clustered issues**: where a linter failure and a review finding land at the same
  file:line, note the shared root cause and the single fix that resolves both.

Each finding carries evidence (`file:line` + the falsifying-question answer or command
output) and cites the owning rule's Fix pattern (`rules/R*.md`) for HOW to fix — this
command does not apply the fix.

## Example Usage

```bash
# Analyze all changed files (default)
/go-ldd-analyze

# Analyze specific package
/go-ldd-analyze ./pkg/parser/

# Analyze specific file
/go-ldd-analyze ./pkg/parser/parser.go
```

## Use Cases

- ✅ Quick quality check before committing
- ✅ Understand what issues exist without making changes
- ✅ Get a combined view of tests + linter + design review
- ✅ See where a linter failure and a design finding share one root cause
- ✅ Identify high-impact fixes (multiple issues at the same location)

## Comparison with Other Commands

| Command | Purpose | Auto-Fix | Spawns agents |
|---------|---------|----------|---------------|
| `/go-ldd-autopilot` | Complete workflow (Phases 1–5) | ✅ Yes | lint-fixer, rule-hunter, overabstraction-skeptic |
| `/go-ldd-quickfix` | Quality-gates loop until green | ✅ Yes | lint-fixer, rule-hunter, overabstraction-skeptic |
| `/go-ldd-review` | Commit-readiness check | ❌ No | rule-hunter, overabstraction-skeptic (report-only) |
| `/go-ldd-analyze` | Tests + lint + review, combined report | ❌ No | rule-hunter, overabstraction-skeptic (report-only) |
| `/go-ldd-status` | Show workflow status | N/A | none |

## Notes

- Read-only: no auto-fix, just analysis and reporting.
- For auto-fix capability, use `/go-ldd-quickfix` instead.
- For a leaner commit-readiness pass, use `/go-ldd-review` instead.
- For the complete workflow with design and implementation, use `/go-ldd-autopilot`.
