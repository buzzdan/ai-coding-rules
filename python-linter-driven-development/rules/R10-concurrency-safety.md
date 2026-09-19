# R10 — Concurrency Safety

## Principle

Every concurrent task has an owner and a provable exit path; shared mutable state is owned
by one type and guarded where it lives; production code never sleeps to pace or
synchronize cancellable work. Concurrency is designed at construction time — who owns
the state, who stops the concurrent task — never patched in afterward.

## Why

This rule owns exactly what static analysis cannot prove. A race detector finds
races only at runtime, only on paths a test happens to exercise; no linter can see
that a loop blocking on a receive has no way out. The failures are the worst kind:
a leaked concurrent task accumulates silently until memory or file descriptors run out; an
unsynchronized concurrent write corrupts state or **crashes the process**; a bare
sleep in a retry loop holds a cancelled request hostage for the full backoff.
Each defect also has a design meaning — a concurrent task nobody can stop has no owner
(`R2-self-validating-types.md`: construction is where ownership is established), and
state written from two concurrent tasks without a guard is the sideways-access sin of
`R8-no-globals.md` in concurrent form. The mechanical neighbors of this rule — ignored
errors, unclosed resources, copied locks — belong to the linter, not to prose. R10
hunts the residue no tool can catch.

## Canonical example

### Before — unowned thread, no exit path

```python
def start_worker(work: queue.Queue[Work]) -> None:
    def run() -> None:
        while True:
            item = work.get()
            process(item)
            # No way to exit this loop — it outlives every caller.

    threading.Thread(target=run, daemon=True).start()
```

Three defects: the thread loops forever (leak — when the queue goes quiet it blocks
on `get()` until process exit), nobody holds a handle to stop or wait for it
(fire-and-forget: `start_worker` returns nothing, and the `daemon` flag only hides
the leak by killing the thread mid-item at interpreter shutdown), and cancellation
cannot reach it (no stop signal — the R8 sin, one level deeper).

### After — owned, stoppable, joinable

```python
class Worker:
    """Owns the thread it starts: close() stops it and waits for it."""

    def __init__(self, work: queue.Queue[Work]) -> None:
        self._work = work
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="worker")
        self._thread.start()

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                item = self._work.get(timeout=0.5)   # never blocks past the stop check
            except queue.Empty:
                continue
            process(item)

    def close(self) -> None:
        self._stop.set()
        self._thread.join()
```

On Python 3.13+, `queue.Queue.shutdown()` replaces the timeout loop: `get()` raises
`ShutDown` the moment the owner shuts the queue, the way a Go loop exits on a closed
channel. The asyncio spelling of the same ownership is structured concurrency:

```python
async with asyncio.TaskGroup() as tg:
    tg.create_task(poller.run())
    tg.create_task(flusher.run())
# both tasks are awaited here; one failing cancels the other
```

A bare `asyncio.create_task(...)` whose handle is dropped is the asyncio form of the
Before: the event loop keeps only a weak reference, so the task can disappear
mid-execution, and nobody can await or cancel it.

### Second case — uncancellable backoff + unguarded shared write

Found by a real hunter pass: a deploy retry loop that paces with a bare sleep and
records results in an unsynchronized module-level dict.

```python
# ❌ Before
for attempt in range(3):
    try:
        resp = httpx.post(f"{self.endpoint}/deploy", json=payload)
    except httpx.TransportError:
        time.sleep(attempt + 1)          # a stopping caller waits anyway
        continue
    ...
    GLOBAL_REGISTRY[name] = version      # written from every deploy thread, no lock


# ✅ After — backoff waits on the stop event; state owned by one guarded type
for attempt in range(3):
    try:
        resp = self._post(payload)
    except httpx.TransportError:
        if self._stop.wait(timeout=backoff(attempt)):
            raise Cancelled()            # the stop request cuts the backoff short
        continue
    ...
    self._registry.record(name, version)  # the Lock lives inside Registry, next to the dict
```

In asyncio the backoff is `await asyncio.sleep(backoff(attempt))` and nothing more:
cancelling the task raises `CancelledError` inside the sleep, so the wait is
cancellable by construction and needs no second signal.

## Design guidance

- **Whoever starts a concurrent task owns its shutdown.** Starting a concurrent task is
  acquiring a resource: the constructor or function that spawns it must hand back a
  way to stop it and a way to wait for it. Fire-and-forget concurrent tasks are acceptable
  only in entry-point wiring that lives as long as the process — and work that must
  legitimately outlive a request detaches honestly, keeping the request's values and
  tracing while dropping its cancellation, never by manufacturing a fresh root context.
