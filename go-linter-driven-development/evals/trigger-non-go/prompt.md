---
name: trigger-non-go
tags: [cheap, trigger]
runs: 3
max_turns: 4
timeout_seconds: 600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  This is a workflow dry run. Do not write any code in this session: state in
  two sentences how you would approach the task, then print DONE on its own line.
---
implement a request-id middleware
