
> **In Python:** `except Exception:` swallows the bug with the failure (ruff `BLE001`);
> the one place it belongs is the process boundary, a worker loop or request handler
> that logs with `logger.exception` and does not re-raise. Inside an `except`, raise
> with `from err`, or `from None` when the cause is deliberately hidden; `B904` wants
> one or the other. Inspect with `except SpecificError`, never `str(e)`. Exception
> classes are defined once per package, named for what went wrong, and in `__all__`
> only when a caller catches them.

**Review:** Does any `except` catch `Exception`, `BaseException` or nothing at all away from the process boundary, re-raise without `from`, both log and raise, or inspect a message string?
