```text
# ❌ one table, a flag, and a branch inside the case
testParsePort():
    cases = [("valid", 14000, expectFailure: false), ("zero", 0, expectFailure: true)]
    for each case in cases:
        result = networking.parsePort("x", case.number)
        if case.expectFailure: assert result failed
        else:                  assert result succeeded

# ✅ success and error tables apart, every row a named case, complexity 1 per case
testParsePort_success():                                     # imported as a consumer would
    for each (name, number) in [("plain", 14000), ("edge", 65535)]:
        case name:
            assert networking.parsePort("x", number) succeeded

testParsePort_error():
    for each (name, number) in [("zero", 0), ("above range", 70000)]:
        case name:
            assert networking.parsePort("x", number) failed
```

> **Spelling:** the table is the language's parametrized-test form, a list of named
> cases, a parametrize decorator, a data provider, and every row is registered under
> its name (a subtest, a parameter id) so a failure names its case. No fixed pause:
> wait on an event, a channel, a future or a timeout. Orchestrators are tested by
> wiring their real collaborators over a temp directory, an in-process fake server or
> an embedded database.
