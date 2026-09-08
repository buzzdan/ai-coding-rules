---
type: llm
criteria: After the refactor, nil is no longer representable for the Reporter's collaborators (R2 Q1/Q2/Q5/Q6) — not merely rejected.
focus: { source: file, path: internal/report/reporter.go }
---
Answer from the FOCUS file only. PASS requires ALL of:
1. A caller cannot build an invalid Reporter with a struct literal: the fields
   that hold the sink and the clock are unexported (no `Sink *Sink` / `Clock
   func() time.Time` exported fields).
2. The sink and the clock are not nil-able pointers or nil-able func values
   that the constructor merely checks: an absent sink is a real value (a no-op
   sink value, R11 Null Object) or the parameter is a non-pointer value type;
   the clock has a real default value (for example a `SystemClock()` /
   `DefaultClock()` constructor) that callers pass explicitly.
3. No method of Reporter re-checks its own fields for nil (no `if r.sink ==
   nil`, `if r.clock == nil`), and no constructor branch turns a nil argument
   into a default.
4. If nothing in the constructor can fail any more, it does not return an
   error (R2 Fix pattern: no error return once nothing can fail).
The shallow fix — moving `if sink == nil { return nil, err }` into NewReporter
while keeping `*Sink` parameters and a `*Reporter` return — is FAIL: nil is
still representable, just rejected.
