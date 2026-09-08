---
type: llm
criteria: The new ProcessHeartbeat body reads at a single altitude (R3 Q2) — every statement is a named call or an assignment of one; no string, index or byte manipulation in the body.
focus: { source: file, path: internal/services/device_service.go }
---
Locate the method `ProcessHeartbeat` on `*DeviceService` in the FOCUS file (the
receiver name may differ). If it is
not defined in this file, FAIL and say so (the function keeps its name and
file; the handler pins it).
PASS only if its body is a short story: parse the line (one call that returns a
heartbeat value or an error), look up or create the device (one call), apply
the status transition (one call), notify on DOWN (one call), score (one call),
persist (one call) — every statement a named call, an assignment of one, or an
early return of an error. FAIL if the body still contains any of: `strings.`
calls, slice indexing like `parts[0]` or `t[7:]`, string comparisons against
status literals (`== "READY"`), a labeled `continue`, `goto`, `time.Sleep`,
a hand-rolled retry loop, or nested `if` blocks more than two levels deep.
Helper functions elsewhere in the file may contain the low-level work; only the
ProcessHeartbeat body is judged.
