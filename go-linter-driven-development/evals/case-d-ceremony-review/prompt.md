---
name: case-d-ceremony-review
tags: [cheap, review, logic-hunter, case-d, precision]
runs: 2
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Bash, Read, Grep, Glob, Agent, Skill]
---
/go-ldd-review internal/models/grants.go internal/handlers/trace.go
