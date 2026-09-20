1. **Is any package or module named after a layer or role?**
   Detection: list the directories that hold source files and match their names
   against `util`, `utils`, `helpers`, `common`, `shared`, `misc`, `domain`,
   `services`, `handlers`, `models`, `repositories`; where the language declares the
   package name inside the file, search the declarations for the same words.
   Violation: any hit — the package describes a role, not a domain.

2. **Is one feature's code spread across ≥2 layer directories?**
   Detection: for each feature noun in the diff, list the directories of the source
   files that mention it and count the distinct layer-named directories among them.
   Violation: the same feature living in `handlers/` and `services/` (etc.) — it is
   horizontally scattered.

3. **Does the diff add a new file into a layer directory instead of a slice?**
   Detection: list the files the diff adds (`git diff --name-only --diff-filter=A`)
   and check each new path's directory against the layer names above.
   Violation: new feature code placed in a layer directory — new code is always
   sliced, even mid-migration.

4. **Do both shapes coexist for one feature?**
   Detection: list `<feature>/`, `services/` and `handlers/` and look for the
   feature's name in more than one of them.
   Violation: `<feature>/service{{.SrcExt}}` alongside
   `services/<feature>_service{{.SrcExt}}` — the never-mix rule; finish the feature's
   migration in this change or don't start it.

5. **Is a mixed-architecture repo missing its migration plan?**
   Detection: layer directories exist alongside slices, and
   `docs/architecture/vertical-slice-migration.md` does not.
   Violation: mixed state with no documented strategy/progress — add the template
   above.
