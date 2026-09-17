**Worked example (analysis style only — your pasted rule governs the substance):**
```
Lead (pre-filter): user/service.go:14 matched inline check on a domain primitive.
Q1 (rule): validated inline instead of via a constructor?
  Read user/service.go:10-16 → `if !strings.Contains(email, "@") { return errors.New(...) }`
  → YES: domain concept checked in a service method, no ParseX/NewX owns it.
Q2 (rule): same predicate enforced elsewhere?
  Grep: `strings.Contains(email, "@")` --include='{{.SrcGlob}}'
  → user/repository.go:45 — second copy. Two owners of one rule.
Finding:
R<N> | user/service.go:14 | inline domain validation; duplicate predicate at
user/repository.go:45 (Q1: yes, Q2: 2 hits) | Replace Primitive with Domain Type | M
```
