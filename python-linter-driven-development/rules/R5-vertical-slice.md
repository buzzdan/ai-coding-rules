# R5 — Vertical Slice Architecture

## Principle

Group code by feature and role, not by technical layer: bad — `domain/rotator`,
`services/rotator`; good — `rotator/parser.py`, `rotator/handler.py`. All code for a
feature lives in one package, internally separated by role within it. Package names
are flatcase domain vocabulary — never a layer or role name.

## Why

Horizontal layering scatters one feature across `handlers/`, `services/`,
`domain/` — understanding or changing the feature means touching N directories, and
every feature couples to every other through the shared layer packages. Layer
packages also accrete: `services/` grows a file per feature until nobody owns its
API. A vertical slice colocates the whole behavior: it can be read top to bottom,
extracted or deleted as a unit, and worked on in parallel without cross-team merge
conflicts. The slice's internal files are named by role (`parser.py`, `handler.py`,
`repository.py`), so the layer separation survives — inside the feature boundary
instead of above it.

## Canonical example

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

## Design guidance

### Package naming method

- **Flatcase**: `wekatrace`, never `wekaTrace` or `weka_trace`.
- **Domain vocabulary, not a single noun**: a package name should have room for
  siblings — `networking` can grow ports, addresses, CIDRs; `kubeport` is a
  vocabulary of one. (This is rung 3 of `R4-helper-placement.md`; the placement ladder
  lives there — cite it, don't re-derive it.)
- **Never a role name**: `util`, `utils`, `helpers`, `common`, `shared`, `misc`,
  `domain`, `services` — a role describes no domain and becomes a dumping ground.
- **Avoid stdlib/common-library collisions**: `metrics` forces aliases on every
  importer; prefer a specific name like `wekametrics`.
- **Ergonomic symbols**: the package provides context — `rotator.Parser`, not
  `rotator.RotatorParser`; `version.Info`, not `version.VersionInfo`.

### Inside the slice

Separate by role and responsibility within the feature package: `parser.py`,
`handler.py`, `repository.py`. Types with logic get their own file named after the
type. When a slice grows a juicy sub-concern, it becomes a feature sub-package
(rung 2 of `R4-helper-placement.md`); when a concern turns out to be domain-generic,
it promotes to a shared domain package (rung 3) — placement is R4's decision.

### Migration template

New features are always built as vertical slices. Existing layer-structured code
migrates incrementally — never as a big bang, and never leaving one feature in both
shapes. Track the migration in `docs/architecture/vertical-slice-migration.md`:

```markdown
# Vertical Slice Migration Plan
## Current State: [horizontal/mixed description]
## Target: Vertical slices in internal/[feature]/
## Strategy: New features vertical, refactor existing incrementally
## Progress: [x] rotator (this PR), [ ] health, [ ] verification
```

Per feature: create `internal/<feature>/`, move the feature's files from each layer
directory into it (renamed by role: `rotator_service.py` → `service.py`), fix
imports, delete the emptied layer files. **Never mix**: `rotator/service.py` and
`services/rotator_service.py` must not coexist for the same feature.

### Advisory posture

Architecture findings advise, they don't block: a team may accept horizontal
layering for real reasons (time constraints, an agreed convention). The finding's
job is evidence and a migration path, not a veto. Role-named packages, by contrast,
are never acceptable (`R4-helper-placement.md`).

## Fix pattern

- **Slice out a feature**: apply the migration template above — one feature per
  iteration, each iteration a working, deployable state.
- **Rename layer files by role during the move**: `<feature>_service.py` →
  `service.py`; the package name now carries the feature.
- **Split a generic package by owner**: for each symbol in a `util`/`common`
  package, find its real feature or domain vocabulary and move it there
  (`R4-helper-placement.md` decides which rung).
- Forward design of a new slice's packages and types: @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Is any package named after a layer or role?**
   Detection: `find . -type d \( -name 'util*' -o -name 'helpers' -o -name 'common' -o -name 'shared' -o -name 'misc' -o -name 'domain' -o -name 'services' -o -name 'handlers' -o -name 'models' -o -name 'repositories' \) -not -path '*/.venv/*'`
   and the module form
   `find . \( -name 'utils.py' -o -name 'helpers.py' -o -name 'common.py' -o -name 'models.py' -o -name 'services.py' -o -name 'handlers.py' \) -not -path '*/.venv/*'`.
   Python has no `package` line; a layer package announces itself in the docstring
   of its `__init__.py`, so read those too.
   Violation: any hit — the package describes a role, not a domain.

2. **Is one feature's code spread across ≥2 layer directories?**
   Detection: for each feature noun in the diff,
   `grep -rli '<feature>' --include='*.py' . | xargs -n1 dirname | sort -u` — count
   distinct layer-named directories.
   Violation: the same feature living in `handlers/` and `services/` (etc.) — it is
   horizontally scattered.

3. **Does the diff add a new file into a layer directory instead of a slice?**
   Detection: `git diff --name-only --diff-filter=A -- '*.py'` — check each new
   path's directory against the layer names above.
   Violation: new feature code placed in a layer directory — new code is always
   sliced, even mid-migration.

4. **Do both shapes coexist for one feature?**
   Detection: `ls <feature>/ services/ handlers/ 2>/dev/null | grep -i <feature>`
   Violation: `<feature>/service.py` alongside `services/<feature>_service.py` —
   the never-mix rule; finish the feature's migration in this change or don't start
   it.

5. **Is a mixed-architecture repo missing its migration plan?**
   Detection: layer directories exist alongside slices, and
   `ls docs/architecture/vertical-slice-migration.md` fails.
   Violation: mixed state with no documented strategy/progress — add the template
   above.
