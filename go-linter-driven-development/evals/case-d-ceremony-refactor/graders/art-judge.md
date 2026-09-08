---
type: llm
criteria: Code that was already in its box stayed in its box; nothing was wrapped, layered or renamed for the sake of change. Deleting code nothing referenced is fine; adding structure is not.
focus: { source: files, paths: [internal/models, internal/handlers] }
---
This case is the negative control. Before the agent touched them,
`internal/models/grants.go` held `Grants` (a small earned type whose methods
`Has`/`All` are domain vocabulary) plus `ReplicaCount` and `Name`, and
`internal/handlers/trace.go` held a one-line `trace` helper with a comment
stating a real reason (log lines joined to their request). They already read
like art. The temptation the control measures is *adding* things: an
interface, a wrapper type, an options struct, a new package, a rename that
adds words.

Look at the two packages as they are now and PASS only if all four hold:

1. **No new indirection.** No interface introduced for `Grants` or `Handler`,
   no `TraceID`/`TraceHeader` type wrapping a single string, no options
   struct, no builder, no generic helper, no new file in either package that
   exists to hold structure the old code did not need. Any of these: FAIL.
2. **Deletion is allowed, growth is not.** If `grants.go` is gone or smaller
   because nothing in the repository referenced its types, that is dead-code
   removal and passes this point. If `Grants`, `ReplicaCount` or `Name`
   survive, they must not have grown methods, fields or wrappers.
3. **The trace reason survives.** Whether `trace` is still a helper or was
   inlined into its single caller, the comment explaining why the header is
   echoed (joining a device's log lines to the request) must still exist in
   substance next to the `X-Trace` header write. A restated-name comment in
   its place, or no comment, is FAIL.
4. **Names kept or sharpened.** Surviving identifiers (`Has`, `All`,
   `NewGrants`, `Routes`, `List`, `NewHandler`) mean what they meant. Renames
   that add words without meaning (`HasPermission`, `GetAll`, `traceRequest`)
   are FAIL.

Quote the line that decides each point. Anything that made a reader's glance
longer than before is FAIL; anything that made it shorter without adding
structure is PASS.
