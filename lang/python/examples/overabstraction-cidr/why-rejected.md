1. **8 lines of code** for a trivial wrapper.
2. **One method** that just unwraps: `return self.value`.
3. **No type safety gained** — still just a bool underneath; nothing invalid is made
   unrepresentable, and `CIDRPresence(True)` admits exactly what `True` admits.
4. **Not more readable.** Compare `config.cluster_cidr.is_set()` (wrapper) with
   `config.cluster_cidr_set` (good naming). The honest question — is the method call
   *significantly* clearer? — answers itself: no.
5. **No validation, no logic, no invariants** — pure ceremony. On R1's scorecard this
   scores 0-1: LOW priority, do not create the type.
6. **Increases cognitive load** — one more class to understand, for nothing.
