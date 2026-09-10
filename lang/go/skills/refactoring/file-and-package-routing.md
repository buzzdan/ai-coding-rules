**`file-length-limit` (>450 lines):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per file (juiciness per R1) |
| Single god type (>15 methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions (R3) |

<package_decomposition>
**Package-size zones** — count non-test `.go` files per directory:

```
find <dir> -maxdepth 1 -type f -name '*.go' -not -name '*_test.go' -not -name '*_gen.go' -not -name '*.pb.go' | wc -l
```

≤7 green — fine. 8–12 yellow — design review *before the next file lands*. ≥13 red —
**must decompose**. Either zone: run the 3-step design review in `reference.md` →
"Package decomposition" (it is a *design* review — missing domain types are the
disease, file count the symptom). Invoke @code-designing to validate extracted types.
</package_decomposition>
