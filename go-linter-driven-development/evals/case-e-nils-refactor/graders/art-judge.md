---
type: llm
criteria: Nil stopped doing three jobs; every optional or absent thing now has a name, and each of the three files tells one story at one altitude.
focus: { source: files, paths: [internal/report] }
---
Glance at the package as a first-time reader (concepts may have moved into files of their own). Judge shape and naming.

PASS only if all four hold, quoting the convincing line for each:

1. **Absence has a name.** `Find` no longer returns a nil pointer: it returns
   `(Device, bool)` or an `(Device, error)` with a named `ErrUnknownDevice`.
   "No sink" is a value, not nil: a null-object sink (`DiscardSink`,
   `NopSink`) or an unexported default, so `Record` has no nil check at all.
   "Default clock" is the constructor's business, never re-defaulted inside a
   method.
2. **The constructor owns the invariants.** `Reporter`'s sink and clock are
   unexported; `NewReporter` takes what it needs (functional options or a
   small value struct are both fine) and callers never pass `nil, nil` to
   mean "defaults". `wire.go` reads as `NewReporter(NewSink(w))` or with
   named options, not positional nils.
3. **Methods read as sentences.** `Record` is one line of intent:
   stamp the event with the clock, hand it to the sink. `Announce` reads:
   find the device, and if known, record its event — with comma-ok or an
   error, not `!= nil` on a pointer.
4. **Comments earn their place.** `// Reporter is a reporter.`,
   `// Sink is where events are written.` and the `// forget this once →
   panic` warning are gone; any remaining comment states a contract the
   name cannot.

FAIL outright if `r.Sink == nil`, `r.Clock == nil`, `return nil` from `Find`,
or `NewReporter(sink, nil, nil)` survives anywhere in the three files.
