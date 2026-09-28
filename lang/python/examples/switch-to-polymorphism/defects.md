- **The decision is asked twice (R11).** Whoever constructed `UpdateArg` already
  chose `KafkaPatch` — the value is typed as the protocol *because* that decision
  was made. The class-pattern `match` re-asks it. A type switch over a protocol the
  same package owns is always a second ask; "decide once at the edge" was violated
  the moment the cases appeared.
- **Ask-and-unpack.** The knowledge of *how a Splunk patch serializes* lives in the
  consumer, not on `SplunkPatch`. Each variant's wire mapping has no owner.
- **Silent growth failure.** Adding a `PubSubPatch` and forgetting this `match`
  passes ruff and ty and ships a request carrying only `name` and `type` — a
  runtime no-op with no checker or test to catch it unless someone remembers to
  write one. (Mixed in, an R3 note: the business flow — identity → payload → TLS —
  is buried under `is not None` plumbing repeated nine times.)
