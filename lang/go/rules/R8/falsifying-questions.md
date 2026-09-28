1. **Does any package declare mutable state at package level?**
   Detect-grep: `^var ([A-Za-z][A-Za-z0-9_]*\b|\($)`
   Detection: then exclude const-like declarations (`var Err... = errors.New(...)` sentinels,
   compile-time interface checks `var _ I = ...`).
   Violation: a package-level `var` that is written after initialization or holds
   configuration/state — reject it into a constructor-injected field.

2. **Does any `init()` write state?**
   Detect-grep: `^func init\(\)` files=all
   Detection: read each body for
   assignments to package-level variables or registrations with side effects.
   Violation: `init()` mutating package state — replace with an explicit
   constructor called at the edge.

3. **Does library code manufacture its own context?**
   Detect-grep: `context\.(Background|TODO)\(\)` exclude-path=(^|/)cmd/,(^|/)main\.go$
   Violation: any hit outside `main`/wiring — the function must take `ctx` from its
   caller.

4. **Is a singleton reached sideways?**
   Detect-grep: `sync\.Once` files=all
   Detection: check whether the guarded
   instance is a package-level var returned by a getter that business logic calls.
   Violation: `GetX()`-style access from inside logic — construct at the edge, pass
   down.

5. **Does deep code read a global config?**
   Detect-grep: `env\.Configs|os\.(Getenv|LookupEnv)\(` exclude-path=(^|/)cmd/,(^|/)main\.go$,setup
   Violation: config reads outside entry-point wiring — each is a dependency to
   reject upward (`../examples/dependency-rejection.md`).

6. **Do tests mutate globals to run?**
   Detect-grep: `env\.Configs\.[A-Za-z_.]* *=[^=]|\b(os|t)\.Setenv\(` files=test
   Violation: a test writing shared state to inject a value — the production code
   under test has a hidden dependency; fix the production code, not the test.
