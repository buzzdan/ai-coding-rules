`Grants` guarantees a non-empty, deduplicated permission set — enforced in the
constructor per R2.

### Before

```go
type Grants struct {
    perms []Permission // constructor guarantees: non-empty, deduplicated
}

func ParseGrants(raw []string) (Grants, error) {
    perms, err := dedupeAndValidate(raw)
    if err != nil {
        return Grants{}, err
    }
    return Grants{perms: perms}, nil
}

// ❌ returns a mutable alias into the validated state
func (g Grants) All() []Permission { return g.perms }
```

```go
// ❌ a distant caller, months later
perms := user.Grants.All()
sort.Slice(perms, func(i, j int) bool { ... }) // reorders internal state
perms[0] = PermissionNone                       // corrupts it — no method called
```

The constructor's guarantee is now a lie, and nothing in `grants.go` changed. The
write that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```go
// ❌ constructor stores the caller's slice
func NewSchedule(days []Weekday) (Schedule, error) {
    if len(days) == 0 {
        return Schedule{}, errors.New("schedule: no days")
    }
    return Schedule{days: days}, nil
}

days := []Weekday{Monday}
s, _ := NewSchedule(days)
days[0] = Sunday // s just changed. NewSchedule's validation saw a different value.
```

### After

```go
func ParseGrants(raw []string) (Grants, error) {
    perms, err := dedupeAndValidate(raw) // freshly built here — no shared alias
    if err != nil {
        return Grants{}, err
    }
    return Grants{perms: perms}, nil
}

// All returns a copy; callers may do anything with it.
func (g Grants) All() []Permission { return slices.Clone(g.perms) }

// Or expose iteration instead of the collection (no copy, no alias).
// iter.Seq / slices.Values require Go 1.23+; on older Go, a walker method
// (func (g Grants) Each(yield func(Permission) bool)) is the same move.
func (g Grants) Each() iter.Seq[Permission] { return slices.Values(g.perms) }

func NewSchedule(days []Weekday) (Schedule, error) {
    if len(days) == 0 {
        return Schedule{}, errors.New("schedule: no days")
    }
    return Schedule{days: slices.Clone(days)}, nil // copy on the way in
}
```

Now every mutation path runs through the type. The caller's `sort.Slice` reorders its
own copy; the caller's `days[0] = Sunday` changes a slice `Schedule` no longer
shares. The invariant has exactly one set of doors, and the constructor guards all of
them.
