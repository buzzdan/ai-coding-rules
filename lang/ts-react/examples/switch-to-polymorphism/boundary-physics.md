- Physically: a method on a type from the shared client module
  (`src/services/exportsApi.ts`, imported by three pages) cannot take one page's
  private `UpdateExportRequest` without that module importing from `src/pages/` — an
  import cycle at best, and in any case the shared client depending on its consumer,
  which inverts the dependency.
- Architecturally: with multiple consumers (the exports page, cluster settings, the
  onboarding wizard), per-consumer `fill<X>Request` methods accrete every page's
  serialization onto the shared types — interface pollution from the opposite direction.
