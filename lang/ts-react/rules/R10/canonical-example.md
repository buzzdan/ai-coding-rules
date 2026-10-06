### Before — unowned effect, no exit path

```tsx
function DeviceStatus({ id }: Readonly<{ id: DeviceId }>) {
  const [status, setStatus] = useState<Status>()

  useEffect(() => {
    setInterval(() => {
      void fetchStatus(id).then(setStatus)        // the previous fetch may land after the next
    }, POLL_MS)
    // No cleanup — the interval outlives the component.
  }, [id])

  return <StatusBadge status={status} />
}

function DevicesProvider({ children }: Readonly<{ children: ReactNode }>) {
  const [devices, setDevices] = useState<Device[]>([])
  void fetchDevices().then(setDevices)            // a fetch per render, none of them cancellable
  return <DevicesContext.Provider value={devices}>{children}</DevicesContext.Provider>
}
```

Three defects: the interval runs forever (leak — unmounting `DeviceStatus` does not
clear it, and every change of `id` starts a second one beside the first), nobody
holds a handle to stop or await the fetch (fire-and-forget: the `.then` sets state
on a component that may already be gone, and the provider starts a new request on
every render), and cancellation cannot reach it (no `AbortController`, no `signal`
— the R8 sin, one level deeper).

### After — owned, cancellable, cleaned up

```tsx
function DeviceStatus({ id }: Readonly<{ id: DeviceId }>) {
  const { data: status } = useQuery({
    queryKey: ['device-status', id],
    queryFn: ({ signal }) => fetchStatus(id, { signal }),   // the query owns the fetch and aborts it
    refetchInterval: POLL_MS,                               // and owns the polling: it stops on unmount
  })
  return <StatusBadge status={status} />
}
```

Where no query layer exists, the effect that starts the work returns the function
that stops it — the cleanup runs on unmount and before every re-run — and each tick
aborts the request before it, so two polls are never in flight and the slow one
cannot overwrite the fresh one:

```tsx
useEffect(() => {
  let inflight: AbortController | undefined
  const timer = setInterval(() => {
    inflight?.abort()                               // the previous tick's response is retired first
    inflight = new AbortController()
    void refreshStatus(id, inflight.signal).then(setStatus).catch(ignoreAbort)
  }, POLL_MS)
  return () => {                                  // whoever starts the timer owns its stop
    clearInterval(timer)
    inflight?.abort()
  }
}, [id])
```

A promise whose handle is dropped — `void fetchDevices()` with nothing holding a
`signal` — is the effect-free form of the Before: nobody can cancel it, nobody sees
its rejection, and its `.then` writes state whenever it pleases.

### Second case — out-of-order response + stale closure

Found by a real hunter pass: a search box whose results flicker back to an older
query, and a counter that stops at 1.

```tsx
// ❌ Before
useEffect(() => {
  void searchDevices(query).then(setResults)      // two in-flight searches; the slower one wins
}, [query])

useEffect(() => {
  const timer = setInterval(() => setCount(count + 1), 1000)   // `count` frozen at the first render
  return () => clearInterval(timer)
}, [])

// ✅ After — the cleanup retires the superseded request; the updater reads the latest value
useEffect(() => {
  let ignore = false
  void searchDevices(query).then((found) => {
    if (!ignore) setResults(found)
  })
  return () => {
    ignore = true                                 // a response to a query nobody wants any more is dropped
  }
}, [query])

useEffect(() => {
  const timer = setInterval(() => setCount((n) => n + 1), 1000)
  return () => clearInterval(timer)
}, [])
```

Where `searchDevices` takes a `signal`, an `AbortController` whose `abort()` is the
cleanup replaces the `ignore` flag and also stops the network request. In a
repository with TanStack Query both halves of the first case disappear:
`useQuery({ queryKey: ['search', query], … })` keys each request by its input,
drops the superseded one, and never needs a second signal.
