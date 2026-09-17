Compact excerpt from the Port case (`R1-primitive-obsession.md` has the full
three-stage study — extraction, placement, testing). The shape is the same in every
language; how the constructor reports a failure — an error result, an exception —
follows the repository's.

```text
Port                         # cannot exist out of range — the constructor is the only entry
    name, number             # {{.Unexported}}: no literal builds a Port around the check
parsePort(name, number):
    if number <= 0 or number > 65535: fail "port <name>: <number> out of range 1-65535"
    return Port(name, number)
```

Before this type existed, the range check was duplicated across two loops at the use
site. After, there is no `isValid()` and no re-check anywhere: the concept of a
maybe-invalid port is deleted from downstream logic, not relocated.

The same pattern for a composed object — validate dependencies once, then trust:

```text
# ❌ every method defends
UserService
    repo                     # public, might be missing
UserService.createUser(user):
    if repo is {{.Nil}}: fail "repo is missing"     # repeated in every method; forget one → crash
    return repo.save(user)

# ✅ constructor validates once; methods trust the receiver
UserService
    repo                     # {{.Unexported}}
newUserService(repo):
    if repo is {{.Nil}}: fail "repo is required"
    return UserService(repo)
UserService.createUser(user):
    return repo.save(user)   # no checks — an invalid service cannot exist
```
