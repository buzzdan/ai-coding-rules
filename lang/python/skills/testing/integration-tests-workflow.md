**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where packages/components interact
2. **Choose dependencies** - Prefer: in-memory > binary > test-containers
3. **Write tests** - Imported as a consumer would, in a `test_integration.py` beside the component or under `tests/integration/`, marked `@pytest.mark.integration` (register the marker in `pyproject.toml` so `pytest -m "not integration"` skips them)
4. **Test workflows** - Cover happy path and error scenarios across boundaries
5. **Use real or test-support implementations** - No `mock.patch` of internal collaborators

**File organization:**
```python
# user/test_integration.py
import pytest

pytestmark = pytest.mark.integration

# Service + Repository + real in-memory dependencies
```

See reference.md for integration test patterns with dependencies.
