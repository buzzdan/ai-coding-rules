```python
# ❌ one production implementer; the Protocol exists for FakeLeaves in the test
class Leaves(Protocol):
    def find_latest(self, job_id: JobId) -> Job: ...

# ❌ the same seam with no declaration to grep for
@patch("app.service.Store")
def test_rerun(store_cls: MagicMock) -> None: ...


# ✅ concrete dependency; the test wires the REAL Store over a temp directory
class Service:
    def __init__(self, leaves: worker.Store) -> None:
        self._leaves = leaves

def test_rerun(tmp_path: Path) -> None:
    svc = Service(worker.Store(tmp_path / "leaves.db"))
```

> **In Python (opinionated):** `mock.patch` and `monkeypatch` on a collaborator you
> own are this smell with no `Protocol` to point at. Patching the true external
> boundary is fine: the clock, a socket, `os.environ` in an entry-point test. A
> `Protocol` is structural like an interface, so the one-implementer test transfers
> unchanged.
