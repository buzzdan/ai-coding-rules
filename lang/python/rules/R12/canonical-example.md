`Grants` guarantees a non-empty, deduplicated permission set — enforced in the
constructor per R2.

### Before

```python
class Grants:
    def __init__(self, raw: Iterable[str]) -> None:
        self._perms: list[Permission] = dedupe_and_validate(raw)   # non-empty, deduplicated

    def all(self) -> list[Permission]:      # ❌ returns a mutable alias into the validated state
        return self._perms
```

```python
# ❌ a distant caller, months later
perms = user.grants.all()
perms.sort(key=lambda p: p.weight)          # reorders internal state
perms[0] = Permission.NONE                  # corrupts it — no method called
```

The constructor's guarantee is now a lie, and nothing in `grants.py` changed. The
write that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```python
# ❌ constructor stores the caller's list
class Schedule:
    def __init__(self, days: list[Weekday]) -> None:
        if not days:
            raise ValueError("schedule: no days")
        self._days = days


days = [Weekday.MONDAY]
s = Schedule(days)
days[0] = Weekday.SUNDAY    # s just changed. Schedule's validation saw a different value.
```

### After

```python
@dataclass(frozen=True, slots=True)
class Grants:
    _perms: tuple[Permission, ...]

    @classmethod
    def parse(cls, raw: Iterable[str]) -> "Grants":
        return cls(tuple(dedupe_and_validate(raw)))     # freshly built here — no shared alias

    def all(self) -> tuple[Permission, ...]:            # a tuple cannot be sorted or assigned into
        return self._perms

    def __iter__(self) -> Iterator[Permission]:         # or expose iteration: no copy, no alias
        return iter(self._perms)


@dataclass(frozen=True, slots=True)
class Schedule:
    _days: tuple[Weekday, ...]

    @classmethod
    def parse(cls, days: Iterable[Weekday]) -> "Schedule":
        items = tuple(days)                              # copy on the way in
        if not items:
            raise ValueError("schedule: no days")
        return cls(items)
```

Now every mutation path runs through the type. The caller's `sorted(grants.all())`
sorts its own list; the caller's `days[0] = Weekday.SUNDAY` changes a list `Schedule`
no longer shares. The Python spellings of the two edges: `tuple(...)` and
`frozenset(...)` on the way in, a tuple, `types.MappingProxyType` or an iterator on
the way out, and `frozen=True` so no assignment slips in between. The invariant has
exactly one set of doors, and the constructor guards all of them.
