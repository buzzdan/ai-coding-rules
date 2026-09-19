- **The moves in Python.** Exit path: a `threading.Event` the loop tests on every
  iteration, set by the owner's `close()`; in asyncio, cancellation of the task the
  owner holds. Joinable: `Thread.join()` after the event is set, or
  `asyncio.TaskGroup` so every task is awaited before the block exits. Cancellable
  wait: `self._stop.wait(timeout=d)` in place of `time.sleep(d)`; in asyncio,
  `await asyncio.sleep(d)` already is one.
