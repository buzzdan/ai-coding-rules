1. **A type error replaces a silent no-op.** A new `pubSubPatch` factory that returns
   `Patch` without `fillUpdate` does not typecheck, and neither does an object handed
   to `UpdateArg.patch` without one — the growth failure moved from "runtime request
   missing its payload" to "`tsc` error at the moment of authorship", the strongest
   catch point TypeScript has. (This is R11's exhaustiveness payoff without an
   `assertNever` arm: interface satisfaction *is* the completeness proof.)
2. **Adding a destination is a new module, not an edit.** `fromUpdateArg` is frozen
   at three beats; the `switch` version grows a hump per destination forever.
3. **The story survives (R3).** The orchestrator states *what* happens; each
   destination's *how* lives one level down, on the object that owns the data.
4. **The interface is earned, and its set is recorded.** Four production
   implementations — this passes R6's earned-interface test (contrast: an interface
   whose only second implementer is a test double). TypeScript cannot seal a
   structural interface — any object with a `kind` and a `fillUpdate` is a `Patch` —
   so the closed set is recorded instead: `kind` is typed `ExportType`, so no factory
   can invent a destination, and `PATCH_FACTORIES = { splunk: splunkPatch, s3:
   s3Patch, kafka: kafkaPatch, syslog: syslogPatch } satisfies Record<ExportType,
   unknown>` fails to compile the moment an `ExportType` member has no factory.
