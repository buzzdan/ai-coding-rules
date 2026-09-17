### Before — unowned {{.Task}}, no exit path

```text
startWorker(workQueue):
    spawn:                               # a background task nobody holds
        loop forever:
            work = workQueue.take()      # blocks; no way to exit — it outlives every caller
            process(work)
```

Three defects: the {{.Task}} loops forever (leak — when the queue goes quiet it
blocks on the take until process exit), nobody holds a handle to stop or wait for it
(fire-and-forget: `startWorker` returns nothing), and cancellation cannot reach it
(no cancellation signal is passed in — the R8 sin, one level deeper).

### After — owned, cancellable, joinable

```text
Worker
    done                                 # signalled when the task has fully exited
startWorker(cancel, workQueue):          # owns the task it spawns: the returned Worker
    worker = Worker()                    # can stop it (via cancel) and wait for it (via join)
    spawn:
        finally: worker.done.set()
        loop:
            wait for the first of: work = workQueue.take() | cancel is signalled | the queue is closed
            queue closed → exit          # don't spin on empty reads
            cancelled    → exit          # clean exit — cancellation reaches the loop
            process(work)
    return worker
Worker.join():
    wait for done
```

### Second case — uncancellable backoff + unguarded shared write

Found by a real hunter pass: a deploy retry loop that paces with a bare sleep and
records results in an unsynchronized module-level map.

```text
# ❌ Before
for attempt in 0..2:
    response = post(endpoint + "/deploy", payload)
    if it failed:
        sleep((attempt + 1) seconds)     # a cancelled caller waits anyway
        continue
    ...
    GlobalRegistry[name] = version       # two concurrent deploys corrupt the map, or crash

# ✅ After — the backoff waits on the timer AND the cancellation signal; state owned by one guarded type
for attempt in 0..2:
    response = self.post(cancel, payload)
    if it failed:
        if not sleepUnlessCancelled(cancel, backoff(attempt)): return cancelled
        continue
    ...
    self.registry.record(name, version)  # the lock lives inside Registry, next to the map

sleepUnlessCancelled(cancel, duration):
    wait for the first of: the timer fires | cancel is signalled
    return true when the timer fired
```

How the spawn, the cancellation signal, the join and the timed wait are spelled — a
Go `go` statement with a cancellation context and a `select`, an asyncio task with
`cancel()` and `await`, a thread with an event and `join()` — follows the
repository's concurrency model; the shape is the same in each.
