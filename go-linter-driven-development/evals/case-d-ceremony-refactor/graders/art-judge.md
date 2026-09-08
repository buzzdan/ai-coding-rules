---
type: llm
criteria: Code that was already in its box stayed in its box; nothing was wrapped, layered or renamed for the sake of change.
focus: { source: files, paths: [internal/models/grants.go, internal/handlers/trace.go] }
---
These two files are the negative control: `Grants` is a small earned type
whose methods are the vocabulary of the domain, and `trace` is a one-line
handler helper with a comment that states a real reason (log lines joined to
their request). Before the agent touched them they already read like art.

PASS only if they still do, and say what (if anything) changed:

1. **No new indirection.** No interface introduced for `Grants` or `Handler`,
   no `Tracer`/`TraceHeader` type wrapping a single string, no options
   struct, no builder, no generic helper. A `Permission` set type is fine
   only if the file already had it; adding one now is ceremony: FAIL.
2. **Names kept or sharpened.** `Has`, `All`, `NewGrants`, `trace`, `Routes`
   still mean what they meant. Renames that add words without meaning
   (`HasPermission`, `GetAll`, `traceRequest`) are FAIL.
3. **Comments kept where they carry a reason.** The `trace` comment about
   joining log lines to the request still exists in substance. Deleting it
   or replacing it with a restatement of the name is FAIL. Tightening a
   restating comment (`// NewGrants creates new Grants.`) is fine.
4. **Nothing moved between boxes.** `Grants` still lives in `models`,
   `trace` still lives on the handler. A new package or file for either is
   FAIL.

Small tidy-ups (a doc comment that now states a contract, a removed blank
line) are PASS. Anything that made the reader's glance longer is FAIL.
