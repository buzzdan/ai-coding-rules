Build each search over `*.py` files; "spawn site" means wherever the repository
starts a thread or an asyncio task.

1. **Does every thread or task started in the diff have a provable exit path?**
   Detection: `grep -nE 'Thread\(|\.start\(\)|create_task\(|ensure_future\(|\.submit\(|TaskGroup\(|run_in_executor\(' <changed files>` —
   catches `threading.Thread(target=...)`, a `Thread` subclass's `.start()`,
   `asyncio.create_task`, executor submits and task groups. For each hit, read the
   body it runs: a `while True` or a blocking `queue.get()`/`await` must test a
   `threading.Event` (`while not self._stop.is_set():`), wait with a timeout and
   re-test, consume a queue the owner can shut down (`queue.shutdown()` on 3.13+,
   a sentinel item before that), or be an asyncio task the owner can cancel; or the
   work must be provably bounded.
   Violation: an unbounded loop or a blocking take with no exit condition — the
   thread or task leaks past `close()`. `daemon=True` is not an exit path: the
   interpreter kills a daemon thread mid-operation at shutdown, so it is acceptable
   only in entry-point wiring for work that owns no resource. A `while True: if
   q.empty(): continue` loop is equally a violation: it spins at 100% CPU — block
   on the queue with a timeout instead.

2. **Can the code that starts a thread or task also stop it and wait for it?**
   Detection: for each spawn site, check what the spawning object exposes: a
   `close()`/`stop()` (or `__exit__`/`__aexit__`) that sets the event and
   `join()`s the thread, or cancels and awaits the task; a `create_task` handle
   kept on `self` or inside an `asyncio.TaskGroup`, never dropped.
   Violation: fire-and-forget in library code — a dropped `create_task` handle, a
   thread started with no `join` anywhere, a `daemon=True` thread doing owned work
   — no caller can join it at shutdown; leaks and lost exceptions are invisible
   (asyncio's "Task exception was never retrieved" at garbage collection is a log
   line, not handling).

3. **Is shared mutable state written from a thread without a guard?**
   Detection: for each thread body, list writes to `self.` attributes, captured
   variables and dicts/lists (`grep -n -A20 'def _run\|def run\|target=' <file>`);
   cross-check that each written location is guarded —
   `grep -nE 'threading\.(Lock|RLock|Condition)|queue\.Queue|asyncio\.Lock' <package files>` —
   or confined to a single thread. There is no race detector and no atomic type:
   the GIL makes single bytecodes atomic, not compound operations (`d[k] += 1`,
   `if k in d: del d[k]`, iterating a dict while another thread deletes from it).
   Between asyncio tasks on one loop a guard is needed only across an `await`.
   Violation: any write reachable from two threads with no lock or queue
   ownership — for a dict iterated while mutated this is a `RuntimeError`, not a
   race that merely corrupts.

4. **Does each lock live next to the data it guards, and is the lock taken on
   every access?**
   Detection: `grep -nE -B1 -A5 'threading\.(Lock|RLock)\(\)' <changed files>` — the
   guarded attributes must be assigned in the same `__init__`, and every method
   touching them must hold the lock with `with self._lock:`; grep the attribute
   names across the module for access paths outside a `with` block. A lock handed
   to a helper together with a *copy* of the data guards nothing.
   Violation: a lock guarding attributes it doesn't live beside, or any access path
   that skips the lock — the guard is decorative.

5. **Does production code sleep?**
   Detection: `grep -nE 'time\.sleep\(' <changed files> | grep -v 'test_\|_test.py'`
   Violation: any hit on a thread that has a stop condition — backoff/pacing/polling
   must be `self._stop.wait(timeout=d)` (it returns early when the event is set) or
   a `queue.get(timeout=d)`. `await asyncio.sleep(d)` is cancellable by construction
   and is not this finding; a `time.sleep` inside an `async def` is (it blocks the
   loop). A bounded loop is not exempt: a retry that sleeps three times on a
   request thread still makes a stopping caller wait out every backoff; the count
   bounds the attempts, not the wait, and every request thread has a stop condition
   (the client going away, the server shutting down). Exempt: startup jitter in
   entry-point wiring. (Test sleeps are R7's Q6, not this rule.)

6. **Inverse — is a guard, thread or task ceremony?**
   Detection: for each NEW `Lock` or spawn site in the diff, grep the package for a
   second thread or task that ever touches the guarded state
   (`grep -rnE 'Thread\(|create_task\(|\.submit\(' <package dir>`) or for a
   caller that needed the work to be asynchronous.
   Violation: a lock on single-thread state, a thread whose caller immediately
   `join()`s it, or a `create_task` immediately awaited — delete the ceremony;
   concurrency has the same over-abstraction trap as R1. A lock guarding only
   one-time initialization is the same finding with a named fix: a module-level
   constant, or `functools.cache` on a zero-argument function.
