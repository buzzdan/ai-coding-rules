Build each search over the language's source files (`{{.SrcGlob}}`), excluding test
files; "entry point" means the main function, application wiring and handler setup.

1. **Does any package declare mutable state at package level?**
   Detection: search the non-test source files for module-level or package-level
   variable declarations (a `var` at column 0, an assignment at module top level, a
   static mutable field) — then exclude const-like declarations (error sentinels,
   frozen constants, compile-time interface checks).
   Violation: a package-level variable that is written after initialization or holds
   configuration/state — reject it into a constructor-injected field.

2. **Does any import-time initializer write state?**
   Detection: search for the language's load-time hooks (an `init` function, a
   module body that runs code on import, a static initializer block) — read each for
   assignments to package-level variables or registrations with side effects.
   Violation: import-time code mutating package state — replace with an explicit
   constructor called at the edge.

3. **Does library code manufacture its own cancellation root?**
   Detection: search the non-test source files outside the entry points for the
   language's root-context or fresh-event-loop constructors (a background context, a
   new event loop, a cancellation source created deep in a call chain).
   Violation: any hit outside the entry points — the function must take the
   cancellation signal from its caller.

4. **Is a singleton reached sideways?**
   Detection: search for the language's once-only initialization idiom (a once
   guard, a lazily created module-level instance, a memoized getter) — check whether
   the guarded instance is a package-level variable returned by a getter that
   business logic calls.
   Violation: `getX()`-style access from inside logic — construct at the edge, pass
   down.

5. **Does deep code read a global config?**
   Detection: search the non-test source files outside the entry points for reads of
   the configuration object and of environment variables (`env.Configs`,
   `os.Getenv`, `os.environ`, `process.env`).
   Violation: config reads outside entry-point wiring — each is a dependency to
   reject upward.

6. **Do tests mutate globals to run?**
   Detection: search the test files for assignments to the configuration object or
   to package-level variables (`env.Configs.X =`, a monkeypatch of a module
   attribute).
   Violation: a test writing shared state to inject a value — the production code
   under test has a hidden dependency; fix the production code, not the test.
