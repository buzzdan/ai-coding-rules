```tsx
// ❌ no owner, no exit; the interval outlives the component, and the slowest response lands last
useEffect(() => {
  setInterval(() => {
    void fetchStatus(id).then(setStatus)
  }, POLL_MS)
}, [id])

// ✅ the effect that starts the timer returns the cleanup that stops it; each tick retires the last
useEffect(() => {
  let inflight: AbortController | undefined
  const timer = setInterval(() => {
    inflight?.abort()                       // a slow response never lands after a newer one
    inflight = new AbortController()
    void fetchStatus(id, inflight.signal).then(setStatus).catch(ignoreAbort)
  }, POLL_MS)
  return () => {
    clearInterval(timer)
    inflight?.abort()
  }
}, [id])

// ✅ where the repository has TanStack Query, the query owns the fetch and the polling
const { data: status } = useQuery({
  queryKey: ['device-status', id],
  queryFn: ({ signal }) => fetchStatus(id, signal),
  refetchInterval: POLL_MS,
})
```

> **In TypeScript:** one thread, no locks. The units are promises, effects, timers,
> subscriptions and queries; the race is the stale closure and the out-of-order
> response, retired by `abort()` or an `ignore` flag set in the cleanup, and
> check-then-act on a ref across an `await` is the split guard. Sleep is
> `setTimeout`-based polling or backoff that nothing cancels; `refetchInterval`, or an
> interval cleared in the cleanup, is the cancellable wait. A `fetch` in `useEffect`
> in a repository that has the query layer is the finding, and a disabled
> `react-hooks/exhaustive-deps` is a suppression of this rule.
