### Before — feature scattered across layers

```
src/
├── components/
│   └── SnapshotsTable.tsx
├── hooks/
│   └── useSnapshots.ts
├── services/
│   └── snapshotsApi.ts
├── types/
│   └── snapshot.ts
└── pages/
    └── SnapshotsPage.tsx
```

Changing the snapshots feature touches five directories; the `hooks/` and `services/`
surfaces are the union of every page's hooks and services; `components`, `hooks`,
`services` and `types` are role names that describe no domain at all.

### After — one slice, roles inside

```
src/pages/Snapshots/
├── SnapshotsPage.tsx          # the route's component: the story
├── SnapshotsTable.tsx         # role: presentation
├── useSnapshots.ts            # role: server state (the query hook)
├── snapshotsApi.ts            # role: HTTP, over apiClient
├── snapshot.ts                # domain type + parseSnapshot
├── SnapshotsPage.module.scss  # role: styles
└── SnapshotsPage.test.tsx     # MSW handlers answer the real fetch
```

The whole feature is one `ls`. Each type with logic sits in its own module named
after the type; the folder name is the feature's domain word, and file names carry
the roles. The router imports `SnapshotsPage` and nothing else from the folder, so
the module split inside it is private to it. Top-level `components/`, `hooks/`,
`services/` and `types/` hold only what two pages share — `apiClient`, the
`renderWithProviders` helper, the `Device` type both the Devices and the Alerts page
read.
