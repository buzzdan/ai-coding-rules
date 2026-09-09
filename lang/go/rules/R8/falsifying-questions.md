
1. **Does any package declare mutable state at package level?**
   Detection: `grep -rn '^var ' --include='*.go' . | grep -v _test.go` — then
   exclude const-like declarations (`var Err... = errors.New(...)` sentinels,
   compile-time interface checks `var _ I = ...`).
   Violation: a package-level `var` that is written after initialization or holds
   configuration/state — reject it into a constructor-injected field.

2. **Does any `init()` write state?**
   Detection: `grep -rn 'func init()' --include='*.go' .` — read each body for
   assignments to package-level variables or registrations with side effects.
   Violation: `init()` mutating package state — replace with an explicit
   constructor called at the edge.

3. **Does library code manufacture its own context?**
   Detection: `grep -rn 'context.Background()\|context.TODO()' --include='*.go' . | grep -v _test.go | grep -v 'cmd/\|main.go'`
   Violation: any hit outside `main`/wiring — the function must take `ctx` from its
   caller.

4. **Is a singleton reached sideways?**
   Detection: `grep -rn 'sync.Once' --include='*.go' .` — check whether the guarded
   instance is a package-level var returned by a getter that business logic calls.
   Violation: `GetX()`-style access from inside logic — construct at the edge, pass
   down.

5. **Does deep code read a global config?**
   Detection: `grep -rn 'env\.Configs\|os.Getenv' --include='*.go' . | grep -v _test.go | grep -v 'cmd/\|main.go\|setup'`
   Violation: config reads outside entry-point wiring — each is a dependency to
   reject upward (`../examples/dependency-rejection.md`).

6. **Do tests mutate globals to run?**
   Detection: `grep -rn 'env.Configs.* =' --include='*_test.go' .`
   Violation: a test writing shared state to inject a value — the production code
   under test has a hidden dependency; fix the production code, not the test.
