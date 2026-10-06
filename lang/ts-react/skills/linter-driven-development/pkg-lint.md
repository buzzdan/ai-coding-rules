1. Package-scoped lint (fast): `npx eslint <dir>` plus `npx tsc --noEmit` (project-wide;
   `tsc -b` where the repository uses project references), then `npx vitest run <dir>`
