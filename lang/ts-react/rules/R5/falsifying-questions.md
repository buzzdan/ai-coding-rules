1. **Is any directory named after a layer or role?**
   Detect-path: `(^|/)(util[^/]*|helpers|common|shared|misc|lib|models|store|repositories)/|(^|/)src/(components|hooks|services|types)/`
   Detection: any scope path under a role-named directory (the first form) or
   under a top-level layer directory (the second). A top-level layer may hold what
   two pages share, so for the second form count importers per file —
   `grep -rln "from '.*<module>'" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules src | wc -l`
   — and the hit is the file with one importer.
   Violation: any hit in the first form, and any single-importer file in the second
   — the directory describes a role, not a domain.

2. **Is one feature's code spread across ≥2 layer directories?**
   Detect: judgment
   Detection: for each feature noun in the diff,
   `grep -rli '<feature>' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules src | xargs -n1 dirname | sort -u`
   — count distinct layer-named directories. The inverse shape is the god file:
   `sonarjs/max-lines` (600) on a `Performance.tsx` of 1,199 lines holding the page,
   its hooks, its API calls and its types in one module.
   Violation: the same feature living in `components/`, `hooks/`, `services/` and
   `types/` — four top-level directories for one page — it is horizontally
   scattered; or one file standing in for the whole slice — split it by role inside
   the page folder.

3. **Does the diff add a new file into a layer directory instead of a slice?**
   Detect: judgment
   Detection: the diff's added files (`new file mode` in the patch) — check each
   new path's directory against the layer names above. A new `src/types/<feature>.ts`
   is the models red zone: a type one page reads belongs beside that page's parser.
   Violation: new feature code placed in a layer directory — new code is always
   sliced, even mid-migration.

4. **Do both shapes coexist for one feature?**
   Detect: judgment
   Detection: `ls src/pages/<Feature>/ src/hooks/ src/services/ 2>/dev/null | grep -i <feature>`
   Violation: `pages/Snapshots/useSnapshots.ts` alongside `hooks/useSnapshots.ts`,
   or `pages/X/` with `services/xApi.ts` plus `hooks/useX.ts` still in place — the
   never-mix rule; finish the feature's migration in this change or don't start it.

5. **Is a mixed-architecture repo missing its migration plan?**
   Detect: judgment
   Detection: layer directories exist alongside page folders, and
   `ls docs/architecture/vertical-slice-migration.md` fails; the `README.md` and
   `CLAUDE.md` say nothing about which shape new code takes.
   Violation: mixed state with no documented strategy/progress — add the template
   above.
