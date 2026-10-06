**`sonarjs/max-lines` (600; or a module over ~450 lines where the repository sets no limit — count):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per module (juiciness per R1) |
| Single god component or class (>15 handlers/methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions and hooks (R3) |
| Several components in one file (`react/no-multi-comp`) | One component per file; the page folder decides where the second lands (R4, R5) |

<package_decomposition>
**Package-size zones** — count non-test `.ts`/`.tsx` modules per directory:

```
find <dir> -maxdepth 1 -type f \( -name '*.ts' -o -name '*.tsx' \) -not -name '*.test.*' -not -name '*.d.ts' -not -name 'index.ts' | wc -l
```

≤7 green — fine. 8–12 yellow — design review *before the next file lands*. ≥13 red —
**must decompose**. Either zone: run the 3-step design review under "Package
decomposition", printed with this range (it is a *design* review — missing domain types are the
disease, file count the symptom). Invoke @code-designing to validate extracted types.
</package_decomposition>
