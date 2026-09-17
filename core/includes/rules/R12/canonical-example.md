`Grants` guarantees a non-empty, deduplicated permission set — enforced in the
constructor per R2.

### Before

```text
Grants
    perms                    # constructor guarantees: non-empty, deduplicated
parseGrants(raw):
    perms = dedupeAndValidate(raw)     # fails → the failure
    return Grants(perms)
Grants.all():
    return self.perms        # ❌ returns a mutable alias into the validated state
```

```text
# ❌ a distant caller, months later
perms = user.grants.all()
perms.sort(...)              # reorders internal state
perms[0] = PermissionNone    # corrupts it — no method called
```

The constructor's guarantee is now a lie, and nothing in the grants file changed. The
write that broke the invariant lives in a file the type's owner has never seen; no
detection aimed at the type itself can find it. The backward version is just as
silent:

```text
# ❌ constructor stores the caller's list
newSchedule(days):
    if days is empty: fail "schedule: no days"
    return Schedule(days)

days = [Monday]
schedule = newSchedule(days)
days[0] = Sunday             # schedule just changed. newSchedule's validation saw a different value.
```

### After

```text
parseGrants(raw):
    perms = dedupeAndValidate(raw)     # freshly built here — no shared alias
    return Grants(perms)

Grants.all():
    return copy of self.perms          # callers may do anything with it

Grants.each():
    yield each permission              # or expose iteration instead of the collection
                                       # (no copy, no alias)

newSchedule(days):
    if days is empty: fail "schedule: no days"
    return Schedule(copy of days)      # copy on the way in
```

Now every mutation path runs through the type. The caller's sort reorders its own
copy; the caller's `days[0] = Sunday` changes a list `Schedule` no longer shares. The
invariant has exactly one set of doors, and the constructor guards all of them. In a
language with immutable collections, storing a frozen copy is the same move with the
copy made once.
