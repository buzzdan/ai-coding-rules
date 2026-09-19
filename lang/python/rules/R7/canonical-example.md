### Before — anti-patterns stacked

```python
from app.user.service import _validate_email_internal, UserService   # private import


def test_validate_email_internal() -> None:                # testing a private
    assert _validate_email_internal("test@example.com")


@patch("app.user.service.Repository")                      # a double instead of the collaborator
def test_create_user(repo_cls: MagicMock) -> None:
    svc = UserService(repo_cls.return_value)
    svc.create_user("123", "test@example.com")
    repo_cls.return_value.save.assert_called_once()        # asserts on the fake, not on behaviour


@pytest.mark.parametrize(
    ("raw", "expect_err"),                                  # success and error fused
    [("a@b.io", False), ("", True)],
)
def test_parse_email(raw: str, expect_err: bool) -> None:
    if expect_err:                                          # a conditional inside a case
        with pytest.raises(ValueError):
            Email.parse(raw)
    else:
        assert Email.parse(raw).domain == "b.io"


def test_async_operation() -> None:
    threading.Thread(target=do_async_work).start()
    time.sleep(0.1)                                         # flaky
    assert work_completed
```

### After — right rung, real collaborators, observable behaviour

```python
from app import user                                       # imported as a consumer would


def test_service_create_user(tmp_path: Path) -> None:
    repo = user.FileRepository(tmp_path / "users.json")    # real implementation, fake data
    emailer = user.RecordingEmailer()

    svc = user.UserService(repo, emailer)
    svc.create_user(TEST_USER)

    assert svc.get_user(TEST_USER.id).email == TEST_USER.email   # verify via the public API


@pytest.mark.parametrize(
    ("raw", "domain"),
    [pytest.param("a@b.io", "b.io", id="plain"), pytest.param("A@B.IO", "b.io", id="lower-cased")],
)
def test_parse_email_success(raw: str, domain: str) -> None:
    assert user.Email.parse(raw).domain == domain


@pytest.mark.parametrize("raw", [pytest.param("", id="empty"), pytest.param("no-at", id="no-at")])
def test_parse_email_error(raw: str) -> None:
    with pytest.raises(ValueError):
        user.Email.parse(raw)


def test_async_operation() -> None:
    done = threading.Event()
    threading.Thread(target=lambda: (do_async_work(), done.set())).start()

    assert done.wait(timeout=1.0), "timeout waiting for async work"
```

Email validation itself is a leaf behaviour — it belongs one rung down, as a unit
test on `Email.parse` with literal strings, not inside the service test and not as a
private-function test. The two `parametrize` tables are the split the rule asks for:
one function asserts values, one asserts the raise, and neither case body branches.
