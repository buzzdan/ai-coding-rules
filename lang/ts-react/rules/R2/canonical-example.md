Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing):

```typescript
/** A named, validated service port; it cannot exist out of range. */
export interface Port {
  readonly name: string
  readonly number: number
}

export function parsePort(name: string, number: number): Port {
  if (!Number.isInteger(number) || number <= 0 || number > 65535) {
    throw new RangeError(`port '${name}': ${number} out of range 1-65535`)
  }
  return { name, number }
}
```

This is the TypeScript self-validating type: a `readonly` shape and the one factory
that builds it. Types are erased, so no check runs on a literal; what "the
constructor is the only entry" means here is that `readonly` forbids assignment after
construction and `parsePort` is the only production site that spells a `Port`
literal — a discipline, enforced by Q1's grep rather than by `tsc`. Before this type
existed, `p.port > 0 && p.port <= 65535` was duplicated across two loops at the use
site. After, there is no `isValid()` and no re-check anywhere: the concept of a
maybe-invalid port is deleted from downstream logic, not relocated. A mutable
`interface` with the same two fields and no factory, or `{ name, number: 70000 }`
written beside the factory, is the hole this rule hunts: every caller can build an
invalid `Port`, and every method must defend.

The same pattern for a composed object — validate dependencies once, then trust:

```typescript
// ❌ every method defends
class UserService {
  constructor(public repo: Repository | undefined) {}

  async createUser(user: User): Promise<void> {
    if (this.repo === undefined) { // repeated in every method; forget one → TypeError at run time
      throw new Error('repo is undefined')
    }
    await this.repo.save(user)
  }
}

// ✅ constructor validates once; methods trust the instance
class UserService {
  constructor(private readonly repo: Repository) {} // new UserService(undefined) fails tsc

  async createUser(user: User): Promise<void> {
    await this.repo.save(user) // no checks — an invalid service cannot exist
  }
}
```

The typed half is mechanical: `repo: Repository` rejects `undefined` at compile time,
and a run-time guard behind it would trip `@typescript-eslint/no-unnecessary-condition`.
The finding survives where the parameter says `Repository | undefined`, or where the
caller is not type-checked.

Where the value is built from unstructured input — a wire response, a search param —
the constructor is a boundary parser that narrows `unknown` with type guards and then
constructs, so the domain only ever sees typed fields:

```typescript
export function parseDevice(raw: unknown): Device {
  if (!isRecord(raw) || typeof raw.id !== 'string' || typeof raw.hostname !== 'string') {
    throw new ApiError('device: malformed response')
  }
  return { id: parseDeviceId(raw.id), hostname: raw.hostname }
}
```

At a boundary that already uses a schema library, `deviceSchema.parse(raw)` is the
same constructor and `z.infer` its type; inside the domain the factory is enough.
`data as DeviceApiResponse`, `apiClient.get<Device>()` taken on faith and
`as unknown as Device` are paths around the constructor: an assertion is not
validation.
