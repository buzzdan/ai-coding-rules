---
name: testing
description: |
  Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed.
  Automatically invoked to write tests for new types, or use as testing expert advisor.
  Covers the composition ladder from rung-0 unit tests to whole-system tests, with emphasis on real in-memory dependencies.
  Ensures 100% coverage on leaf types with public API testing.
---

<objective>
Principles and patterns for writing effective any-language tests.
Writes tests autonomously based on code structure and type design, and serves as testing expert advisor.

**Reference**: See `reference.md` for comprehensive testutils patterns and DSL examples.
</objective>

<quick_start>
1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: a case table for simple behaviors (the repository's
   table-test or parametrize idiom), a suite or fixture for complex setup
3. **Import as a consumer would** - test public API only
4. **Compose real layers** - in-memory/in-process implementations from the
   repository's test utilities
5. **Avoid pitfalls**: No sleeps, no conditionals in test cases

Ready after tests? Run the repository's lint command with its fix flag.
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
- When testing strategy is unclear (table-driven vs suites)
- When choosing between dependency levels (in-memory vs binary vs test-containers)
- When adding tests to existing untested code
- When user needs testing expert guidance or consultation
</manual_invocation>
</when_to_use>

<philosophy>
**Test only the public API**
- Import the package as a consumer would, so privates are unreachable
- Test types through their constructors
- No testing private methods/functions — the urge to unit-test an internal helper directly is a promotion signal: give the helper its own package (`../../rules/R4-helper-placement.md`), never test privates.

**No mocks — and a type that only satisfies a production interface in a test IS a mock**
- A "fake" is a *real implementation with fake data* (embedded DB, in-process HTTP server, fake binary, temp dir) — NOT a type written to satisfy a dependency interface, and NOT a patched-in stand-in.
- Terminology: the banned "mock" is an interface-injected or patched-in double. The "in-memory mock servers" elsewhere in this skill are fakes in this sense — real servers speaking the real protocol with configurable fake data — and remain the recommended stand-in for external APIs you don't control (wired via URL/config, never via a production interface).
- Use in-memory implementations (fastest, no external deps), in-process HTTP test servers, temp files/directories, or the real dependency.
- **Orchestrators are tested by wiring their real collaborators** (real Store/Evaluator over embedded DB + in-process external services), never by injecting doubles.
- If you are tempted to add an interface so a test can inject a fake, stop — that interface is a test-only smell. Depend on the concrete type instead (see @code-designing and `../../rules/R6-test-only-interfaces.md`).

**Coverage targets**
- Rung 0 (leaf types): 100% unit test coverage, and no untriaged survivor when the
  mutation tool runs over the leaf's package (`../../rules/R7-test-placement.md`,
  Mutation score on leaf types only) — coverage is the floor, the mutation score the claim
- Higher rungs (orchestrating types): cover the delta each rung adds — its seams and emergent behaviors
- Critical workflows: top-rung (system) tests

**Assertions**: the repository's own assertion style wins — match the codebase you're in; never introduce a second assertion library.
</philosophy>

<composition_ladder>
Tests sit on a ladder of real composition, not a pyramid of layer percentages.

**Rung 0 — pure leaf types.** No I/O, no concurrent tasks, no production dependencies.
Tests are plain constructions plus assertions: slice literals, value tables.
100% coverage is expected here — leaf types own most of the logic.

