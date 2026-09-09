---
type: architecture
description: the go-mini fixture and the violations manifest: plants, controls, scaffolds, and the checks that keep them honest
---
# The Fixture and Its Answer Key

## The fixture
`evals/fixtures/go-mini/` is a small device-fleet backend: devices post heartbeats
over HTTP, a scheduler runs snapshot jobs, alerts go out over channels, a status
endpoint reports. It is written to be as bad as possible in exactly the ways the
plugin's twelve rules describe, and no worse: every rule's falsifying questions have
at least one plant that trips that question's own detection command, and every rule
has a control — healthy code the plugin must leave alone. Recall is measured on
plants, precision on controls.

Ground rules, all enforced:

- **No hints in the tree.** No markers, no TODOs naming rules, no fixture CLAUDE.md
  describing the mess. The agent sees a legacy repo. `check-manifest.sh` fails on
  the words violation, falsifying, smell and on any rule id in a comment.
- **Runnable.** It builds, `task test` is green, `task lint` is green in the default
  state, and `task test:race` is red on exactly one planted race. Real
  collaborators are cheap on purpose: the repository is a JSON file store and the
  alert channel is an HTTP webhook, so the test-double plants are demonstrably
  unnecessary.
- **Two lint states from one tree.** Every design-level lint plant carries a
  `//nolint:<linter> // TODO` directive. `scaffold/default.sh` copies the tree as is
  (lint green, and the review must flag every directive). `scaffold/red-lint.sh`
  strips the directives first: 51 real findings across 13 linters, which is what
  the quickfix case exercises.
- **House style is plain.** Standard-library testing and logging, a Taskfile, no
  assertion library. Anything the agent introduces beyond that is a
  when-in-Rome finding it must raise on itself.
- **Everything lives under `internal/`, `cmd/` and `pkg/`** because the plugin's
  package-size hook scans only those directories.

## The manifest
`evals/violations.yaml` is the answer key, kept outside the scaffolded tree. One
entry per plant or control, 148 in total:

```yaml
- id: R11.Q1.channel-switch
  rule: R11
  questions: [Q1, Q3]
  files: [internal/services/notify.go, internal/services/validate.go]
  anchor: 'switch a\.Channel'          # stable regex; no marker in code
  expect:
    review:   { category: "🔴", cluster: "Alert.Channel", fix: "Replace Duplicated Switch with Interface Dispatch" }
    refactor: { gone: 'switch a\.Channel', count_max: 1 }
    lint:     { linter: dupl, route: R11 }
- id: CTRL.R6.store-interface
  rule: R6
  control: true
  files: [internal/repository/store.go]
  anchor: 'type Store interface'
  symbol: Store
```

The manifest has three consumers, so a fact lives once:

1. **The whole-repo review's graders.** `tools/gen-review-graders.sh` writes one
   recall grader per plant (the report must name the plant's file), one cluster
   grader per declared cluster, and one precision grader per control (the report
   must not mention the control's `symbol`, unless `mention_ok: true` says a correct
   report legitimately names it). Never hand-edit the generated files; edit the
   manifest and regenerate.
2. **The refactor cases' oracles.** The `gone` patterns become file graders with
   `match: count:0` or a maximum count.
3. **The later Python parity report.** A Python fixture will carry the same ids with
   Python anchors, so per-rule recall can be compared across languages.

`check-manifest.sh` asserts that every listed file exists, that every anchor matches
at least one line in each listed file, that every rule has at least one plant and
one control, and that the fixture carries no hints. Run it after any change to the
fixture or the manifest.

## Known weakness
The Case D control's types have no callers in the fixture, so an agent that deletes
them is right, and the control never gets to test "leave earned ceremony alone".
Give the control a real caller before recording the next baseline; the refactor
case's judge already tolerates deletion of unreferenced code.
