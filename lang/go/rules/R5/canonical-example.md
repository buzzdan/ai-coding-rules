### Before — feature scattered across layers

```
project/
├── domain/
│   └── rotator.go
├── services/
│   └── rotator_service.go
├── repository/
│   └── rotator_repository.go
└── handlers/
    └── rotator_handler.go
```

Changing rotation policy touches four directories; the `services` package's API is
the union of every feature's service; `domain` and `services` are role names that
describe no domain at all.

### After — one slice, roles inside

```
project/
└── rotator/
    ├── rotator.go       # domain type
    ├── parser.go        # role: parsing
    ├── handler.go       # role: HTTP
    ├── repository.go    # role: persistence
    └── rotator_test.go
```

The whole feature is one `ls`. Each type with logic sits in its own file named after
the type; the package name is the feature's domain word, and file names carry the
roles.
