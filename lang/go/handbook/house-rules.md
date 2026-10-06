Rules marked *(opinionated)* are stances, not Go community norms; the departure is
deliberate.

### G1 — Package names are flatcase and do not collide

A package name is one lower-case word from the domain (`wekatrace`, `rotator`). It
never collides with the standard library or a library everyone imports, because
every importer then pays an alias: `metrics` collides, `wekametrics` does not.

**Review:** Does any package name collide with the standard library or a common import?

### G2 — Names read at the call site, not the declaration

The package is part of the name. `version.Info`, not `version.VersionInfo`;
`user.New`, not `user.NewUser`.

**Review:** Does any exported name repeat its package?

### G3 — A godoc example shows the happy path and nothing else (opinionated)

Every exported constructor a consumer calls gets one `Example` function in the
`_test` package: no arguments, no fakes, no branches, an `// Output:` line. A
constructor is any public function that returns the type, so `ParseAddress(s)
(Address, error)` is one. It is compiled documentation; edge cases belong in tests.

```go
func ExampleParsePort() {
    p, _ := networking.ParsePort("weka-api", 14000)
    fmt.Println(p.Number())
    // Output: 14000
}
```

**Review:** Does every exported constructor have an `Example`?

### G4 — Table tests for logic, testify suites for expensive setup (opinionated)

A table is the default, and each case has cyclomatic complexity 1 with named fields.
A `suite.Suite` earns its place only when several tests share costly setup that
`t.TempDir()` and `t.Cleanup` do not cover: a test server, an embedded database. A
suite around plain value tests is ceremony. Assertions follow the codebase: testify
where the project uses it, the standard library where it does not.

**Review:** Is any suite wrapping tests that share no setup?

### G5 — A `defer` body with a branch is a function (opinionated)

`defer func() { if err := f.Close(); err != nil { ... } }()` hides logic in the place
nobody reads. Extract it and name it: `defer closeOrLog(f, log)`.

**Review:** Does any `defer` body branch?

### G6 — Lint runs through the project's task (opinionated)

Projects lint with golangci-lint v2 from `.golangci.yaml` at the root. Run the
project's `task lintwithfix` where it exists (go vet, `golangci-lint fmt`,
`golangci-lint run --fix`), else `golangci-lint run --fix`, and it is green before
every commit, with the v2 configuration reference open before the file is edited.

**Review:** Is the tree lint-green through the project's task, not a bare command?
