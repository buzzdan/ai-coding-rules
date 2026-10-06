then confirm the module
   still type-checks (`npx tsc --noEmit`) and the edge is found by
   `grep -rn "See docs/" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules`
   — the edge is a `// See docs/<feature>.md` line directly above the front-door
   export, under its JSDoc block, so the only way to break it is to land it inside a
   string or JSX text. TypeScript files only — the gate verifies edges in `.ts` and
   `.tsx` files alone, so an edge in another language is unverifiable; report such
   docs as unwired instead of improvising.
