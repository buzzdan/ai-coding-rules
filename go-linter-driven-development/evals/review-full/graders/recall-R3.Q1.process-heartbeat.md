---
# recall: the report names at least one file of this plant by basename.
# ids: R3.Q1.process-heartbeat, R3.Q3.block-comments, R3.Q1.nested-blocks, R1.Q3.status-string-compare, R1.Q4.minus-one-sentinel, R2.Q5.tags-nil-or-slice, R10.Q3.last-seen-race, R10.Q5.goto-sleep-backoff, R11.Q4.force-flag-in-body, R9.Q4.what-comment-process-heartbeat, R9.critic.provenance-tail, R9.critic.decoder-ring, R9.critic.review-defense, R9.critic.long-private-comment, R2.Q2.validate-device-in-method, R3.Q5.dishonest-names, R4.Q6.feature-envy, R5.Q1.god-file, R10.Q1.unowned-loop, R10.Q2.goroutine-in-constructor
type: regex
pattern: 'device_service\.go'
match: contains
target: last_message
---
