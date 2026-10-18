**A file over the file-length limit** — the repository linter's limit where it sets one, else {{.FileMaxLines}} code lines; `bash <this skill dir>/../../scripts/ldd-lint.sh file-length --root .` lists them and names the limit it applied:

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per file (juiciness per R1) |
| Single god type (>15 methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions (R3) |

<package_decomposition>
**Package-size zones** — source files per directory:

```
bash <this skill dir>/../../scripts/ldd-lint.sh package-size --root .
```

The gap linter counts the non-test, non-generated source files of each directory;
a `.ldd-lint.yaml` at the repository root sets other sizes, and the first line of
its output says which sizes applied.

Below {{.PackageWarnFiles}} files green — fine. {{.PackageWarnFiles}} or more yellow — design review
*before the next file lands*. {{.PackageMaxFiles}} or more red — **must decompose**. Either
zone: run the 3-step design review under "Package decomposition", printed with this
range (it is a *design* review — missing domain types are the
disease, file count the symptom). Invoke @code-designing to validate extracted types.
</package_decomposition>