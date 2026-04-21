---
name: go-ldd-status
description: Show current workflow status and progress
argument-hint: ""
allowed-tools:
  - Read
  - Bash(git *)
---

!`git status --porcelain`
!`git diff --stat`

Display current implementation status:

📍 Current Context:
  - Active plan: [file path or "conversation"]
  - Current step: [step number]
  - Phase: [design/testing/linting/refactoring/review/docs/commit]

📊 Last Results:
  Tests: [status + coverage]
  Linter: [status + error count]
  Review: [status + finding count]

📝 Files Modified:
  [list with +/- lines]

🎯 Next Action:
  [What happens next in the workflow]

## Suggested Next Steps

Based on current status:
- **Tests failing?** → Fix tests, then run `/go-ldd-analyze`
- **Linter errors?** → Run `/go-ldd-quickfix` for auto-fix loop
- **Code complete?** → Run `/go-ldd-review` for commit readiness check
- **Starting new work?** → Run `/go-ldd-autopilot` for full workflow

Perfect for: "where are we?", "what's the status?", "what's next?"
