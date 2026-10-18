**`sonarjs/max-lines`, or a module over {{.FileMaxLines}} code lines where the repository sets no limit** — `bash <this skill dir>/../../scripts/ldd-lint.sh file-length --root .` lists them and names the limit it applied:

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per module (juiciness per R1) |
| Single god component or class (>15 handlers/methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions and hooks (R3) |
| Several components in one file (`react/no-multi-comp`) | One component per file; the page folder decides where the second lands (R4, R5) |

<package_decomposition>
**Package-size zones** — non-test `.ts`/`.tsx` modules per directory, `index.ts`, declaration files and stories left out:

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
