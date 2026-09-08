---
# recall: the report names at least one file of this plant by basename.
# ids: R3.Q2.parse-beside-decision, R3.Q4.labeled-continue-dedupe, R1.Q1.inline-id-check, R1.Q5.five-results, R9.critic.extraction-order
type: regex
pattern: '(device_service\.go|heartbeat_parser\.go)'
match: contains
target: last_message
---
