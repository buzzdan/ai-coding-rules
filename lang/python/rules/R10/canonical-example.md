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
