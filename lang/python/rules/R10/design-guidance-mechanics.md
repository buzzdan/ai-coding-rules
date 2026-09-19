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
