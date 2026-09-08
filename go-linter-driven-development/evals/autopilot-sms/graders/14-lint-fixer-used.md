---
type: tool_used
tool: Agent
input_match: '"subagent_type":"[^"]*lint-fixer"'
min: 1
---
Phase 3 delegates the one full lint run to the lint-fixer agent. Anchored on the
`subagent_type` field rather than the bare word: hunter and skeptic spawn
prompts paste whole rule files, which may mention the lint-fixer by name.
