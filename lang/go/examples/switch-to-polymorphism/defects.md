- **The decision is asked twice (R11).** Whoever constructed `UpdateArg` already
  chose `KafkaPatch` — the value is an interface *because* that decision was made.
  The type switch re-asks it. A type switch over an interface the same package owns
  is always a second ask; "decide once at the edge" was violated the moment the
  cases appeared.
- **Ask-and-unpack.** The knowledge of *how a Splunk patch serializes* lives in the
  consumer, not on `SplunkPatch`. Each variant's wire mapping has no owner.
- **Silent growth failure.** Adding a `PubSubPatch` and forgetting this switch
  compiles clean and ships a request carrying only `Name` and `Type` — a runtime
  no-op with no compiler, linter, or test to catch it unless someone remembers to
  write one. (Mixed in, an R3 note: the business flow — identity → payload → TLS —
  is buried under nil-deref-convert plumbing repeated nine times.)
