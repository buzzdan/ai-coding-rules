---
name: case-e-nils-refactor
tags: [medium, refactor, logic-hunter, case-e]
runs: 1
max_turns: 150
timeout_seconds: 3600
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  If a skill asks for user approval of a design plan or an option, treat it as approved: choose the recommended option and continue.
  You are running non-interactively: there is no next turn and no user to answer. Never end your turn while a subagent you spawned is still running; when you spawn agents, run them in the foreground (run_in_background: false) and wait for every result before continuing. Do not schedule wakeups or say you will pick something up later; finish the task and print your final report in this turn.
---
Apply the go-ldd workflow to fix the design problems in internal/report/reporter.go, internal/report/catalog.go and internal/report/wire.go: nil is doing three different jobs here — the reporter's sink and clock may be nil and every method has to check, Find hands back nil for "not found", and callers pass nil to NewReporter to mean "use the defaults".
