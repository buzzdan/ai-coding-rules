```python
# ❌ success and error fused into one table, with a branch inside the case
@pytest.mark.parametrize(("raw", "expect_err"), [("a@b.io", False), ("", True)])
def test_parse_email(raw: str, expect_err: bool) -> None:
    if expect_err:
        with pytest.raises(ValueError):
            Email.parse(raw)
    else:
        assert Email.parse(raw).domain == "b.io"


# ✅ two functions, one shape each, every row named
@pytest.mark.parametrize(
    "raw",
    [pytest.param("a@b.io", id="plain"), pytest.param("A@B.IO", id="upper")],
)
def test_parse_email_success(raw: str) -> None:
    assert Email.parse(raw).domain == "b.io"


@pytest.mark.parametrize(
    "raw",
    [pytest.param("", id="empty"), pytest.param("no-at", id="no-at")],
)
def test_parse_email_error(raw: str) -> None:
    with pytest.raises(ValueError):
        Email.parse(raw)
```

> **In Python:** `pytest.param(..., id=...)` on every row so a failure names its
> case; import as a consumer would, `from app import user`. No `time.sleep`: wait on
> `Event.wait(timeout)`, `Queue.get(timeout)` or an awaited future. Orchestrators are
> tested by wiring their real collaborators over `tmp_path`, an in-process fake
> server or an embedded database. Leaf packages, and only they, are also listed under
> `paths_to_mutate` for `mutmut`: a surviving mutant is a missing row or dead logic.
