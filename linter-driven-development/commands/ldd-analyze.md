---
name: ldd-analyze
description: Run quality analysis only - tests + plain lint + hunter/skeptic review, combined report, no auto-fix
argument-hint: "[file_pattern | --all]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Agent
  - Skill(linter-driven-development:pre-commit-review)
---

Run comprehensive quality analysis: tests, a report-only linter pass, and the
hunter/skeptic design review — combined into one report, with NO changes to your code.

> **🔍 READ-ONLY COMMAND**
> This command performs analysis only and makes NO changes to your code.
> For auto-fix capability, use `/ldd-quickfix` instead.

Execute these steps:

## Step 1: Discover Project Commands

Search project documentation to find test and lint commands:

1. **Detect the language** from the marker files at the repository root — `go.mod`,
   `pyproject.toml`/`setup.cfg`/`setup.py`, `package.json`, `Cargo.toml`,
   `pom.xml`/`build.gradle`, a `.csproj` — confirmed against the source files
   actually present. Several markers → one language at a time.

2. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lint:` tasks)
   - `package.json` scripts, `pyproject.toml` tool sections, the CI workflow under
     `.github/workflows/`
   - the linter's own configuration file (`.golangci.yaml`, `ruff.toml` or
     `[tool.ruff]`, `eslint.config.js`, `clippy.toml`)

3. **Extract commands**:
   - **Test command**: the one the repository defines — `make test`, `task test`, an
     `npm test` script, `pytest`, `cargo test` as CI runs it
   - **Lint command (report-only)**: this command must NOT fix. Strip any fix flag
     (`--fix`, `--write`) and run the linter in report mode.

4. **No fallbacks.** A command the repository does not define is not invented. No test
   command → the tests gate reports "no test command found" and the analysis
   continues. No linter → the linter gate reports "no linter configured", the review
   carries it as a 🟠 New Practice finding, and the design review runs on the rules
   alone — never a linter this plugin brought along.

## Step 2: Identify Files to Analyze

!`git status --porcelain`
!`git diff --stat HEAD`
!`git log --oneline "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo HEAD)"..HEAD`

**Resolve the scope** — the first rung that applies, and only that rung:

1. **An argument names it** (`$ARGUMENTS`). A file pattern (`./pkg/parser/*.<ext>`,
   `./pkg/parser/`) analyzes those files — validate they exist with glob/ls. `--all`, or
   an explicit request to audit the whole repository, analyzes every source file of the
   language outside vendored and generated directories. The whole repository is never
   analyzed without being asked.
2. **The working tree.** Files changed against `HEAD`, staged, unstaged and untracked,
   filtered to the language's source files:
   ```bash
   { git diff --name-only --diff-filter=ACMR HEAD; git ls-files --others --exclude-standard; } | grep '\.<ext>$' | sort -u
   ```
3. **The current PR.** With a clean tree, the files changed on this branch since its base
   (the merge-base shown in the preamble). This is the ceiling: never wider than the branch.
   ```bash
   git diff --name-only --diff-filter=ACMR "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)"..HEAD | grep '\.<ext>$'
   ```
4. **Nothing.** Say "nothing to analyze", name the `--all` form, and stop — no gates run
   over an empty scope, and the scope is never widened silently.

Name the rung in the report's scope line.

## Step 3: Run the Three Quality Gates (report-only)

1. **Tests**: `Bash([discovered test command])`
2. **Linter (report-only)**: `Bash([discovered lint command, no --fix])` — surfaces
   what needs refactoring without changing anything. (The `linter-driven-development:lint-fixer` agent, which
   auto-fixes, is intentionally NOT used here — this command never edits.)
3. **Design review**: invoke `Skill(linter-driven-development:pre-commit-review)`
   in FULL mode over the file scope. It grep-prefilters the diff against rules R1–R12,
   spawns one parallel `linter-driven-development:rule-hunter` per rule with hits, runs the
   `linter-driven-development:overabstraction-skeptic` over every type/package-extraction proposal, and returns
   evidence-backed findings. It reports — it never edits.

## Step 4: Display Combined Report

Merge the three gates into one report:

- ✅/❌ **Tests**: pass/fail status with coverage
- ✅/❌ **Linter**: clean / error count (with file:line and the failing linter)
- ✅/⚠️ **Review**: clean / findings, categorized as the pre-commit-review report returns them:
  - 🐛 **Bugs** — fail at runtime regardless of rule (incl. R10 concurrent task leaks and unguarded concurrent writes)
  - 🔴 **Design Debt** — R1, R2, R4, R5, R6, R7, R8, R10's non-crash findings, R11, R12 (advisory)
  - 🟡 **Readability Debt** — R3, R9, unclear naming
  - 🟢 **Polish** — minor idiomatic improvements, the skeptic's cheaper alternatives
- 🎯 **Clustered issues**: where a linter failure and a review finding land at the same
  file:line, note the shared root cause and the single fix that resolves both.

Each finding carries evidence (`file:line` + the falsifying-question answer or command
output) and cites the owning rule's Fix pattern (`rules/R*.md`) for HOW to fix — this
command does not apply the fix.

## Example Usage

```bash
# Analyze the working tree's changes, or the current branch when the tree is clean (default)
/ldd-analyze

# Analyze specific package
/ldd-analyze ./pkg/parser/

# Analyze specific file
/ldd-analyze ./pkg/parser/parser.<ext>

# Audit the whole repository — only ever on request
/ldd-analyze --all
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
| `/ldd-autopilot` | Complete workflow (Phases 1–5) | ✅ Yes | lint-fixer, rule-hunter, overabstraction-skeptic |
| `/ldd-quickfix` | Quality-gates loop until green | ✅ Yes | lint-fixer, rule-hunter, overabstraction-skeptic |
| `/ldd-review` | Commit-readiness check | ❌ No | rule-hunter, overabstraction-skeptic (report-only) |
| `/ldd-analyze` | Tests + lint + review, combined report | ❌ No | rule-hunter, overabstraction-skeptic (report-only) |
| `/ldd-status` | Show workflow status | N/A | none |

## Notes

- Read-only: no auto-fix, just analysis and reporting.
- For auto-fix capability, use `/ldd-quickfix` instead.
- For a leaner commit-readiness pass, use `/ldd-review` instead.
- For the complete workflow with design and implementation, use `/ldd-autopilot`.
