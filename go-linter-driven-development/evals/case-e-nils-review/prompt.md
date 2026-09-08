---
name: case-e-nils-review
tags: [cheap, review, logic-hunter, case-e]
runs: 2
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Bash, Read, Grep, Glob, Agent, Skill]
---
/go-ldd-review internal/report/reporter.go internal/report/catalog.go internal/report/wire.go
