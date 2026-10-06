1. **Is a symbol exported only so tests can reach it?**
   Detect: judgment
   Detection: for each newly `export`ed function, hook or type
   (`grep -rn "export " <file>` lists the candidates),
   `grep -rln "import .*\b<Symbol>\b.* from '" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   — count non-test importers outside its defining module.
   Violation: zero production importers while `*.test.ts`/`*.test.tsx` files import
   it — it was exported for tests; demote (rung 1) or promote (rung 2/3).
   `export function parseRetention` whose only importer is `parseRetention.test.ts`
   is the shape.

2. **Are module-private helpers tested directly?**
   Detect-grep: `__test|for test|@internal|^export \{|vi\.spyOn\(` files=all
   Detection: a non-exported name cannot be imported, so the reach leaves a trace:
   a re-export or a `__testing` bag added at the bottom of the module, a barrel
   `index.ts` that re-exports what the module kept private, and a `vi.spyOn` in a
   test on a module's internals through its namespace import — read what each
   `export {` block and each spy names.
   Violation: any direct test of a private helper — that urge is the promotion
   signal; give the helper its own module instead. The re-export is a convention
   the test runs through, and that is why the question is asked.

3. **Does a new shared module have a role name?**
   Detect-path: `(^|/)(util[^/]*|helpers|helper|common|shared|misc|lib)/|(^|/)(utils|helpers|common|constants)\.tsx?$`
   Detection: any scope path under a role-named directory, or a module of that
   name; a barrel `hooks/index.ts` that collects every hook is the same dumping
   ground with an `index` and is read by hand.
   Violation: any hit — `utils/strings.ts`, `utils/time.ts` and `common/constants.ts`
   are the TypeScript spelling of the role-named package; modules are named for a
   domain vocabulary, never a role.

4. **Is a new shared module a single noun rather than a vocabulary?**
   Detect: judgment
   Detection: `grep -cE '^export (interface|type|class|function|const) ' src/<name>/*.ts`
   and ask whether plausible domain siblings exist under the name.
   Violation: a module named after its one type (`src/kubeport/`) with no room for
   siblings — fold into a vocabulary module (`src/networking/`) or keep at rung 1/2.

5. **Did feature policy leak into a shared module?**
   Detect: judgment
   Detection: grep the shared module for feature-owned literals and constants, e.g.
   `grep -rn "'weka-" <shared module>/`; a feature literal in a shared constants
   module (`common/constants.ts` holding `SNAPSHOTS_PAGE_SIZE`) is the same leak.
   Violation: any feature-specific literal or preference decision inside a
   domain-generic module — policy stays in the feature (Stage 2 of
   `R1-primitive-obsession.md`).

6. **Does a changed function envy another type's data?**
   Detect: judgment
   Detection: for each changed function or component, count property accesses per
   value: `grep -oE '\b<param>\.[a-zA-Z_]+' <function body> | sort | uniq -c` for its
   most-touched parameter or prop versus the same count for its own data (its
   state, its module's types). A parameter that is a `Record`, an array or a `Map`
   is accessed by `[`, `.get(`, `in`, `.length` and `for … of` rather than by
   property; count those the same way. A component reaching into another page's
   data shape — `pages/Alerts/AlertRow.tsx` walking
   `device.network.interfaces[0].addresses` from the Devices page's type — is the
   React form.
   Violation: accesses on one foreign value outnumber accesses on the function's
   own data and the foreign type is yours to extend — Move Method to the Envied
   Type (a function beside that type, or a selector on its hook), then re-place via
   the ladder. A component that merely *reads* a DTO once to render it at the
   boundary is not envy.
