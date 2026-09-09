
1. **How many production implementations does each new/changed interface have?**
   Detection: for each method of the interface,
   `grep -rn 'func (.*) <Method>(' --include='*.go' . | grep -v _test.go` — list the
   implementing types.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: `grep -rn 'func (.*) <Method>(' --include='*_test.go' .` plus the same
   grep over test-support packages (`fakes/`, `mocks/`, `testutil*`).
   Violation: yes — one production implementation + a double = test-only interface;
   delete it and test the real type.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction:
   ```bash
   # a real cycle exists only if the dependency package imports the consumer back:
   grep -rn '"<module>/<consumer-pkg>"' <dependency-pkg-dir>/*.go   # no match ⇒ no cycle ⇒ interface unjustified
   ```
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: `grep -rn 'New<Consumer>(' --include='*.go' . | grep -v _test.go` —
   inspect the argument's type at each production call site.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: `grep -rn -B2 'interface {' <changed files> | grep -iE 'for test|import cycle|mock'`
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
