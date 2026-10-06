```text
❌ by layer                          ✅ by feature, roles inside
src/models/rotator{{.SrcExt}}             src/rotator/rotator{{.SrcExt}}        # domain type
src/services/rotator{{.SrcExt}}           src/rotator/parser{{.SrcExt}}         # role: parsing
src/repositories/rotator{{.SrcExt}}       src/rotator/handler{{.SrcExt}}        # role: HTTP
src/handlers/rotator{{.SrcExt}}           src/rotator/repository{{.SrcExt}}     # role: persistence
```

> **Spelling:** the directory is a package, module, crate or namespace, whatever the
> language calls one unit of code with its own public surface. Its name is the
> feature noun, `rotator`, never `services` or `models`; `utils`, `common` and
> `helpers` name no vocabulary at all, so the first function that lands there has no
> owner and the next lands beside it. Role names live in the file names inside the
> slice, and a type with logic gets its own file named after the type.
