---
type: llm
criteria: cmd/svc/main.go is the only reader of configuration and reads as load → construct leaves → construct orchestrators → serve, with no business logic (R3 altitude at the composition root; R8 dependency rejection completed).
focus: { source: file, path: cmd/svc/main.go }
---
PASS only if ALL hold in the FOCUS file:
1. Configuration is obtained once at the top of main (a call such as
   `cfg, err := env.Load()` or `cfg := env.Load()`) and then individual values
   are handed to constructors — no package reads a global elsewhere from this
   file's point of view (no `env.Config.X` anywhere).
2. The body reads as a story at one altitude: load config → build leaf values
   (worker pool size, batch size, flap window, store) → build the services /
   scheduler / handlers that take them → serve. Every step is a named call or
   an assignment of one.
3. No business logic or parsing lives in main (no string splitting, no status
   comparisons, no retry loops); small wiring helpers (listen address, store
   selection) are fine.
FAIL if main still reads `env.Config`, or threads the whole configuration
struct into internal packages instead of the values they need.
