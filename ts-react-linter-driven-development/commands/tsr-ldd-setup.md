---
name: tsr-ldd-setup
description: Compare the linter setup with the LDD recommended setup, agree a tighter setup per rule, and edit only after you agree to the plan
argument-hint: "[project dir …]"
allowed-tools:
  # residue-exempt: the check commands of the linters that the plugins ship recommended configs for.
  - Read
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - Bash(bash *ldd-lint.sh *)
  - Bash(git *)
  - Bash(golangci-lint run *)
  - Bash(golangci-lint linters *)
  - Bash(golangci-lint config *)
  - Bash(ruff check *)
  - Bash(npx eslint *)
  - Bash(reviewdog *)
  - Skill(ts-react-linter-driven-development:lint-setup)
---

Load `Skill(ts-react-linter-driven-development:lint-setup)` and follow it.

**The projects** are `$ARGUMENTS` when given: one directory each. With no argument,
the skill picks the projects from context.

The skill shows, per rule, the recommended value, the project's value and the finding
count at each. You decide per rule. The skill changes no file before you agree to its
edit plan.
