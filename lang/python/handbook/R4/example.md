```python
# ❌ imported by the test through its private name, so it stays where it should not
from app.k3s._args import _parse_k3s_argument

# ✅ rung 1: one caller, no vocabulary of its own;
#    covered through the public API that calls it
def _parse_k3s_argument(arg: str) -> tuple[str, str] | None: ...

# ✅ rung 3: networking vocabulary with several callers → its own package,
#    named for the domain
from app.networking import Port, Ports
```

> **In Python:** the leading underscore is a convention, not a wall, so a test *can*
> import `_parse_row`. That it can is not a reason it should: the urge is a placement
> signal, and the helper wants its own module with a public name. Rung 2 is the
> feature package, whose `__init__.py` re-exports the slice's public names and lists
> them in `__all__`; rung 3 a shared package under the source root. There is no
> `internal/`; the underscore and `__all__` carry visibility.
