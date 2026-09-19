1. **How many production implementations does each new/changed interface have?**
   Detection: for each `Protocol` or `ABC` in the diff, list its method names, then
   `grep -rnE '^\s+def <method>\(' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'`
   — the implementing classes. A Protocol is structural, so an implementer never
   names it; the method-name census is the only census. A `type[Protocol]`
   assignment or an `if TYPE_CHECKING:` tuple of implementers is a declared census
   — read it, then verify it.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: `grep -rnE '^\s+def <method>\(' --include='test_*.py' --include='*_test.py' --include='conftest.py' .`
   plus the same grep over test-support packages (`fakes/`, `mocks/`, `testing/`);
   then `grep -rnE 'mock\.patch|patch\(|monkeypatch\.setattr|MagicMock|create_autospec' --include='test_*.py' --include='*_test.py' .`
   and read what each patch targets — a patch on a concrete collaborator is a seam
   that exists only so the test can substitute a double, the same smell without the
   Protocol.
   Violation: yes — one production implementation + a double (a fake class, a
   `MagicMock`, a `patch` of the collaborator) = test-only seam; delete the
   Protocol, test the real type, and give the collaborator a real in-memory
   implementation if the test needs one. Patching the true external boundary (a
   socket, the wall clock, `os.environ` in an entry-point test) is not this finding.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction:
   ```bash
   # a real cycle exists only if the dependency module imports the consumer back:
   grep -rnE '^(from|import) .*<consumer module>' <dependency dir>/*.py   # no match ⇒ no cycle ⇒ interface unjustified
   ```
   An import under `if TYPE_CHECKING:` is not a run-time cycle: it exists for the
   annotation only, so a Protocol justified by "the import would cycle" is not
   justified when the concrete type could be imported the same way.
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: `grep -rn '<Consumer>(' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` —
   inspect the argument's type at each production call site.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: `grep -rn -B3 -E 'class \w+\((Protocol|ABC)\)' <changed files> | grep -iE 'for test|import cycle|mock|patch'`
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
