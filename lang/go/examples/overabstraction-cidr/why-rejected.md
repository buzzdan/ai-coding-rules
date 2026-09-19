1. **8 lines of code** for a trivial wrapper.
2. **One method** that just unwraps: `return bool(p)`.
3. **No type safety gained** — still just a bool underneath; nothing invalid is made
   unrepresentable.
4. **Not more readable.** Compare `config.ClusterCIDR.IsSet()` (wrapper) with
   `config.ClusterCIDRSet` (good naming). The honest question — is the method call
   *significantly* clearer? — answers itself: no.
5. **No validation, no logic, no invariants** — pure ceremony. On R1's scorecard this
   scores 0-1: LOW priority, do not create the type.
6. **Increases cognitive load** — one more type to understand, for nothing.
