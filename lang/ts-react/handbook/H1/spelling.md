
> **In TypeScript:** `// eslint-disable-next-line <rule>`, `// eslint-disable-line`,
> the block form `/* eslint-disable <rule> */ … /* eslint-enable */`,
> `@ts-expect-error`, `@ts-ignore`, `@ts-nocheck` and `// prettier-ignore` are the
> same thing. A bare `eslint-disable` names no rule, so read for the rule id; of the
> type suppressions, `@ts-expect-error` is preferred over `@ts-ignore` because it
> fails the build when the error goes away. An override block in `eslint.config.*` or
> a `tsconfig` option is the reviewed place for a true false positive.

**Review:** Did the diff add an `eslint-disable`, `@ts-expect-error`, `@ts-ignore`, `@ts-nocheck` or `prettier-ignore`, or edit `eslint.config.*`, `tsconfig*.json` or `.prettierrc*`?
