---
type: llm
criteria: The report files the unguarded concurrent map write (the services DeviceService writes its lastSeen map from ProcessHeartbeat while a flush goroutine reads it — a real data race) under the Bugs category, not under Design Debt, and files the production time.Sleep calls (the retry backoff inside ProcessHeartbeat and/or retry.go / sync_service.go) under Design Debt.
focus: last_message
---
You are grading a code review report produced by an automated reviewer. Answer two
questions from the report text alone:

1. Is the unguarded concurrent map write (a `lastSeen` map, or an equivalent
   description of a map written from one goroutine while another reads it,
   in `internal/services/device_service.go`) listed under the 🐛 Bugs section?
   A mention only under 🔴 Design Debt, 🟡 Readability Debt, or 🟢 Polish fails
   this question. A report that never mentions the race fails it too.
2. Is the production `time.Sleep` (retry backoff / polling sleep in
   `internal/services/`) listed under the 🔴 Design Debt section rather than
   under 🐛 Bugs?

Both questions must be answered yes to pass. Ignore everything else in the
report. End your reply with exactly one line: `VERDICT: PASS` or `VERDICT: FAIL`.
