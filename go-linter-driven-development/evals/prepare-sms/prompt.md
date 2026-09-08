---
name: prepare-sms
tags: [medium, prepare]
runs: 1
max_turns: 100
timeout_seconds: 3000
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
---
/go-ldd-prepare "add an SMS alert channel alongside email, slack and pagerduty"
