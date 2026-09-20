```python
# ❌ no owner, no exit; daemon=True hides the leak by killing it mid-item
threading.Thread(target=run_forever, daemon=True).start()


# ✅ the object that starts the thread stops it and waits for it
class Worker:
    def __init__(self, work: queue.Queue[Work]) -> None:
        self._work = work
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="worker")
        self._thread.start()

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                process(self._work.get(timeout=0.5))
            except queue.Empty:
                continue

    def close(self) -> None:
        self._stop.set()
        self._thread.join()


# ✅ asyncio: structured, both awaited, one failure cancels the other
async with asyncio.TaskGroup() as tg:
    tg.create_task(poller.run())
    tg.create_task(flusher.run())
```

> **In Python:** `asyncio.sleep` is cancellable by construction and fine;
> `time.sleep` on a thread with a stop condition is the finding, fixed with
> `Event.wait(timeout)`. A dropped `asyncio.create_task` handle is a leak. A lock
> lives beside the fields it guards and is taken with `with`; on 3.13+
> `Queue.shutdown()` is the closed-channel twin.
