- [ ] Every JSDoc fits its tier budget — helper 0–1 / contract 2–3 /
      crossroads ≤5 prose lines (R9's tiered comment policy); a `@param`,
      `@returns` or `@throws` tag that adds what the signature cannot is the
      contract's shape and is free, one that restates a type is deleted; overflow
      moved to the feature doc, the package's `index.ts` block (~20–30 lines) used
      for package docs that earn it
- [ ] Menu sections included only where they earn their place for that symbol,
      within the tier budget
- [ ] Crossroads that deserve a richer inline JSDoc got an expand
      recommendation in the report — never extra lines beyond budget
- [ ] `See docs/<feature>.md` edge present wherever a feature doc exists — on its
      own trailing line (the last line of the JSDoc block, or a `// See` line
      directly under it), never woven into the summary line
- [ ] Runnable examples: at least one `@example` per complex/core type; kept honest
      by the colocated `*.test.ts`/`*.test.tsx` that runs the same lines; happy path
      only; the result on a `// =>` comment at the end of the line
