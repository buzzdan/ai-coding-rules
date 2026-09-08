---
type: tool_order
before: { tool: Agent, input_match: '"subagent_type":"[^"]*lint-fixer"' }
after:  { tool: Skill, input_match: 'pre-commit-review' }
---
Timing negative from the plan: the review pass follows the full lint (Phase 3
before Phase 4) and is never invoked mid-implementation. tool_order compares
first occurrences, so a review that ran before any lint-fixer call fails here.
