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