---
type: tool_used
tool: Skill
input_match: ':linter-driven-development"'
min: 1
---
The bare prompt "Implement SPEC.md" in a Go repo must trigger the meta
orchestrator. The match is anchored on `:linter-driven-development"` (plugin
prefix colon, skill name, closing quote) because every other plugin skill id
also contains the substring `linter-driven-development`.