**Each rung above adds exactly one real production layer** — the real
implementation, never a mock. In-memory/in-process infrastructure counts as the
real layer: an in-process HTTP server, an in-memory broker, temp files, an embedded
database.

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
Build shared test infrastructure where the repository already keeps its test
helpers (a test-utilities package, a `conftest`, a `test/support` directory —
create one in the language's convention when none exists):
- In-memory fake servers with a DSL (HTTP, DB, file system)
- Reusable across all test levels
- Test the infrastructure itself!
- Can expose as CLI tools for manual testing

**Dependency Priority** (choose appropriate level):
1. **In-memory** (fastest): pure in-process code, an in-process HTTP server, an in-memory DB - use when testing your code's logic
2. **Binary** (isolated): a standalone executable started as a subprocess - use when testing against a real service
3. **Test-containers** (realistic): programmatic Docker from the test - use when you need real external services
4. **Docker-compose** (full stack): For complex multi-service scenarios

Choose based on what you're testing, not dogmatically. In-memory is fastest but sometimes you need real services.

The repository's own test utilities and their DSLs are the reference — match them
before inventing a shape.
</reusable_infrastructure>

<workflow>

<unit_tests_workflow>
**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Self-contained types with logic
2. **Choose structure** - A case table (simple) or a suite/fixture (complex setup)
3. **Import as a consumer would** - Test public API only
4. **Use in-memory implementations** - From the repository's test utilities or local implementations
5. **Avoid pitfalls** - No sleeps, no conditionals in cases, no private method tests

**Test structure:**
- Case tables: Separate success/error test functions (complexity = 1)
- Suites/fixtures: Only for complex infrastructure setup (HTTP servers, DBs)
- Name every case field or parameter — positional case tuples hide what each value means

Match the repository's test framework and assertion style; never introduce a second one.
</unit_tests_workflow>

<integration_tests_workflow>
**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where packages/components interact
2. **Choose dependencies** - Prefer: in-memory > binary > test-containers
3. **Write tests** - Imported as a consumer would, marked the way the repository marks
   slower tests (a build tag, a marker, a separate directory) so they can be run on
   their own
4. **Test workflows** - Cover happy path and error scenarios across boundaries
5. **Use real or test-utility implementations** - Avoid heavy mocking

**File organization:** one integration test file per seam, next to the tests of the
component that owns the seam, or under the repository's integration-test directory
when it has one — follow the existing layout.
</integration_tests_workflow>

<system_tests_workflow>
**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

1. **Place in tests/ folder** - At project root, separate from packages
2. **Test via CLI/API** - A subprocess for a CLI, an HTTP client for an API
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, use when testing your code's behavior
   - **Binary**: Run the real executable as a separate process
   - **Test-containers**: When you need real external services (DB, message queue)
4. **Test critical workflows** - User journeys, not every edge case

**Example with an in-process fake:** start the fake API in-process (an HTTP test
server with configurable responses), run the CLI as a subprocess with the fake's
URL, assert on the output.

**Example with a real service binary:** start the service executable in the
background, wait for its health endpoint (a poll with a timeout, never a fixed
sleep), run requests against it, assert on the responses, stop it in teardown.
</system_tests_workflow>

</workflow>

<key_patterns>
**Case Tables (Cyclomatic Complexity = 1):**
- **NEVER fuse success and error cases behind a flag** - It splits test logic and adds conditionals
- **Max complexity = 1 inside a case** - No if/else, no switch, no conditionals
- Separate success and error test functions (TestFoo_Success, TestFoo_Error)
- Name every case field or parameter; positional tuples hide what each value means
- Canonical violation, detection commands, and split pattern: `../../rules/R7-test-placement.md`

**Suites and fixtures:**
- Only for complex infrastructure (HTTP servers, DBs, telemetry)
- Suite-level setup/teardown for expensive shared setup
- Per-test setup/teardown for per-test isolation

**Synchronization:**
- Never sleep to synchronize (flaky, slow)
- Wait on an event, channel or future with a timeout for async operations
- Join concurrent work through its group or wait primitive before asserting

The repository's test framework decides how each of these is spelled; match it.
</key_patterns>

<output_format>
After writing tests:

```
TESTING COMPLETE

Unit Tests:
- user/user_id<test-file suffix>: 100% (4 test cases)
- user/email<test-file suffix>: 100% (6 test cases)
- user/service<test-file suffix>: 100% (8 test cases)

Integration Tests:
- user/integration<test-file suffix>: 3 workflows tested
- Dependencies: in-memory DB, in-process fake API server

System Tests:
- tests/cli<test-file suffix>: 2 end-to-end workflows (in-memory fakes)
- tests/api<test-file suffix>: 1 full API workflow (binary executable)
- tests/db<test-file suffix>: 1 database workflow (test-containers)

Test Infrastructure:
- <test utilities>/httpserver: in-memory fake API with DSL
- <test utilities>/fakedb: in-memory database fake
- <test utilities>/containers: test-container helpers

Test Execution:
$ <the repository's test command>                 # all tests (in-memory only)
$ <the same command, integration marker enabled>  # include integration tests
$ <the same command over tests/>                  # system tests (may need containers)

All tests pass
100% coverage on leaf types

Next Steps:
1. Run the repository's lint command with its fix flag
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```
</output_format>

<testing_checklist>
<unit_tests_checklist>
- [ ] All unit tests import the code as a consumer would
- [ ] Testing public API only (no private methods)
- [ ] Case tables name every field or parameter
- [ ] No conditionals in test cases (complexity = 1)
- [ ] Using in-memory implementations from the repository's test utilities
- [ ] No sleeps (events, channels or futures with a timeout)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] Marked for optional execution the way the repository marks slow tests
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or test-utility implementations (minimal mocking)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in tests/ folder at project root
- [ ] Black box testing via CLI/API
- [ ] Appropriate dependency level chosen (in-memory, binary, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable fakes live where the repository keeps its test utilities
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing
</test_infrastructure_checklist>

The repository's own test framework and utilities are the reference for how each
item is spelled.
</testing_checklist>

<success_criteria>
Testing is complete when ALL of the following are true:

- [ ] All unit tests import the code as a consumer would and test the public API only
- [ ] Case tables name every field or parameter
- [ ] No success-or-error flag - success and error cases in separate test functions
- [ ] Cyclomatic complexity = 1 inside every case (no if/else, no switch)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover component seams
- [ ] System tests in tests/ folder with appropriate dependency level
- [ ] No sleeps (events, channels or futures with a timeout)
- [ ] Tests pass and linter approves
</success_criteria>
