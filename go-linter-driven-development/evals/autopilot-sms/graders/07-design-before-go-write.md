---
type: tool_order
before: { tool: Skill, input_match: 'code-designing' }
after:  { tool: Write, input_match: '"file_path":"[^"]*\.go"' }
---
Design before any Go file is created. `Write` covers new files; the sibling
grader 08 covers `Edit` on existing ones.
