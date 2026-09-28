1. **Is any package or module named after a layer or role?**
   Detect-path: `(^|/)(util[^/]*|helpers|common|shared|misc|domain|services|handlers|models|repositories)/`
   Detection: any scope path under a layer- or role-named directory; a Go package is
   named after its directory, so the `package` line says the same.
   Violation: any hit — the package describes a role, not a domain.

2. **Is one feature's code spread across ≥2 layer directories?**
   Detect: judgment
   Detection: for each feature noun in the diff,
   `grep -rln '<feature>' --include='*.go' . | xargs -n1 dirname | sort -u` — count
   distinct layer-named directories.
   Violation: the same feature living in `handlers/` and `services/` (etc.) — it is
   horizontally scattered.

3. **Does the diff add a new file into a layer directory instead of a slice?**
   Detect: judgment
   Detection: the diff's added files (`new file mode` in the patch) — check each new
   path's directory against the layer names above.
   Violation: new feature code placed in a layer directory — new code is always
   sliced, even mid-migration.

4. **Do both shapes coexist for one feature?**
   Detect: judgment
   Detection: `ls <feature>/ services/ handlers/ 2>/dev/null | grep -i <feature>`
   Violation: `<feature>/service.go` alongside `services/<feature>_service.go` —
   the never-mix rule; finish the feature's migration in this change or don't start
   it.

5. **Is a mixed-architecture repo missing its migration plan?**
   Detect: judgment
   Detection: layer directories exist alongside slices, and
   `ls docs/architecture/vertical-slice-migration.md` fails.
   Violation: mixed state with no documented strategy/progress — add the template
   above.
