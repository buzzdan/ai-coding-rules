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
