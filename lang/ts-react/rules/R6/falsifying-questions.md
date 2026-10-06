1. **How many production implementations does each new/changed interface have?**
   Detect-grep: `^(export )?(interface|abstract class) [A-Z][A-Za-z]*`
   Detection: the pattern lists the interfaces and abstract classes; a `Props`
   interface describes data, not a collaborator, so keep the hits whose members are
   functions. For each,
   `grep -rn 'implements <Interface>\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   plus `grep -rnE ': <Interface> = \{|satisfies <Interface>\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   for object literals typed by it. An interface is structural, so an implementer
   need not name it; where none does, the method-name census
   (`grep -rnE '^\s+(async )?<method>\(' --include='*.ts' --exclude-dir=node_modules .`)
   is the only census — read it, then verify it.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detect-grep: `vi\.mock\(|vi\.fn\(|jest\.mock\(|jest\.fn\(` files=test
   Detection: the same greps as Q1 over `*.test.ts`/`*.test.tsx`,
   `src/test-utils/mocks/*Mock.ts` and `__mocks__/` directories; the detect line
   finds every mock and fake function in the test files — keep the `vi.mock` hits
   on relative and alias imports (`'./`, `'../`, `'@/`) and the `vi.fn()` objects
   shaped like a service, and read what each targets: a `vi.mock` of an internal
   hook or service is a seam that exists only so the test can substitute a double,
   the same smell without the interface.
   Violation: yes — one production implementation + a double (a `Mock*` class, a
   `vi.fn()` object, a `vi.mock` of the collaborator) = test-only seam; delete the
   interface, test the real hook over MSW, and give the collaborator a real
   in-memory implementation only if production also needs one. Mocking the true
   external boundary — `fetch` through MSW, the router, the auth SDK, the clock
   (`vi.useFakeTimers`), `matchMedia` — is not this finding.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detect: judgment
   Detection — do not trust a "cycle" comment; check the import direction:
   ```bash
   # a real cycle exists only if the dependency module imports the consumer back:
   grep -rnE "from '(\.|@/).*<consumer module>'" <dependency dir>/*.ts   # no match ⇒ no cycle ⇒ interface unjustified
   ```
   `import/no-cycle` reports the real ones where the repository configures it. An
   `import type` is erased and is never a run-time cycle, so an interface justified
   by "the import would cycle" is not justified when the concrete type could be
   imported with `import type` for the annotation.
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detect: judgment
   Detection: `grep -rnE 'new <Consumer>\(|\b<Consumer>\(|<<Context>\.Provider value=' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   — inspect the argument's type at each production call site. A hook or function
   whose trailing parameter is the interface and whose only non-default argument
   comes from a test (`useDevices(id, repo = apiRepository)`) is the same shape, and
   so is a factory returning the interface type (`createDeviceRepository():
   DeviceRepository`) with one body behind it.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detect-grep: `(//|\*).*\b([Ff]or test(ing)?|[Ii]mport cycle|[Mm]ock|[Ss]wap)|so (that )?tests can`
   Detection: read the lines below each hit for the `interface` or `abstract class`
   it justifies; `find src -type d -name '__mocks__' -not -path '*/node_modules/*'`
   lists the directories that say the same thing without a comment.
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
