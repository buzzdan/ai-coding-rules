```python
# ❌ returns a mutable alias into validated state; a distant caller sorts it in place
class Grants:
    def all(self) -> list[Permission]:
        return self._perms


# ✅ copy on the way in; hand out a view, not the storage
@dataclass(frozen=True, slots=True)
class Grants:
    _perms: tuple[Permission, ...]

    @classmethod
    def of(cls, raw: Iterable[str]) -> "Grants":
        return cls(tuple(dedupe_and_validate(raw)))

    def __iter__(self) -> Iterator[Permission]:
        return iter(self._perms)
```

> **In Python:** `frozen=True` freezes the binding, not the value: a frozen dataclass
> holding a `list` is mutable through that list. Store tuples and mapping proxies,
> or copy on the way out. A mutable default in a signature (ruff `B006`) is this
> rule's most common form.
