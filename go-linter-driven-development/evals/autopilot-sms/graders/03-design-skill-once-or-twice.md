---
type: tool_used
tool: Skill
input_match: 'code-designing'
min: 1
max: 2
---
Phase 1 invokes @code-designing exactly once; the only legitimate second call is
one escalation (a Phase 4 cluster in cluster-scoped mode, or @refactoring's
escalation after GREEN). A third call means design happened mid-implementation
(the "never invoke @code-designing from GREEN" rule) or the plan was redone.
