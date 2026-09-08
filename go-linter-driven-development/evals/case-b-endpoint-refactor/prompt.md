---
name: case-b-endpoint-refactor
tags: [medium, refactor, logic-hunter, case-b]
runs: 1
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  If a skill asks for user approval of a design plan or an option, treat it as approved: choose the recommended option and continue.
---
Apply the go-ldd workflow to fix the design problems in internal/transport/client.go: the same host, port and TLS flag are handed around through three functions, the http/https choice is made in two places, and the port range is checked twice.
