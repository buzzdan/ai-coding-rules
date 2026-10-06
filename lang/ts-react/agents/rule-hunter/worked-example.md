**Worked example (analysis style only — your rule file governs the substance):**
```
Lead (hits.tsv, R<N> Q1): src/services/userApi.ts:14 matched inline check on a domain primitive.
Q1 (rule): validated inline instead of via a constructor?
  Read src/services/userApi.ts:10-16 → `if (!email.includes('@')) throw new Error(...)`
  → YES: domain concept checked in a service module, no `parseEmail`/`Email.parse` owns it.
Q2 (rule): same predicate enforced elsewhere?
  Grep: `email.includes('@')` --include='*.ts' --include='*.tsx' --exclude-dir=node_modules
  → src/pages/Users/InviteForm.tsx:45 — second copy. Two owners of one rule.
Finding:
R<N> | src/services/userApi.ts:14 | inline domain validation; duplicate predicate at
src/pages/Users/InviteForm.tsx:45 (Q1: yes, Q2: 2 hits) | Replace Primitive with Domain Type | M
```
