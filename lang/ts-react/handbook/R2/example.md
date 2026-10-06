```typescript
// ❌ an assertion is not validation; whatever the server sent is now typed Device
export async function fetchDevice(id: DeviceId): Promise<Device> {
  const data = await apiClient.get<Device>(`/devices/${id}`)
  return data
}

// ✅ the boundary parses unknown once, with type guards; the domain only sees a Device
export function parseDevice(raw: unknown): Device {
  if (!isRecord(raw) || typeof raw.id !== 'string' || typeof raw.hostname !== 'string') {
    throw new ApiError('device: malformed response')
  }
  return { id: parseDeviceId(raw.id), hostname: raw.hostname }
}

export async function fetchDevice(id: DeviceId): Promise<Device> {
  return parseDevice(await apiClient.get(`/devices/${id}`))
}

// ❌ optional collaborator kept undefined-able; every method re-asks the question
class Reporter {
  constructor(private readonly sink?: Sink) {}

  record(ev: UiEvent): void {
    if (this.sink !== undefined) this.sink.write(ev)
  }
}

// ✅ absence is a named value bound once; no argument is ever undefined
const NULL_SINK: Sink = { write() {} }

class Reporter {
  constructor(private readonly sink: Sink = NULL_SINK) {}

  record(ev: UiEvent): void {
    this.sink.write(ev) // no guard anywhere
  }
}
```

> **In TypeScript:** the self-validating type is the `readonly` shape with the one
> factory that builds it, shown under R1, or a class with a private constructor and a
> static `parse`. Types are erased, so the invariant lives in that factory:
> `readonly` closes assignment after construction, and the factory is the only
> production site that spells the literal. The finding is a mutable `interface`
> carrying invariants with no factory, `data as Device`, an `apiClient.get<T>()`
> taken on faith at the boundary, or an `as unknown as`. Where the repository already
> uses a schema library, `schema.parse` at the boundary is the constructor and the
> inferred type its shape; a refactor never introduces one. The second fence is the
> optional-collaborator case: a Null Object bound once as a module constant, the
> parameter typed `Sink` and never `Sink | undefined`, supplied by a default.
