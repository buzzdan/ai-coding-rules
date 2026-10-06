1. Package-scoped lint (fast): `npx eslint <dir>` plus `npx tsc --noEmit -p tsconfig.json`
   (project-wide — TypeScript has no per-directory type check; `tsc -b` where the
   repository uses project references), then `npx vitest run <dir>`
