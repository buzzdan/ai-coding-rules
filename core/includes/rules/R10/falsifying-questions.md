Build each search over the language's source files (`{{.SrcGlob}}`); "spawn site"
means wherever the repository starts a {{.Task}} — a `go` statement, a thread or
task constructor, a task-group or executor submit, an `async` job.

1. **Does every {{.Task}} started in the diff have a provable exit path?**
   Detection: in the changed files, find every spawn site. For each hit, read the
   {{.Task}}'s body: a loop or a blocking take/put must wait on the cancellation
   signal (or a closed queue) at the same time, or the work must be provably bounded.
   Violation: an unbounded loop or a blocking take/put with no exit case — the
   {{.Task}} leaks. A loop with a non-blocking default branch is equally a
   violation: it spins at 100% CPU — block on the queue or a ticker instead.

2. **Can the code that starts a {{.Task}} also stop it and wait for it?**
   Detection: for each spawn site, check what the spawning function returns/exposes:
   a cancellation signal it honors plus a join/close/done handle, or a task group the
   caller holds.
   Violation: fire-and-forget in library code — no caller can join the {{.Task}} at
   shutdown; leaks and lost errors are invisible.

3. **Is shared mutable state written from a {{.Task}} without a guard?**
   Detection: for each spawned body, list writes to captured variables, receiver
   fields, and maps; cross-check that each written location is guarded — search the
   package for the language's lock, atomic and concurrent-collection types (atomic
   values and concurrent maps are legitimate guards for the state they cover) — or
   confined to a single {{.Task}}. Run the repository's race detector or thread
   sanitizer where it has one, but treat a quiet detector as absence of evidence,
   not evidence of absence.
   Violation: any write reachable from two {{.Task}}s with no lock/queue
   ownership — for maps this can be a fatal crash, not a race that merely corrupts.

4. **Does each lock live next to the data it guards, and is the lock taken on
   every access?**
   Detection: for each lock declared in the changed files, read the declaration's
   neighbors — the guarded fields must sit in the same type, and every method
   touching them must lock; search the field names across the package for unlocked
   access paths.
   Violation: a lock guarding fields it doesn't live beside, or any access path
   that skips the lock — the guard is decorative.

5. **Does production code sleep?**
   Detection: search the changed non-test files for the language's sleep call
   (`time.Sleep`, `time.sleep`, `asyncio.sleep`, `Thread.sleep`, `setTimeout`).
   Violation: any hit on a cancellable path — backoff/pacing/polling must wait on a
   timer and the cancellation signal together, sustained pacing on a rate limiter
   that honors cancellation. Exempt: startup jitter in entry-point wiring. (Test
   sleeps are R7's Q6, not this rule.)

6. **Inverse — is a guard or {{.Task}} ceremony?**
   Detection: for each NEW lock or {{.Task}} in the diff, search the package for a
   second {{.Task}} that ever touches the guarded state, or for a caller that needed
   the work to be asynchronous.
   Violation: a lock on single-{{.Task}} state, or a {{.Task}} whose caller
   immediately blocks waiting for it — delete the ceremony; concurrency has the same
   over-abstraction trap as R1. A lock guarding only one-time initialization is the
   same finding with a named fix: the language's once-only initializer.
