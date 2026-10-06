Package Structure:
pages/Snapshots/
  ├── index.ts               # the public surface: what another page imports
  ├── SnapshotsPage.tsx      # the component: its render tree is the story
  ├── useSnapshots.ts        # the hook: the query and state the page reads
  ├── snapshotsApi.ts        # the api module: fetch and parse at the boundary
  ├── snapshot.ts            # each juicy type in its own module (Snapshot, parseSnapshot)
  └── SnapshotsPage.test.tsx
