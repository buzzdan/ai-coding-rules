---
name: case-c-picker-refactor
tags: [medium, refactor, logic-hunter, case-c]
runs: 1
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  If a skill asks for user approval of a design plan or an option, treat it as approved: choose the recommended option and continue.
---
Apply the go-ldd workflow to fix the design problems in internal/placement/picker.go: the replica picker walks the node list with two boolean flags and three levels of nesting, decides inline which nodes are even usable, and is hard to follow.
