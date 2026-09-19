**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

1. **Place in tests/ folder** - At project root, separate from packages
2. **Test via CLI/API** - `subprocess.run` for a CLI, an HTTP client for an API
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, use when testing your code's behavior
   - **Binary**: `subprocess.Popen` to run the real executable in a separate process
   - **Test-containers**: When you need real external services (DB, message queue)
4. **Test critical workflows** - User journeys, not every edge case

**Example with an in-process fake:**
```python
# tests/test_cli.py - the CLI against a fake API
def test_cli_prints_the_user(fake_api: FakeServer) -> None:
    fake_api.on_get("/users/1").respond_json(200, USER)

    result = subprocess.run(
        [sys.executable, "-m", "myapp", "get-user", "1", "--api-url", fake_api.url],
        capture_output=True, text=True, check=False,
    )

    assert result.returncode == 0
    assert "alice" in result.stdout
```

**Example with a real service binary:**
```python
# tests/test_system.py - against the real service process
def test_lists_users_from_the_running_service(service: RunningService) -> None:
    # `service` is a fixture: it starts the process, polls /health with a
    # deadline (never a fixed sleep), and terminates and waits in teardown
    with urllib.request.urlopen(f"{service.url}/api/users") as resp:
        assert resp.status == 200
```

See reference.md for the harnesses behind `fake_api` and `service`, and for test-containers.
