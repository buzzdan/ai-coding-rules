---
type: llm
criteria: The node list became a collection type that answers placement questions by name, and Pick reads as a two-line story instead of a flag-driven loop.
focus: { source: files, paths: [internal/placement] }
---
Glance at the package as a first-time reader. The single-altitude grader already
checks the orchestrator body; you judge whether the whole file now reads as
art.

PASS only if all four hold, quoting the convincing line for each:

1. **The collection has a name.** Something like `type Nodes []Node` (or
   `Fleet`, `Candidates`) exists and owns the walking: methods such as
   `Usable()`, `InZone(zone)`, `OutsideZone(zone)`, `First()` returning
   `(Node, bool)`. A loop that still lives in the placer with flags renamed
   is FAIL.
2. **The node knows its own health.** "Empty zone or non-positive capacity
   means unusable" is stated once, as a method on `Node` (`Usable()`,
   `Healthy()`), not as an inline predicate in the picker.
3. **Pick tells the story.** Its body reads roughly: primary = usable nodes
   in the zone, first; secondary = usable nodes outside the zone, first;
   error if either is missing. Each step a named call. No `primaryFound`
   style booleans anywhere in the file.
4. **Names and comments earn their place.** No `// Placer is a placer` style
   restatements remain; the package comment says why placement spreads
   replicas across zones. Method names are domain words, not `helper`,
   `process`, `do`, `check`.

FAIL outright if `primaryFound`, `secondaryFound` or any `found` flag
survives, or if `pickReplicas` still ranges over the slice with nested `if`.
