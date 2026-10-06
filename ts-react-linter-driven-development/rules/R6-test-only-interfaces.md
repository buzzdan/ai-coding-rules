# R6 — Test-Only Interfaces

## Principle

A seam that exists only so a test can substitute a double — an interface with one
production implementer, a patched attribute, an injection parameter no production
caller varies — is deleted; depend on the concrete collaborator. Don't create interfaces
until you need them; a test fake is not a need. An interface is justified only by a
real second production implementation or a verified import cycle.

## Why

This is the exact failure that slips past reviews: a reasonable-looking interface
with a comment "explaining" it (usually "avoids an import cycle" or "for testing"),
one production implementation, and a test double as the only other implementer. The
interface adds an indirection every reader must resolve, detaches the consumer from
the real type's documentation and behavior, and — worst — licenses the test to
exercise a hand-written double instead of the real collaborator, so the test proves
nothing about production wiring. A hand-written type that only satisfies a
production interface to stand in for the real collaborator IS a mock, whatever the
file calls it. A "fake" is a real implementation with fake *data* — embedded DB,
in-process HTTP server, temp dir. Orchestrators are tested by wiring their real
collaborators (`R7-test-placement.md`); they never need injection seams carved for
doubles.

## Canonical example

### Before — a seam exists only for a test double

```typescript
// deviceRepository.ts — one production implementation (ApiDeviceRepository); the
// interface and the context exist "so tests can swap it"
export interface DeviceRepository {
  findLatest(id: DeviceId): Promise<Device>
}

export const DeviceRepositoryContext = createContext<DeviceRepository | undefined>(undefined)

// DevicesPage.test.tsx — the ONLY other implementer is a hand-written double
class MockDeviceRepository implements DeviceRepository {
  constructor(private readonly device: Device) {}

  findLatest(): Promise<Device> {
    return Promise.resolve(this.device)
  }
}
```

The same seam without an interface, the React way — a module mock of the concrete
collaborator in a page test, while MSW handlers for the same endpoint already exist:

```typescript
vi.mock('../hooks/useDevices', () => ({ // ❌ the double rides in through the module
  useDevices: () => ({ data: [device], isLoading: false }),
}))
```

### After — concrete dependency, tested by wiring the real collaborator

```tsx
// devicesApi.ts — concrete; the client arrives as a parameter, never from a module (R8)
export async function fetchLatestDevice(client: ApiClient, id: DeviceId): Promise<Device> {
  return parseDevice(await client.get(`/devices/${id}`))
}

// useLatestDevice.ts — the hook reads the same client through the provider
export function useLatestDevice(id: DeviceId) {
  const { client } = useServices()
  return useQuery({ queryKey: ['devices', id], queryFn: () => fetchLatestDevice(client, id) })
}

// DevicesPage.test.tsx — the REAL hook over the REAL fetch; the MSW handler is the
// fake data
it('shows the latest device', async () => {
  server.use(http.get('/api/devices/:id', () => HttpResponse.json(deviceFixture)))

  renderWithProviders(<DevicesPage />) // real objects, fake data

  expect(await screen.findByRole('heading', { name: deviceFixture.hostname })).toBeInTheDocument()
})
```

The test now covers the seam it claims to cover: the real hook's query runs through
the `ApiClient` the test-utils provider supplies against a real `fetch`, and
`parseDevice` sees the same wire shape production does. The interface, the context,
its indirection and the double are all deleted; the `vi.mock` is gone with them. A
TypeScript interface is structural, like a Go interface, so the one-implementer
smell transfers unchanged; `vi.mock` of an internal hook or service and a `vi.fn()`
object shaped like a service are the same smell with no declaration to grep for. The
earned interface, for contrast: a `PreferencesStore` with two production
implementations — one over `localStorage` for the browser, one in memory for the
embedded build that has no storage — where the second implementer ships, and the
test picks the in-memory one for the same reason production does.

## Design guidance

- **Interfaces are earned by a second production implementation** — an in-memory
  repository that production code can also use, a second backend, a real plug point.
  Until that exists, depend on the concrete type.
- **"For testing" never justifies an interface.** The test's job is to wire real
  collaborators over fake data (real store over embedded DB, real client against an
  in-process HTTP server) — `R7-test-placement.md` places the test; @testing has the harness
  patterns.
