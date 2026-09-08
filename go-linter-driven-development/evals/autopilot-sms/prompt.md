---
name: autopilot-sms
tags: [expensive, autopilot, workflow]
runs: 1
max_turns: 300
timeout_seconds: 7200
allowed_tools: [Bash, Read, Edit, Write, Grep, Glob, Agent, Skill]
append_system_prompt: |
  You are working unattended. The user who asked for this change is unavailable
  for the whole session and has given these standing answers in advance:

  - Any DESIGN PLAN you present is approved exactly as presented. Do not wait
    for confirmation; continue with the next phase immediately.
  - Any question that offers options (Option A / Option B, or a longer list) is
    answered with the recommended option. If no option is marked recommended,
    take Option A.
  - Advisory review findings: fix the bugs and the design-debt findings that lie
    inside your own diff; defer the rest and list them in the ship summary.
  - Commits are approved. Land preparatory refactoring in its own commit(s)
    before the first feature test, and commit the finished feature at the ship
    step, each with a descriptive message. Leave no work uncommitted.

  Never stop to ask a question; if the spec is silent on a detail, make the
  smallest reasonable choice and record it in the ship summary.

  Hard constraint: do not add dependencies. go.mod must remain unchanged; use
  only the standard library, including for tests.

  Your final message must be the ship summary.
---
Implement SPEC.md
