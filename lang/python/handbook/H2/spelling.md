
> **In Python:** `except Exception:` swallows the bug with the failure (ruff `BLE001`);
> inside an `except`, raise with `from err` so the chain is kept (`B904`); exception
> classes are defined once per package, named for what went wrong.

**Review:** Does any `except` catch `Exception`, re-raise without `from`, or both log and raise?
