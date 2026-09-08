---
name: case-a-retention-review
tags: [cheap, review, logic-hunter, case-a]
runs: 2
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Bash, Read, Grep, Glob, Agent, Skill]
---
/go-ldd-review internal/snapshot/policy.go internal/snapshot/config.go
