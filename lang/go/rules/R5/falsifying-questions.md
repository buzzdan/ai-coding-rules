1. **Is any package named after a layer or role?**
   Detection: `grep -rn 'package \(util\|utils\|helpers\|common\|shared\|misc\|domain\|services\|handlers\|models\)$' --include='*.go' .`
   and `find . -type d \( -name 'util*' -o -name 'helpers' -o -name 'common' -o -name 'domain' -o -name 'services' -o -name 'handlers' -o -name 'models' -o -name 'repositories' \)`
   Violation: any hit — the package describes a role, not a domain.

2. **Is one feature's code spread across ≥2 layer directories?**
   Detection: for each feature noun in the diff,
   `grep -rln '<feature>' --include='*.go' . | xargs -n1 dirname | sort -u` — count
   distinct layer-named directories.
   Violation: the same feature living in `handlers/` and `services/` (etc.) — it is
   horizontally scattered.

3. **Does the diff add a new file into a layer directory instead of a slice?**
   Detection: `git diff --name-only --diff-filter=A -- '*.go'` — check each new
   path's directory against the layer names above.
   Violation: new feature code placed in a layer directory — new code is always
   sliced, even mid-migration.

4. **Do both shapes coexist for one feature?**
   Detection: `ls <feature>/ services/ handlers/ 2>/dev/null | grep -i <feature>`
   Violation: `<feature>/service.go` alongside `services/<feature>_service.go` —
   the never-mix rule; finish the feature's migration in this change or don't start
   it.

5. **Is a mixed-architecture repo missing its migration plan?**
   Detection: layer directories exist alongside slices, and
   `ls docs/architecture/vertical-slice-migration.md` fails.
   Violation: mixed state with no documented strategy/progress — add the template
   above.
