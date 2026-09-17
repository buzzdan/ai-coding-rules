Build each search over the language's source files (`{{.SrcGlob}}`); test files are
the ones the repository's test runner picks up.

1. **How many production implementations does each new/changed interface have?**
   Detection: for each method of the interface (protocol, abstract base class, trait),
   search the non-test source files for definitions of that method name — list the
   implementing types.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: search the test files for definitions of the same method names, plus
   the same search over test-support directories (`fakes/`, `mocks/`, `testutil*`,
   `conftest`); in a patching language, search the test files for a patch or
   monkeypatch that targets the collaborator.
   Violation: yes — one production implementation + a double = test-only seam;
   delete it and test the real type.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction: a real
   cycle exists only if the dependency's package imports the consumer's package
   back. Search the dependency's source files for an import of the consumer.
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: search the non-test source files for calls to the consumer's
   constructor — inspect the argument's type at each production call site.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: in the changed files, read the comment lines above each new interface,
   protocol or abstract class for `for test`, `import cycle`, `mock`.
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
