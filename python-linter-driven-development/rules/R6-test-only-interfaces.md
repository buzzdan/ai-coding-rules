# R6 — Test-Only Interfaces

## Principle

A seam that exists only so a test can substitute a double — an interface with one
production implementer, a patched attribute, an injection parameter no production
caller varies — is deleted; depend on the concrete collaborator. Don't create interfaces
until you need them; a test fake is not a need. An interface is justified only by a
real second production implementation or a verified import cycle.

## Why

This is the exact failure that slips past reviews: a reasonable-looking interface
with a comment "explaining" it (usually "avoids an import cycle" or "for testing"),
one production implementation, and a test double as the only other implementer. The
interface adds an indirection every reader must resolve, detaches the consumer from
the real type's documentation and behavior, and — worst — licenses the test to
exercise a hand-written double instead of the real collaborator, so the test proves
nothing about production wiring. A hand-written type that only satisfies a
production interface to stand in for the real collaborator IS a mock, whatever the
file calls it. A "fake" is a real implementation with fake *data* — embedded DB,
in-process HTTP server, temp dir. Orchestrators are tested by wiring their real
collaborators (`R7-test-placement.md`); they never need injection seams carved for
doubles.

## Canonical example

### Before — a seam exists only for a test double

```python
# service.py — one production implementation (worker.Store); the Protocol exists for the test
class Leaves(Protocol):
    def find_latest(self, job_id: JobId) -> Job: ...


class Service:
    def __init__(self, leaves: Leaves) -> None:
        self._leaves = leaves


# test_service.py — the ONLY other implementer is a hand-written double
class FakeLeaves:
    def __init__(self, job: Job) -> None:
        self.job = job

    def find_latest(self, job_id: JobId) -> Job:
        return self.job
```

The same seam without a Protocol, the Python way — a patch of the concrete
collaborator:

```python
@patch("app.service.Store")                      # ❌ the double rides in through the module
def test_rerun(store_cls: MagicMock) -> None:
    store_cls.return_value.find_latest.return_value = job
    ...
```

### After — concrete dependency, tested by wiring the real collaborator

```python
# service.py — concrete; no cycle (the worker package does not import this one)
class Service:
    def __init__(self, leaves: worker.Store) -> None:
        self._leaves = leaves


# test_service.py — construct the REAL Store over a temp directory (or an embedded
# database) plus a fake HTTP server for the external service
def test_rerun(tmp_path: Path, jira: FakeJira) -> None:
    store = worker.Store(tmp_path / "leaves.db")
    svc = Service(store, Evaluator(), JiraClient(jira.url))   # real objects, fake data
    ...                                                        # exercise the public method, assert on real state
```

The test now covers the seam it claims to cover: the real `Store`'s queries run
against a real file. The Protocol, its indirection, and the double are all deleted;
the `patch` is gone with them. A Protocol is structural, like a Go interface, so the
one-implementer smell transfers unchanged; `unittest.mock.patch` and `monkeypatch`
on a concrete collaborator are the same smell with no declaration to grep for.

## Design guidance

- **Interfaces are earned by a second production implementation** — an in-memory
  repository that production code can also use, a second backend, a real plug point.
  Until that exists, depend on the concrete type.
- **"For testing" never justifies an interface.** The test's job is to wire real
  collaborators over fake data (real store over embedded DB, real client against an
  in-process HTTP server) — `R7-test-placement.md` places the test; @testing has the harness
  patterns.
- **"Avoids an import cycle" is a claim, not a fact — verify it.** A real cycle
  exists only if the dependency's package imports the consumer's package back. If
  the grep (below) shows no back-import, the comment is cover for a test seam.
- **A real cycle is a layering bug, not an interface opportunity.** Move the package
  so the dependency direction is downward; don't invert the arrow with an interface
  whose only purpose is to break the cycle a double rides in on.
- **When an interface is genuinely needed**, define it at the point of use (in the
  consumer's package), keep it small and cohesive, and expect every implementation
  to be production code. The worked case of an *earned* interface — multiple
  production implementations replacing a growing type switch, sealed by an
  underscore-prefixed method: `../examples/switch-to-polymorphism.md` (dispatch discipline:
  `R11-conditional-dispatch.md`).

## Fix pattern

- **Delete the Test Seam**: replace the interface field, patched attribute or
  injection parameter with the concrete type; delete the interface declaration.
- **Rewrite the test around real collaborators**: construct the real dependency over
  fake data (embedded DB, temp dir, in-process HTTP server) and exercise the consumer's
  public API (@testing for harness patterns; placement per
  `R7-test-placement.md`).
- **Delete the double**: the fake type in `*_test.py` / `fakes/` / `mocks/` /
  `testutil*` goes with the interface.
- **If a verified cycle exists, fix the layering**: extract the shared vocabulary
  into a lower package both can import, or move the consumer — the dependency arrow
  must point downward.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **How many production implementations does each new/changed interface have?**
   Detection: for each `Protocol` or `ABC` in the diff, list its method names, then
   `grep -rnE '^\s+def <method>\(' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'`
   — the implementing classes. A Protocol is structural, so an implementer never
   names it; the method-name census is the only census. A `type[Protocol]`
   assignment or an `if TYPE_CHECKING:` tuple of implementers is a declared census
   — read it, then verify it.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: `grep -rnE '^\s+def <method>\(' --include='test_*.py' --include='*_test.py' --include='conftest.py' .`
   plus the same grep over test-support packages (`fakes/`, `mocks/`, `testing/`);
   then `grep -rnE 'mock\.patch|patch\(|monkeypatch\.setattr|MagicMock|create_autospec' --include='test_*.py' --include='*_test.py' .`
   and read what each patch targets — a patch on a concrete collaborator is a seam
   that exists only so the test can substitute a double, the same smell without the
   Protocol.
   Violation: yes — one production implementation + a double (a fake class, a
   `MagicMock`, a `patch` of the collaborator) = test-only seam; delete the
   Protocol, test the real type, and give the collaborator a real in-memory
   implementation if the test needs one. Patching the true external boundary (a
   socket, the wall clock, `os.environ` in an entry-point test) is not this finding.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction:
   ```bash
   # a real cycle exists only if the dependency module imports the consumer back:
   grep -rnE '^(from|import) .*<consumer module>' <dependency dir>/*.py   # no match ⇒ no cycle ⇒ interface unjustified
   ```
   An import under `if TYPE_CHECKING:` is not a run-time cycle: it exists for the
   annotation only, so a Protocol justified by "the import would cycle" is not
   justified when the concrete type could be imported the same way.
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: `grep -rn '<Consumer>(' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` —
   inspect the argument's type at each production call site.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: `grep -rn -B3 -E 'class \w+\((Protocol|ABC)\)' <changed files> | grep -iE 'for test|import cycle|mock|patch'`
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
