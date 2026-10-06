- Never add a suppression — `// eslint-disable-next-line`, `// eslint-disable-line`,
  `/* eslint-disable */`, `@ts-expect-error`, `@ts-ignore`, `@ts-nocheck`, `// prettier-ignore` — not even for issues you escalate.
- Never edit `eslint.config.*`, `tsconfig*.json`, `.prettierrc*` or `vitest.config.*` — no new
  `rules` override, `ignores` entry or loosened compiler option.
- Never touch test semantics: you may fix lint inside `*.test.ts`/`*.test.tsx` files,
  but never weaken, remove, or reorder assertions.
