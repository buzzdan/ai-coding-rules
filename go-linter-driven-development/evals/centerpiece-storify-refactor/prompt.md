---
name: centerpiece-storify-refactor
tags: [medium, refactor, logic-hunter, centerpiece]
runs: 1
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  If a skill asks for user approval of a design plan or an option, treat it as approved: choose the recommended option and continue.
---
Make ProcessHeartbeat in internal/services/device_service.go readable and maintainable without changing the HTTP behavior of POST /heartbeat.
