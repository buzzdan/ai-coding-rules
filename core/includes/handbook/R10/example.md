```text
# ❌ no owner, no exit, paced by sleep
spawn:
    loop forever:
        poll()
        sleep(interval)

# ✅ the type that starts it stops it; the wait is cancellable; close waits for the exit
Poller.run(cancel):
    timer = every(self.interval)
    loop:
        wait for the first of: cancel is signalled | timer fires
        cancelled → return
        self.poll(cancel)
Poller.close():
    signal cancel
    join the task                  # returns only when the loop has exited
```

> **Spelling:** the spawn is a `go` statement, a thread or an async task; the
> cancellation signal a context, an event or a token; the join a wait group, a
> `join()` or an awaited handle. A bare sleep in production code becomes a wait on
> the timer *and* the cancellation signal; a sleep the runtime cancels for you, as
> `asyncio.sleep` does, is fine. A lock lives beside the fields it guards, and a
> guard around fields only one task touches is deleted.
