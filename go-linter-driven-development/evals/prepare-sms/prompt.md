---
name: prepare-sms
tags: [medium, prepare]
runs: 1
max_turns: 100
timeout_seconds: 3000
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  You are running non-interactively: there is no next turn and no user to answer. Never end your turn while a subagent you spawned is still running; when you spawn agents, run them in the foreground (run_in_background: false) and wait for every result before continuing. Do not schedule wakeups or say you will pick something up later; finish the task and print your final report in this turn.
---
/go-ldd-prepare "add an SMS alert channel alongside email, slack and pagerduty"
