A real refactoring where a module-level `env.CONFIG` object reached from deep inside
the codebase (20+ access points) was eliminated incrementally — one clean island at a
time, pushing each global up one level per iteration until only the entry points
touched configuration. This is the case law for R8: the rejection move, why sideways
access resists testing, and the pragmatic stopping point.

This pattern differs from the other refactorings in one important way: it is **not a
one-time fix**. It is an incremental journey — start at the bottom (leaf code),
create one clean island at a time, push globals toward `main()` and the app
factory, and accept globals at the top.
