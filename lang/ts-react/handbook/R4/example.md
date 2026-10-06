```typescript
// ❌ exported from the page module only so the test can import it
import { parseK3sArgument } from './ClusterPage'

// ✅ rung 1: one caller, no vocabulary of its own; non-exported, at module scope,
//    covered through the module's exports
function parseK3sArgument(arg: string): readonly [key: string, value: string] | undefined {
  const [key, ...rest] = arg.split('=')
  return rest.length === 0 ? undefined : [key, rest.join('=')]
}

// ✅ rung 2: the page folder's own module, named for its vocabulary, by relative path
import { managementPort } from './managementPort'
import { useClusterHealth } from './hooks/useClusterHealth'

// ✅ rung 3: networking vocabulary with several callers → a shared module,
//    named for the domain, through the path alias
import { parsePort, Ports } from '@/networking/ports'
```

> **In TypeScript:** `export` is the wall: a non-exported function cannot be
> imported, so the urge to test it shows up as an `export` added for the test or a
> barrel `index.ts` that re-exports a private name. The urge is a placement signal,
> and the helper wants its own module with a public name. Rung 1 is beside its only
> caller at module scope, never inside the component body, where it is re-created
> every render; rung 2 is the page folder's own module or its `hooks/`; rung 3 a
> shared `src/<domain>/` module. There is no `internal/`. Extract Custom Hook climbs
> the same ladder: beside its only caller, then the page's `hooks/`, then
> `src/hooks/` only when two pages share it.
