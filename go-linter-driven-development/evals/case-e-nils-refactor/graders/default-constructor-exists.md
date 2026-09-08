---
# The null object for "no sink" has a name and a constructor. Go spells it
# Discard (io.Discard) as often as Default/System/Nop; any of those is the fix.
type: regex
pattern: 'func (Default|System|Discard|Nop|Noop|Null)\w*\(\)'
match: contains
target: files
---
