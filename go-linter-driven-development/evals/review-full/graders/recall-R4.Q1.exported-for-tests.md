---
# recall: the report names at least one file of this plant by basename.
# ids: R4.Q1.exported-for-tests
type: regex
pattern: '(heartbeat_parser\.go|service_test\.go)'
match: contains
target: last_message
---
