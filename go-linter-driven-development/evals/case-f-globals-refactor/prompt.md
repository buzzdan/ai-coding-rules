---
name: case-f-globals-refactor
tags: [medium, refactor, logic-hunter, case-f]
runs: 1
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  If a skill asks for user approval of a design plan or an option, treat it as approved: choose the recommended option and continue.
---
Remove the nolint on env.Config and make the linter pass without suppressions, keeping every step deployable: commit each working step separately.
