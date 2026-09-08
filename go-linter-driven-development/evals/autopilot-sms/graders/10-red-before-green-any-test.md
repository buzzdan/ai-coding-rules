---
type: tool_order
before: { tool: Write, input_match: '"file_path":"[^"]*_test\.go"' }
after:  { tool: Write, input_match: '"file_path":"[^"]*sms([a-z0-9_]*[^t"/.])?\.go"' }
---
Looser companion to grader 09: SOME new test file precedes the first sms
implementation file, regardless of how the test file is named (a `phone_test.go`
or `e164_test.go` RED test still counts). Passes trivially if PREPARE's SAFE gate
wrote characterization tests first — which is the intended order anyway.
