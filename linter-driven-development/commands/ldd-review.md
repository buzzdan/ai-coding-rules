---
name: ldd-review
description: Advisory review of the code in scope before a commit (hunters + skeptic report; no tests, no lint, no auto-fix)
argument-hint: "[file_pattern | --all]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Agent
  - Skill(linter-driven-development:pre-commit-review)
---

Run the advisory design review **without** the auto-fix loop, and without the tests
and the linter.

> **🔍 READ-ONLY COMMAND**
> This command reviews only and makes NO changes to your code.
> For the tests and the linter beside the review, use `/ldd-analyze`; for
> auto-fix capability, use `/ldd-quickfix`.

!`git status --porcelain`
!`git diff --stat HEAD`
!`git log --oneline "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo HEAD)"..HEAD`

**Resolve the scope first** — the first rung that applies, and only that rung:

1. **An argument names it.** A file pattern reviews those files. `--all` — or an explicit
   request to audit the whole repository — reviews every `detected-language source` file. The whole
   repository is never reviewed without being asked for.
2. **The working tree.** Files changed against `HEAD`: staged, unstaged and untracked.
3. **The current PR.** With a clean tree, the files changed on this branch since its base
   (the merge-base with `origin/main`, `main` or `master`, as the preamble above shows).
   This is the ceiling: never wider than the branch.
4. **Nothing.** Say "nothing to review", name the `--all` form for a whole-repository
   audit, and stop. No hunters, no verdict over an empty scope, no silent widening.

Name the rung in the report's scope line.

Execute these steps:

1. **No build, no tests, no linters.** A review-only command runs none of them: the
   review reads code, it does not verify it. Do not discover or run the project's test
   or lint commands; `/ldd-analyze` is the command that runs those gates
   beside the review.
2. **Review**: invoke `Skill(linter-driven-development:pre-commit-review)` in FULL mode over the resolved
   scope, passing it the file list. It orchestrates parallel `linter-driven-development:rule-hunter` agents
   (one per rule family with hits, six at most) + the `linter-driven-development:overabstraction-skeptic`
   and reports — it never edits, and it never widens the scope.
   Its report renders inside this command's final message, whole: never written to a
   file, never summarised with a pointer to one, however long a `--all` report runs.
3. **Generate commit readiness report**:
   - ✅/⚠️ Review: [clean/findings — Bugs / Design Debt / Readability Debt / Polish]
   - 📝 Files in scope: [rung — list with +/- lines]
   - 💡 Suggested commit message

**Does NOT auto-fix anything** — just reports current state. Every review finding is advisory.

Use when you want the design review on the code you are about to commit, without changes and without waiting for the tests and the linter. This is the Phase 4 review on its own; `/ldd-analyze` adds the tests and lint gates, `/ldd-quickfix` the auto-fix loop.
