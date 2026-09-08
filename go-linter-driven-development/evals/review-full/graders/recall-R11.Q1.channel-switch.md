---
# recall: the report names at least one file of this plant by basename.
# ids: R11.Q1.channel-switch
type: regex
pattern: '(notify\.go|validate\.go|retry\.go)'
match: contains
target: last_message
---
