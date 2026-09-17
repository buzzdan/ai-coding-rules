**A file-length limit (the linter's, or ~450 lines when it has none):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per file (juiciness per R1) |
| Single god type (>15 methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions (R3) |

<package_decomposition>
**Package-size zones** — count the non-test, non-generated source files in one
directory:

```
find <dir> -maxdepth 1 -type f -name '{{.SrcGlob}}' -not -name '*{{.TestGlob}}' | wc -l
```

≤7 green — fine. 8–12 yellow — design review *before the next file lands*. ≥13 red —
**must decompose**. Either zone: run the 3-step design review in `reference.md` →
"Package decomposition" (it is a *design* review — missing domain types are the
disease, file count the symptom). Invoke @code-designing to validate extracted types.
</package_decomposition>