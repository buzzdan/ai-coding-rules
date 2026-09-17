- **The mechanics follow the repository's concurrency model.** Name the cancellation
  signal, the join primitive, the atomic and lock types and the timer form the
  repository already uses — an asyncio task is cancelled and awaited, a thread is
  signalled and joined, a channel worker selects on its cancellation — and never introduce a
  concurrency library the repository does not already depend on.
