# R5 — Vertical Slice Architecture

## Principle

Group code by feature and role, not by technical layer: bad — `domain/rotator`,
`services/rotator`; good — `rotator/parser.<ext>`, `rotator/handler.<ext>`. All code for a
feature lives in one package, internally separated by role within it. Package names
are flatcase domain vocabulary — never a layer or role name.

## Why

Horizontal layering scatters one feature across `handlers/`, `services/`,
`domain/` — understanding or changing the feature means touching N directories, and
every feature couples to every other through the shared layer packages. Layer
packages also accrete: `services/` grows a file per feature until nobody owns its
API. A vertical slice colocates the whole behavior: it can be read top to bottom,
extracted or deleted as a unit, and worked on in parallel without cross-team merge
conflicts. The slice's internal files are named by role (`parser.<ext>`, `handler.<ext>`,
`repository.<ext>`), so the layer separation survives — inside the feature boundary
instead of above it.

## Canonical example

### Before — feature scattered across layers

```
project/
├── domain/
│   └── rotator.<ext>
├── services/
│   └── rotator_service.<ext>
├── repository/
│   └── rotator_repository.<ext>
└── handlers/
    └── rotator_handler.<ext>
```

Changing rotation policy touches four directories; the `services` package's API is
the union of every feature's service; `domain` and `services` are role names that
describe no domain at all.

### After — one slice, roles inside

```
project/
└── rotator/
    ├── rotator.<ext>       # domain type
    ├── parser.<ext>        # role: parsing
    ├── handler.<ext>       # role: HTTP
    ├── repository.<ext>    # role: persistence
    └── rotator<test-file suffix>
```

The whole feature is one `ls`. Each type with logic sits in its own file named after
the type; the package name is the feature's domain word, and file names carry the
roles. The directory is a package, module or namespace — whatever the language calls
one unit of code with its own public surface.

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

Separate by role and responsibility within the feature package: `parser.<ext>`,
`handler.<ext>`, `repository.<ext>`. Types with logic get their own file named after the
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
directory into it (renamed by role: `rotator_service.<ext>` → `service.<ext>`), fix
imports, delete the emptied layer files. **Never mix**: `rotator/service.<ext>` and
`services/rotator_service.<ext>` must not coexist for the same feature.

### Advisory posture

Architecture findings advise, they don't block: a team may accept horizontal
layering for real reasons (time constraints, an agreed convention). The finding's
job is evidence and a migration path, not a veto. Role-named packages, by contrast,
are never acceptable (`R4-helper-placement.md`).

## Fix pattern

- **Slice out a feature**: apply the migration template above — one feature per
  iteration, each iteration a working, deployable state.
- **Rename layer files by role during the move**: `<feature>_service.<ext>` →
  `service.<ext>`; the package name now carries the feature.
- **Split a generic package by owner**: for each symbol in a `util`/`common`
  package, find its real feature or domain vocabulary and move it there
  (`R4-helper-placement.md` decides which rung).
- Forward design of a new slice's packages and types: @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Is any package or module named after a layer or role?**
   Detection: list the directories that hold source files and match their names
   against `util`, `utils`, `helpers`, `common`, `shared`, `misc`, `domain`,
   `services`, `handlers`, `models`, `repositories`; where the language declares the
   package name inside the file, search the declarations for the same words.
   Violation: any hit — the package describes a role, not a domain.

2. **Is one feature's code spread across ≥2 layer directories?**
   Detection: for each feature noun in the diff, list the directories of the source
   files that mention it and count the distinct layer-named directories among them.
   Violation: the same feature living in `handlers/` and `services/` (etc.) — it is
   horizontally scattered.

3. **Does the diff add a new file into a layer directory instead of a slice?**
   Detection: list the files the diff adds (`git diff --name-only --diff-filter=A`)
   and check each new path's directory against the layer names above.
   Violation: new feature code placed in a layer directory — new code is always
   sliced, even mid-migration.

4. **Do both shapes coexist for one feature?**
   Detection: list `<feature>/`, `services/` and `handlers/` and look for the
   feature's name in more than one of them.
   Violation: `<feature>/service.<ext>` alongside
   `services/<feature>_service.<ext>` — the never-mix rule; finish the feature's
   migration in this change or don't start it.

5. **Is a mixed-architecture repo missing its migration plan?**
   Detection: layer directories exist alongside slices, and
   `docs/architecture/vertical-slice-migration.md` does not.
   Violation: mixed state with no documented strategy/progress — add the template
   above.
