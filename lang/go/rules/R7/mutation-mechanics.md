- **Mutation mechanics**: `gremlins unleash ./path/to/leaf` (go-gremlins, a Go mutation
  tester that swaps comparison operators, negates conditions, flips arithmetic and
  removes statements) over the leaf package, after `go test` is green there and after
  each fix; its report's `LIVED` lines are the survivors to triage, `KILLED` the rows
  that hold. In CI, `--threshold-efficacy` on that package only, never on `./...`, so
  orchestrator packages are not mutated. When `gremlins` is not on `PATH`, propose a
  `mutate` target beside `test` and `lint` in the repository's Taskfile or Makefile
  that runs `go install github.com/go-gremlins/gremlins/cmd/gremlins@latest` and then
  `gremlins unleash ./<leaf>`; with no task runner, propose that `go install` line for
  the developer to run. Ask first, never install silently, and never substitute a
  different invocation: a report whose mutants all timed out, with no `LIVED` and no
  `KILLED` line, is a broken run, not a clean one.
