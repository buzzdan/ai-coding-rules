---
name: py-ldd-setup
description: Compare the linter setup with the LDD recommended setup, agree a tighter setup per rule, and edit only after you agree to the plan
argument-hint: "[project dir …]"
allowed-tools:
  - Read
  - Grep
  - Bash
  - Skill(python-linter-driven-development:lint-setup)
---

Load `Skill(python-linter-driven-development:lint-setup)` and follow it.

**The projects** are `$ARGUMENTS` when given: one directory each. With no argument,
the skill picks the projects from context.

The skill shows, per rule, the recommended value, the project's value and the finding
count at each. You decide per rule. The skill changes no file before you agree to its
edit plan.
