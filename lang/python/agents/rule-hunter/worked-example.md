**Worked example (analysis style only — your rule file governs the substance):**
```
Lead (pre-filter): user/service.py:14 matched inline check on a domain primitive.
Q1 (rule): validated inline instead of via a constructor?
  Read user/service.py:10-16 → `if "@" not in email: raise ValueError(...)`
  → YES: domain concept checked in a service method, no `Email.parse`/`__post_init__` owns it.
Q2 (rule): same predicate enforced elsewhere?
  Grep: `"@" not in email` --include='*.py'
  → user/repository.py:45 — second copy. Two owners of one rule.
Finding:
R<N> | user/service.py:14 | inline domain validation; duplicate predicate at
user/repository.py:45 (Q1: yes, Q2: 2 hits) | Replace Primitive with Domain Type | M
```
