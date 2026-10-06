```text
❌ by layer                          ✅ by feature, roles inside
src/components/SnapshotsTable.tsx    src/pages/Snapshots/SnapshotsPage.tsx       # the route's component: the story
src/hooks/useSnapshots.ts            src/pages/Snapshots/SnapshotsTable.tsx      # role: presentation
src/services/snapshotsApi.ts         src/pages/Snapshots/useSnapshots.ts         # role: server state (the query hook)
src/types/snapshot.ts                src/pages/Snapshots/snapshotsApi.ts         # role: HTTP, over apiClient
src/pages/SnapshotsPage.tsx          src/pages/Snapshots/snapshot.ts             # domain type + parseSnapshot
                                     src/pages/Snapshots/SnapshotsPage.test.tsx  # MSW handlers answer the real fetch
```

> **In TypeScript:** the folder name is the feature noun, `Snapshots`, never
> `services` or `hooks`. `utils/`, `common/` and `helpers/` name no vocabulary at all:
> the first function that lands there has no owner, and the next lands beside it
> because the first did. Role names (`snapshotsApi.ts`, `useSnapshots.ts`) live in
> the file names inside the slice. Each type with logic sits in its own module named
> after the type. The router imports `SnapshotsPage` and nothing else from the folder,
> so the module split inside it is private to it; top-level `components/`, `hooks/`,
> `services/` and `types/` hold only what two pages share.
