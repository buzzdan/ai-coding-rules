---
type: llm
criteria: The review report does not ship a TraceID domain type as a Design Debt finding; a pass-through raw string used once (the traceID parameter that is copied into the X-Trace header) needs no type.
focus: last_message
---
Read the report. FAIL if a `TraceID` (or equivalently named) type is proposed as
a 🔴 Design Debt / Replace Primitive with Domain Type finding that survived the
skeptic. PASS if no TraceID type is proposed at all. Also PASS if a hunter
proposed it but the skeptic's verdict for it is `REFUTED (score 0 ...)` or
`REFUTED (score 1 ...)` — a refuted proposal that does not ship is the correct
outcome. Mentions of the parameter `traceID` in prose or in a 🟢 Polish /
BROADER CONTEXT note are fine.
