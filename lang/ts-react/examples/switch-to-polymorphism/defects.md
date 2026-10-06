- **The decision is asked twice (R11).** Whoever constructed `UpdateArg` already
  chose `KafkaPatch` — the value is typed as the union *because* that decision was
  made. The `switch (patch.kind)` re-asks it. A switch over a union the same module
  owns is always a second ask; "decide once at the edge" was violated the moment the
  cases appeared.
- **Ask-and-unpack.** The knowledge of *how a Splunk patch serializes* lives in the
  consumer, not on `SplunkPatch`. Each variant's wire mapping has no owner.
- **Silent growth failure.** Adding `'pubsub'` to `ExportType` and a `PubSubPatch` to
  the union and forgetting this `switch` passes `tsc` and ESLint — a statement
  `switch` with no `assertNever` arm is complete as far as either can tell — and
  ships a request carrying only `name` and `type`: a runtime no-op with no checker or
  test to catch it unless someone remembers to write one. (Mixed in, an R3 note: the
  business flow — identity → payload → TLS — is buried under `!== undefined` guards
  repeated nine times.)
