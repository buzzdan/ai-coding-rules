---
type: llm
criteria: Any wrapper type proposed for the worker count (WorkerCount, NumWorkers or similar) is handled honestly by the skeptic — either CONFIRMED with scorecard evidence or REFUTED with a concrete cheaper alternative.
focus: last_message
---
If the report proposes NO wrapper type for the worker count / batch size, PASS.
If a hunter proposed one, PASS when the skeptic's verdict line for it is either
`CONFIRMED (score N: ...)` with verified evidence, or `REFUTED (score 0|1: ...)`
followed by a concrete cheaper alternative (for example "pass numWorkers as an
int parameter to a constructor"). FAIL if the proposal appears with no skeptic
verdict, or if a REFUTED verdict names no alternative.
