---
# lint-fixer report: the mechanical class is FIXED (errcheck is the surest member);
# accepts the contract's FIXED: line or a FIXED section listing linters
type: regex
pattern: 'FIXED\b.{0,600}errcheck'
flags: s
match: contains
target: trace
---
