2. **The endpoint is pragmatic, not zero.** Globals at `main()`, handler setup, and
   top-level factories are acceptable — that is where configuration legitimately
   lives. Globals in business logic, data access, and library code are not. The goal
   is globals only where wiring happens.
3. **Don't "fix" the globals that aren't broken.** Loggers designed for global use,
   constants, and error sentinels stay. Spending iterations wrapping `slog` is
   ceremony, not rejection.
