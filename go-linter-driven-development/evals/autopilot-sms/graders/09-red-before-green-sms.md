---
type: tool_order
before: { tool: Write, input_match: '"file_path":"[^"]*(sms|channel)[^"]*_test\.go"' }
after:  { tool: Write, input_match: '"file_path":"[^"]*sms([a-z0-9_]*[^t"/.])?\.go"' }
---
RED before GREEN, approximated on file names because tool_order sees paths, not
intent: the first test file whose path mentions `sms` or `channel` must be
written before the first NON-test implementation file whose basename contains
`sms`.

Why `sms` only on the after side: Phase 1.5 PREPARE legitimately creates
non-test files such as a `channel.go` (Channel type extraction) BEFORE the first
RED test, so `channel` must not count as feature GREEN code. The after regex
excludes `_test.go` without lookahead by requiring the character before `.go`
to be neither `t` nor a separator (`sms.go`, `sms_channel.go`, `sms_handler.go`
match; `sms_test.go` does not). Known false negative: a non-test file ending in
`t` (e.g. `sms_client.go`) is not matched, and both files must exist for the
grader to pass at all — grader 10 is the looser companion.