- **"Avoids an import cycle" is a claim, not a fact — verify it.** A real cycle
  exists only if the dependency's package imports the consumer's package back. If
  the grep (below) shows no back-import, the comment is cover for a test seam.
- **A real cycle is a layering bug, not an interface opportunity.** Move the package
  so the dependency direction is downward; don't invert the arrow with an interface
  whose only purpose is to break the cycle a double rides in on.
- **When an interface is genuinely needed**, define it at the point of use (in the
  consumer's package), keep it small and cohesive, and expect every implementation
  to be production code. The worked case of an *earned* interface — multiple
  production implementations replacing a growing type switch, sealed by an
  unexported method: `../examples/switch-to-polymorphism.md` (dispatch discipline:
  `R11-conditional-dispatch.md`).

## Fix pattern

- **Delete the Test Seam**: replace the interface field, patched attribute or
  injection parameter with the concrete type; delete the interface declaration.
- **Rewrite the test around real collaborators**: construct the real dependency over
  fake data (embedded DB, temp dir, in-process HTTP server) and exercise the consumer's
  public API (@testing for harness patterns; placement per
  `R7-test-placement.md`).
- **Delete the double**: the fake type in `*.test.ts*` / `fakes/` / `mocks/` /
  `testutil*` goes with the interface.
- **If a verified cycle exists, fix the layering**: extract the shared vocabulary
  into a lower package both can import, or move the consumer — the dependency arrow
  must point downward.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **How many production implementations does each new/changed interface have?**
   Detection: for each `interface` or abstract class in the diff
   (`grep -rn "^export interface" --include='*.ts' --exclude-dir=node_modules .`
   lists them),
   `grep -rn 'implements <Interface>\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   plus `grep -rnE ': <Interface> = \{|satisfies <Interface>\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   for object literals typed by it. An interface is structural, so an implementer
   need not name it; where none does, the method-name census
   (`grep -rnE '^\s+(async )?<method>\(' --include='*.ts' --exclude-dir=node_modules .`)
   is the only census — read it, then verify it.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: the same greps over `*.test.ts`/`*.test.tsx`, `src/test-utils/mocks/*Mock.ts`
   and `__mocks__/` directories; then
   `grep -rn "vi.mock(" --include='*.test.ts' --include='*.test.tsx' .` filtered to
   relative and alias imports (`'./`, `'../`, `'@/`), and
   `grep -rnE 'vi\.fn\(\)' --include='*.test.ts' --include='*.test.tsx' .` for
   objects shaped like a service — read what each targets: a `vi.mock` of an
   internal hook or service is a seam that exists only so the test can substitute a
   double, the same smell without the interface.
   Violation: yes — one production implementation + a double (a `Mock*` class, a
   `vi.fn()` object, a `vi.mock` of the collaborator) = test-only seam; delete the
   interface, test the real hook over MSW, and give the collaborator a real
   in-memory implementation only if production also needs one. Mocking the true
   external boundary — `fetch` through MSW, the router, the auth SDK, the clock
   (`vi.useFakeTimers`), `matchMedia` — is not this finding.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction:
   ```bash
   # a real cycle exists only if the dependency module imports the consumer back:
   grep -rnE "from '(\.|@/).*<consumer module>'" <dependency dir>/*.ts   # no match ⇒ no cycle ⇒ interface unjustified
   ```
   `import/no-cycle` reports the real ones where the repository configures it. An
   `import type` is erased and is never a run-time cycle, so an interface justified
   by "the import would cycle" is not justified when the concrete type could be
   imported with `import type` for the annotation.
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: `grep -rnE 'new <Consumer>\(|\b<Consumer>\(|<<Context>\.Provider value=' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   — inspect the argument's type at each production call site. A hook or function
   whose trailing parameter is the interface and whose only non-default argument
   comes from a test (`useDevices(id, repo = apiRepository)`) is the same shape, and
   so is a factory returning the interface type (`createDeviceRepository():
   DeviceRepository`) with one body behind it.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: `grep -rn -B3 -E '^export (interface|abstract class) ' <changed files> | grep -iE 'for test|import cycle|mock|swap'`,
   then `grep -rniE 'for test(ing)?|so (that )?tests can' <changed files>` and
   `find src -type d -name '__mocks__' -not -path '*/node_modules/*'`.
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
