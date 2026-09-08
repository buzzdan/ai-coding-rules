---
name: trigger-go
tags: [cheap, trigger]
runs: 3
max_turns: 6
timeout_seconds: 600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  This is a workflow dry run. Do not write any code in this session: stop as soon
  as you have announced the workflow you are using and listed the pre-flight
  commands you discovered (test and lint), then print DONE on its own line.
  You are running non-interactively: there is no next turn and no user to answer. Never end your turn while a subagent you spawned is still running; when you spawn agents, run them in the foreground (run_in_background: false) and wait for every result before continuing. Do not schedule wakeups or say you will pick something up later; finish the task and print your final report in this turn.
---
implement a request-id middleware for the HTTP server
