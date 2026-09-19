Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing):

```python
@dataclass(frozen=True, slots=True)
class Port:
    """A named, validated service port; it cannot exist out of range."""

    name: str
    number: int

    def __post_init__(self) -> None:
        if not 0 < self.number <= 65535:
            raise ValueError(f"port {self.name!r}: {self.number} out of range 1-65535")
```

This is the Python self-validating type: a frozen dataclass whose `__post_init__`
runs on every construction, literal or not. Its fields are public and read-only,
which is what "the constructor is the only entry" means here — there is no literal
that skips the check and no assignment after it. Before this type existed,
`0 < p.port <= 65535` was duplicated across two loops at the use site. After, there
is no `is_valid()` and no re-check anywhere: the concept of a maybe-invalid port is
deleted from downstream logic, not relocated. A plain mutable dataclass with the
same two fields and no `__post_init__` is the hole this rule hunts: every caller can
build an invalid `Port`, and every method must defend.

The same pattern for a composed object — validate dependencies once, then trust:

```python
# ❌ every method defends
class UserService:
    def __init__(self, repo: Repository | None) -> None:
        self.repo = repo  # public, might be None

    def create_user(self, user: User) -> None:
        if self.repo is None:  # repeated in every method; forget one → AttributeError
            raise RuntimeError("repo is None")
        self.repo.save(user)


# ✅ constructor validates once; methods trust the instance
class UserService:
    def __init__(self, repo: Repository) -> None:
        if repo is None:  # only an untyped caller can get here; mypy rejects it first
            raise TypeError("UserService: repo is required")
        self._repo = repo

    def create_user(self, user: User) -> None:
        self._repo.save(user)  # no checks — an invalid service cannot exist
```

Where the value is built from unstructured input — a config string, a wire dict —
the constructor is a `parse` classmethod that normalises and then constructs, so
`__post_init__` sees typed fields:

```python
    @classmethod
    def parse(cls, raw: str) -> "Port":
        name, _, number = raw.partition(":")
        return cls(name, int(number))
```

At a boundary that already uses pydantic, a `BaseModel` with `frozen=True` and field
validators is the same type; inside the domain the dataclass is enough, and
`model_construct()` anywhere outside a test is a path around the constructor.
