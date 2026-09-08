---
name: case-a-retention-refactor
tags: [medium, refactor, logic-hunter, case-a]
runs: 1
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  If a skill asks for user approval of a design plan or an option, treat it as approved: choose the recommended option and continue.
  You are running non-interactively: there is no next turn and no user to answer. Never end your turn while a subagent you spawned is still running; when you spawn agents, run them in the foreground (run_in_background: false) and wait for every result before continuing. Do not schedule wakeups or say you will pick something up later; finish the task and print your final report in this turn.
---
Apply the go-ldd workflow to fix the design problems in internal/snapshot/policy.go and internal/snapshot/config.go: the retention setting is parsed and range-checked in two different places, checked again inside the pruning loop, and one of the two helpers hands back 0 to mean "not set".
