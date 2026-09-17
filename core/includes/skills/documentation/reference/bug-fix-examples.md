**Example — Email Validation Bug:**
```
❌ DON'T ADD:
## Bug Fixes
- Fixed: Email validation now correctly rejects addresses without TLD

✅ DO UPDATE existing "Validation" section:
## Validation
Email addresses must include a valid TLD (e.g., .com, .org).
Invalid formats fail with ErrInvalidEmail and a descriptive message.
```

**Example — Parser Edge Case:**
```
❌ DON'T ADD:
## v1.2.3 Changes
- Fixed edge case where empty input crashed the parser

✅ DO UPDATE existing "Input Handling" section:
## Input Handling
Empty input fails with ErrEmptyInput. All inputs are validated before parsing.
```