From the Port case (`R1-primitive-obsession.md` carries the full three-stage study).
After extraction, `Port`/`Ports`/`firstNamed`/`first` say nothing about Kubernetes
or Weka: juicy (range validation, collection queries) and domain-generic → rung 3,
a shared `src/networking/` module. The feature keeps a two-line storified policy
function:

```typescript
const WEKA_API_PORT = 'weka-api'

export function managementPort(ports: Ports): Port | undefined {
  return ports.firstNamed(WEKA_API_PORT) ?? ports.first()
}
```

Only the domain-generic parts were promoted: the `WEKA_API_PORT` constant is feature
policy and stays in the feature. A shared module that knows one feature's port names
is not shared vocabulary — it is leaked policy.

The rung-1 contrast — a trivial helper that stays put:

```typescript
// One caller, no domain vocabulary, no rules of its own: stays non-exported.
function parseK3sArgument(arg: string): readonly [key: string, value: string] | undefined {
  const [key, ...rest] = arg.split('=')
  return rest.length === 0 ? undefined : [key, rest.join('=')]
}
```

There is no urge to test this directly — and that absence is the point: the promotion
signal (below) never fires. The rungs in TypeScript: rung 1 is a non-exported
function at module scope beside its only caller (never inside the component body,
where it is re-created every render), covered through the module's exports; rung 2
is the page folder's own module named for its vocabulary
(`pages/Cluster/managementPort.ts`, `pages/Cluster/hooks/`), imported by relative
path; rung 3 is a shared `src/<domain>/` module named for a vocabulary, reached
through the path alias. There is no `internal/` convention — `export` is the wall,
and a barrel `index.ts` that re-exports a module's private names tears it down.
Extract Function (here, a custom hook) climbs the same ladder: beside its only
caller, then the page's `hooks/`, then `src/hooks/` only when two pages share it.
