---
# recall: the report names at least one file of this plant by basename.
# ids: R7.Q6.sleep-then-assert
type: regex
pattern: '(service_test\.go|heartbeat_test\.go)'
match: contains
target: last_message
---
