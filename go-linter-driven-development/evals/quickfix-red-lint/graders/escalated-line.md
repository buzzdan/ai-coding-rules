---
# lint-fixer escalates rather than fixes design-level failures: the contract's
# ESCALATED: lines, or the LINT STATUS line that announces pending escalations
type: regex
pattern: 'ESCALATED:|LINT STATUS: escalations pending'
match: contains
target: trace
---
