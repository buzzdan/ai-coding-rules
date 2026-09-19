### Before — feature scattered across layers

```
src/app/
├── models/
│   └── rotator.py
├── services/
│   └── rotator_service.py
├── repositories/
│   └── rotator_repository.py
└── handlers/
    └── rotator_handler.py
```

Changing rotation policy touches four directories; the `services` package's surface
is the union of every feature's service; `models` and `services` are role names that
describe no domain at all.

### After — one slice, roles inside

```
src/app/
└── rotator/
    ├── __init__.py      # the slice's public names, in __all__
    ├── rotator.py       # domain type
    ├── parser.py        # role: parsing
    ├── handler.py       # role: HTTP
    ├── repository.py    # role: persistence
    └── test_rotator.py  # or tests/rotator/ — whichever the repository uses
```

The whole feature is one `ls`. Each type with logic sits in its own module named after
the type; the package name is the feature's domain word, and module names carry the
roles. `__init__.py` is the slice's front door: it re-exports what other slices may
import and nothing else, so the module split inside the package is private to it.
