**MANDATORY** after creating new types or extracting functions:
1. List created types: `grep -RnE "^class[[:space:]]+\w+" --include="*.py" .`
2. Missing tests for any of them → STOP and invoke @testing.
3. Coverage: `pytest --cov=<package> --cov-report=term-missing` (or the repository's
   coverage command) — leaf types must show 100% (R7).
