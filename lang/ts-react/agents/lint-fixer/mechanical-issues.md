mechanical issues you fix —
formatting (Prettier), import ordering and duplicates (`simple-import-sort/*`,
`import/order`, `import/no-duplicates`), unused imports/variables
(`unused-imports/no-unused-imports`, `unused-imports/no-unused-vars`,
`@typescript-eslint/no-unused-vars`), type-only imports
(`@typescript-eslint/consistent-type-imports`), `curly`, `prefer-const`, `eqeqeq`,
`no-plusplus`, `arrow-body-style`, `no-console`, the `jsx-a11y` families
`click-events-have-key-events`, `no-static-element-interactions`,
`interactive-supports-focus`, `label-has-associated-control`, `aria-props`,
`aria-proptypes`, `role-has-required-aria-props`, `alt-text`, `img-redundant-alt`
when the fix is one attribute or a `button` for a `div onClick` (when the honest fix
is `role` + `tabIndex` + `onKeyDown` on a non-interactive element, escalate: that is a
design question for the component), `react/jsx-no-leaked-render` (wrap the `&&`
render in a boolean), `react/no-array-index-key` when the item has an id
(`key={item.id}`; when nothing in the item identifies it, escalate to R1 — the list
element has no identity, which is a missing type, not a key problem),
`react/forbid-dom-props` / `react/forbid-component-props` on an inline `style` (the
SCSS module class), magic values (`no-magic-numbers` — mechanical ONLY when the value is not an
enum-shaped domain concept; enum-shaped hits like `=== 'READY'` status strings
escalate, see the table), `@typescript-eslint/no-floating-promises` fixed with `await`
— or `void` only when the promise is genuinely fire-and-forget at an entry point;
anything else escalates to R10, never a suppression.
