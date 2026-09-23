- **Mutation mechanics**: `gremlins unleash ./path/to/leaf` (go-gremlins, a Go mutation
  tester that swaps comparison operators, negates conditions, flips arithmetic and
  removes statements) over the leaf package, after `go test` is green there and after
  each fix; its report's `LIVED` lines are the survivors to triage, `KILLED` the rows
  that hold. In CI, `--threshold-efficacy` on that package only, never on `./...`, so
  orchestrator packages are not mutated.
