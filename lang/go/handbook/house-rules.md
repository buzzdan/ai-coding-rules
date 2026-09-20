### G1 — Package names are flatcase vocabulary that does not collide

A package name is one lower-case word from the domain (`wekatrace`, `rotator`). It
never names a layer or a bucket (`utils`, `common`, `domain`, `models`) and never
collides with the standard library or a library everyone imports, because every
importer then pays an alias: `metrics` collides, `wekametrics` does not.

**Review:** Does any package name a layer, a bucket, or collide with a common import?

### G2 — Names read at the call site, not the declaration

The package is part of the name. `version.Info`, not `version.VersionInfo`;
`user.New`, not `user.NewUser`. A constructor is any public function that returns
the type, so `ParseAddress(s) (Address, error)` is one.

**Review:** Does any exported name repeat its package?

### G3 — A godoc example shows the happy path and nothing else

Every exported type a consumer constructs gets one `Example` function in the
`_test` package: no arguments, no fakes, no branches, an `// Output:` line. It is
compiled documentation; complex cases belong in tests.

```go
func ExampleParsePort() {
    p, _ := networking.ParsePort("weka-api", 14000)
    fmt.Println(p.Number())
    // Output: 14000
}
```

**Review:** Does every exported type a consumer constructs have an `Example`?

### G4 — Table tests for logic, testify suites for expensive setup

A table is the default, and each case has cyclomatic complexity 1 with named fields.
A `suite.Suite` earns its place only when several tests share costly setup: a test
server, an embedded database, a temp directory with teardown. A suite around plain
value tests is ceremony. Assertions follow the codebase: testify where the project
uses it, the standard library where it does not.

**Review:** Is any suite wrapping tests that share no setup?

### G5 — A `defer` body with a branch is a function

`defer func() { if err := f.Close(); err != nil { ... } }()` hides logic in the place
nobody reads. Extract it, name it, test it.

**Review:** Does any `defer` body branch?

### G6 — Lint is the contract; `nolint` is a request, not a tool

Every project lints with golangci-lint v2 from `.golangci.yaml` at the root, and
`task lintwithfix` (go vet, `golangci-lint fmt`, `golangci-lint run --fix`) is green
before every commit. A `//nolint` is never added on your own: fix the code, and if it
is a true false positive, propose an `exclusions` entry in `.golangci.yaml` and get it
reviewed. Read the v2 configuration reference before touching the file.

**Review:** Did the diff add a `//nolint` or edit `.golangci.yaml`?

### G7 — Errors carry the context of the layer that saw them

Wrap at each boundary with `fmt.Errorf("parse port %q: %w", name, err)`; never log
*and* return the same error; inspect only with `errors.Is` and `errors.As`. A
sentinel `var ErrX = errors.New(...)` is exported only when a caller decides on it.

**Review:** Is any error both logged and returned, or inspected by string?