- **Every blocking loop selects on its exit.** A loop that blocks on a receive, a
  send or a sleep also waits on its cancellation signal. A blocking operation with no
  exit case is a leak with a delay on it.
- **State and its guard are one unit.** Shared mutable state lives on one type with
  the lock declared directly above the fields it guards, and every access goes
  through that type's methods. A lock in one place guarding data in another is a
  convention, not a guarantee. (Whether that type is worth extracting is R1's
  scorecard; that it must not be a package global is R8.)
- **Prefer handing off to sharing.** If the design can pass values through a channel
  or queue, or confine state to a single concurrent task, no lock is needed at all — reach
  for a guard only when sharing is the honest requirement.
- **Pick the right guard.** A counter or flag touched from multiple concurrent tasks can be
  an atomic value instead of a lock; a concurrent map type only for append-only or
  disjoint-key caches — a plain map plus a lock is the default. A lock whose only job
  is one-time initialization is a once-guard wearing a costume.
- **Production code does not sleep.** Backoff, pacing, and polling wait on a timer
  *and* the cancellation signal at the same time; sustained rate limiting belongs to
  a rate limiter that honors cancellation. A bare sleep on a cancellable path ignores
  cancellation by construction. (Sleeps in tests are `R7-test-placement.md` Q6;
  startup jitter in entry-point wiring gets the same exemption as fire-and-forget
  above.)
- **The linter owns the mechanical neighbors.** Swallowed exceptions (ruff `BLE001`,
  `S110`), bare `except:` (`E722`), a `raise` inside `except` without `from`
  (`B904`), unclosed files and connections (`SIM115`, and `with` blocks) — enforce
  these in `pyproject.toml`'s `[tool.ruff.lint]`; do not re-hunt them here. There is
  no race detector: an unguarded write is found by reading the code.
- **The mechanics in Python.** Threads: stop with a `threading.Event` the loop checks,
  wait with `Thread.join`, never a `daemon` thread for work that owns a resource
  (daemon threads are killed mid-operation at interpreter shutdown). Every blocking
  loop waits with a timeout and re-checks the event, or consumes a queue the owner
  can shut down (`queue.Queue.shutdown()` on 3.13+, a sentinel item before that).
  asyncio: a task is owned by the `asyncio.TaskGroup` that created it, or by the
  object that keeps its handle and cancels and awaits it in `close()`; a dropped
  `create_task` handle is a leak. Python has no atomics and no concurrent dict, and
  the GIL does not make compound operations safe (`d[k] = d[k] + 1`, iterating while
  another thread deletes): the guard is a `threading.Lock` declared beside the
  fields it protects, taken with `with`, or confinement of the state to one thread.
  One-time initialization is a module-level constant or a `functools.cache`d
  zero-argument function. Backoff and polling: `Event.wait(timeout)` on a thread,
  `await asyncio.sleep(d)` in a task — the latter is cancellable by construction and
  is not a bare sleep; `time.sleep` on a thread that has a stop condition is.
- Forward design of the owning types: @code-designing. Cancellation discipline:
  `R8-no-globals.md`.

## Fix pattern

- **Inject the Exit Path**: add a cancellation case to the concurrent task's blocking loop;
  pass cancellation from the caller (the Pass Cancellation Down move in
  `R8-no-globals.md`). For fan-out result sends, either wait on cancellation around
  the send or size the channel buffer to the number of senders — so no sender can
  block forever after the caller returns early.
- **Make Concurrent Work Joinable**: return an owner with `Wait`/`Close`, or use a
  group the caller holds — spawn and join in the same hands.
- **Extract Synchronized Owner**: move shared state plus its lock onto one type;
  all access via methods. This proposes a new type — score it with R1's scorecard
  and expect the over-abstraction skeptic to challenge it.
- **Replace Sleep with Cancellable Wait**: wait on a timer and the cancellation
  signal together — or a ticker for polling loops.
- **Delete Unearned Guards**: a lock on state that only one concurrent task ever touches
  is ceremony — remove it (the concurrency mirror of R1's over-abstraction trap).
- **The moves in Python.** Exit path: a `threading.Event` the loop tests on every
  iteration, set by the owner's `close()`; in asyncio, cancellation of the task the
  owner holds. Joinable: `Thread.join()` after the event is set, or
  `asyncio.TaskGroup` so every task is awaited before the block exits. Cancellable
  wait: `self._stop.wait(timeout=d)` in place of `time.sleep(d)`; in asyncio,
  `await asyncio.sleep(d)` already is one.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

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
   loop). Exempt: startup jitter in entry-point wiring. (Test sleeps are R7's Q6,
   not this rule.)

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
