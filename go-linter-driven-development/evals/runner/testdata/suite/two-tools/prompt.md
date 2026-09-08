---
name: two-tools
tags: [cheap, review]
runs: 1
max_turns: 5
timeout_seconds: 60
allowed_tools: [Bash, Read, Write, Skill]
append_system_prompt: |
  Be brief.
---
/go-ldd-review
