---
type: llm
criteria: The global was pushed up to the composition root and every layer below it now states, in its signature, exactly what it depends on.
focus: { source: files, paths: [internal/env/env.go, internal/pool/workers.go, internal/jobs/scheduler.go, cmd/svc/main.go] }
---
Glance at the four files top-down, main first. Judge the dependency story,
not lint mechanics (the linter and the git ratchet are graded elsewhere).

PASS only if all four hold, quoting the convincing line for each:

1. **The root reads like a wiring diagram.** `main` loads configuration once
   into a value (`cfg := env.Load()` or similar), then hands each collaborator
   the specific value it needs: the pool gets a worker count, the scheduler
   gets a batch size (or a small config value type such as `pool.Config`).
   No `env.Config.` read anywhere outside `main`.
2. **Islands are clean.** `pool` and `jobs` import nothing from `env`. Their
   constructors or `Start` functions name the dependency in the signature:
   `pool.Start(jobs, workers int)` or `pool.New(Config{Workers: n})`. A
   package-level `var` that main sets from the outside is a global with
   extra steps: FAIL.
3. **The env package only loads.** No `init()`, no package-level mutable
   `Config` or `region`. `Load` returns a `Configuration` value (or an
   error); defaults live next to the key they default (`intEnv("NUM_WORKERS",
   4)` is fine).
4. **Names carry the meaning the global used to hide.** Parameters are
   `workers`, `batchSize`, `flapWindow time.Duration` — not `cfg` passed whole
   into leaf packages, not `n`, not `opts interface{}`. Types that turn a
   bare int into a named quantity (`Workers`, `BatchSize`) are a plus, never
   required.

FAIL outright if any file other than `cmd/svc/main.go` references
`env.Config`, or if `env.go` still contains `func init()`.
