2. **The endpoint is pragmatic, not zero.** Configuration at `main()`, the app
   factory, and top-level wiring functions is acceptable — that is where it
   legitimately lives, read once from `os.environ`. Configuration in business logic,
   data access, and library code is not. The goal is globals only where wiring
   happens.
3. **Don't "fix" the globals that aren't broken.** `logging.getLogger(__name__)`,
   constants, enums, and exception classes stay. Spending iterations injecting a
   logger is ceremony, not rejection.
