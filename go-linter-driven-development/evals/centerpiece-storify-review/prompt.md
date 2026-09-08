---
name: centerpiece-storify-review
tags: [cheap, review, logic-hunter, centerpiece]
runs: 2
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Bash, Read, Grep, Glob, Agent, Skill]
---
/go-ldd-review internal/services/device_service.go
