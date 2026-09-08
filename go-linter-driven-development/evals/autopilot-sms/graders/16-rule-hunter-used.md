---
type: tool_used
tool: Agent
input_match: '"subagent_type":"[^"]*rule-hunter"'
min: 1
---
@pre-commit-review must actually spawn rule hunters (its step 2), not review
in-context. Anchored on `subagent_type` for the same reason as grader 14.
