---
name: testing
description: |
  Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed.
  Automatically invoked to write tests for new types, or use as testing expert advisor.
  Covers the composition ladder from rung-0 unit tests to whole-system tests, with emphasis on real in-memory dependencies.
  Ensures 100% coverage on leaf types with public API testing.
---

<objective>
Principles and patterns for writing effective {{.Lang}} tests.
Writes tests autonomously based on code structure and type design, and serves as testing expert advisor.

**Reference**: See `reference.md` for comprehensive testutils patterns and DSL examples.
</objective>

<quick_start>
{{include "skills/testing/quick-start.md"}}
</quick_start>

<when_to_use>
<automatic_invocation>
- **Automatically invoked** by @linter-driven-development in Phase 2's RED step — one failing test per behavior, placed by the composition ladder
- **Automatically invoked** by @refactoring when new isolated types are created
- **Automatically invoked** by @code-designing after designing new types
- **After creating new leaf types** - Types that should have 100% unit test coverage
- **After extracting functions** during refactoring that create testable units
</automatic_invocation>

<manual_invocation>
- User explicitly requests tests to be written
- User asks for testing advice, recommendations, or "what to do"
- When testing strategy is unclear (table-driven vs testify suites)
- When choosing between dependency levels (in-memory vs binary vs test-containers)
- When adding tests to existing untested code
- When user needs testing expert guidance or consultation
</manual_invocation>
</when_to_use>

<philosophy>
**Test only the public API**
- Use `pkg_test` package name
- Test types through their constructors
- No testing private methods/functions — the urge to unit-test an unexported helper directly is a promotion signal: give the helper its own package (`../../rules/R4-helper-placement.md`), never test privates.

**No mocks — and a struct that only satisfies a production interface in a test IS a mock**
- A "fake" is a *real implementation with fake data* (embedded DB, `httptest` server, fake binary, temp dir) — NOT a struct written to satisfy a dependency interface.
- Terminology: the banned "mock" is an interface-injected struct double. The "in-memory mock servers" elsewhere in this skill (testutils DSL, `httptest` wrappers) are fakes in this sense — real servers speaking the real protocol with configurable fake data — and remain the recommended stand-in for external APIs you don't control (wired via URL/config, never via a production interface).
- Use in-memory implementations (fastest, no external deps), HTTP test servers (httptest), temp files/directories, or the real dependency.
- **Orchestrators are tested by wiring their real collaborators** (real Store/Evaluator over embedded DB + `httptest` external services), never by injecting doubles.
- If you are tempted to add an interface so a test can inject a fake, stop — that interface is a test-only smell. Depend on the concrete type instead (see @code-designing and `../../rules/R6-test-only-interfaces.md`).

**Coverage targets**
- Rung 0 (leaf types): 100% unit test coverage
- Higher rungs (orchestrating types): cover the delta each rung adds — its seams and emergent behaviors
- Critical workflows: top-rung (system) tests

**Assertions**: testify is the default, but project convention wins (e.g. goweka uses stdlib assertions) — match the codebase you're in.
</philosophy>

<composition_ladder>
Tests sit on a ladder of real composition, not a pyramid of layer percentages.

**Rung 0 — pure leaf types.** No I/O, no goroutines, no production dependencies.
Tests are plain constructions plus assertions: slice literals, value tables.
100% coverage is expected here — leaf types own most of the logic.

**Each rung above adds exactly one real production layer** — the real
implementation, never a mock. In-memory/in-process infrastructure counts as the
real layer: httptest server, bufconn gRPC, in-memory NATS, temp files, embedded
VictoriaMetrics.

**Fake only the true external boundary** — the thing you genuinely cannot run
in-process (a third-party SaaS API, a hardware device). Everything inside the
boundary composes real.

**Placement rule: test each behavior at the lowest rung that contains it.** A
behavior expressible at rung 0 never gets tested through a rung-2 harness.

**Each rung tests its delta plus emergent behaviors**: the wiring/seams that rung
adds and behaviors that only exist through composition — not a re-test of
lower-rung logic (some overlap with leaf coverage is acceptable for orchestrators,
per `../../rules/R7-test-placement.md`).

The **top rung** is the whole system composed: black-box tests from `tests/` via
CLI/API, only the external boundary faked.

**Obligation table** — a template; adapt the rows per project and keep the adapted
table in the project docs:

| Kind of change | Owes a test at |
|---|---|
| New leaf type, or new behavior on one | Rung 0 |
| New seam between components X and Y | Rung 1 — the first rung containing the seam |
| New wiring through an infrastructure layer (queue, DB, RPC) | The rung that adds that layer |
| New externally observable behavior | Top rung |

The ladder is defined here; the placement review contract (falsifying questions)
lives in `../../rules/R7-test-placement.md`.
</composition_ladder>

<reusable_infrastructure>
{{include "skills/testing/reusable-infrastructure.md"}}
</reusable_infrastructure>

<workflow>

<unit_tests_workflow>
{{include "skills/testing/unit-tests-workflow.md"}}
</unit_tests_workflow>

<integration_tests_workflow>
{{include "skills/testing/integration-tests-workflow.md"}}
</integration_tests_workflow>

<system_tests_workflow>
{{include "skills/testing/system-tests-workflow.md"}}
</system_tests_workflow>

</workflow>

<key_patterns>
{{include "skills/testing/key-patterns.md"}}
</key_patterns>

<output_format>
{{include "skills/testing/output-format.md"}}
</output_format>

<testing_checklist>
{{include "skills/testing/checklists.md"}}
</testing_checklist>

<success_criteria>
{{include "skills/testing/success-criteria.md"}}
</success_criteria>
