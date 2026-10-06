mechanical issues you fix —
formatting (Prettier), import ordering and duplicates (`simple-import-sort/*`,
`import/order`, `import/no-duplicates`), unused imports/variables (`unused-imports/*`,
`@typescript-eslint/no-unused-vars`), type-only imports
(`@typescript-eslint/consistent-type-imports`), `curly`, `prefer-const`, `eqeqeq`,
`no-plusplus`, `arrow-body-style`, `no-console`, `jsx-a11y/*` markup fixes (the `alt`,
the `htmlFor`, the role), `react/jsx-no-leaked-render` (wrap the `&&` render in a
boolean), magic values (`no-magic-numbers` — mechanical ONLY when the value is not an
enum-shaped domain concept; enum-shaped hits like `=== 'READY'` status strings
escalate, see the table), `@typescript-eslint/no-floating-promises` fixed with `await`
— or `void` only when the promise is genuinely fire-and-forget at an entry point;
anything else escalates to R10, never a suppression.
