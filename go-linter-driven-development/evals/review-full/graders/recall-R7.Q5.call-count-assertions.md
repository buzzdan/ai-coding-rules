---
# recall: the report names at least one file of this plant by basename.
# ids: R7.Q5.call-count-assertions
type: regex
pattern: '(heartbeat_test\.go|scheduler_test\.go)'
match: contains
target: last_message
---
