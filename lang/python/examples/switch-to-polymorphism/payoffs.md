1. **A type check replaces a silent no-op.** A new `PubSubPatch` without
   `fill_update` no longer satisfies `Patch`, so `UpdateArg(patch=PubSubPatch(...))`
   fails ty at the moment of authorship — the strongest catch point Python has.
   (This is R11's exhaustiveness payoff without an `assert_never` arm: protocol
   satisfaction *is* the completeness proof.)
2. **Adding a destination is a new module, not an edit.** `from_update_arg` is frozen
   at three beats; the `match` version grows a hump per destination forever.
3. **The story survives (R3).** The orchestrator states *what* happens; each
   destination's *how* lives one level down, on the class that owns the data.
4. **The protocol is earned, and its set is recorded.** Four production
   implementations — this passes R6's earned-interface test (contrast: a protocol
   whose only second implementer is a test double). Python cannot seal a protocol
   the way a private method would elsewhere; the closed set is recorded instead,
   as a `PATCH_TYPES: tuple[type[Patch], ...] = (SplunkPatch, S3Patch, KafkaPatch,
   SyslogPatch)` that ty checks member by member, and a one-line test that every
   `ExportType` has a class in it.
