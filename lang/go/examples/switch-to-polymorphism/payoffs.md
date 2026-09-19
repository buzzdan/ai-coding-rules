1. **Compile-time enforcement replaces a silent no-op.** A new `PubSubPatch`
   without `fillUpdate` no longer builds. The growth failure mode moved from
   "runtime request missing its payload" to "compiler error at the moment of
   authorship" — the strongest possible catch point. (This is R11's exhaustiveness
   payoff without the `exhaustive` linter: interface satisfaction *is* the
   completeness proof.)
2. **Adding a destination is a new file, not an edit.** `fromUpdateArg` is frozen
   at three beats; the switch version grows a hump per destination forever.
3. **The story survives (R3).** The orchestrator states *what* happens; each
   destination's *how* lives one level down, on the type that owns the data.
4. **The interface is earned, and sealed.** Four production implementations — this
   passes R6's earned-interface test (contrast: an interface whose only second
   implementer is a test double). The unexported method is a bonus: no code outside
   the package can implement `Patch`, so the implementation set is closed and the
   compiler-enforcement guarantee in payoff 1 cannot be bypassed.
