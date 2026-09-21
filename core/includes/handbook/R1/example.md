```text
# ❌ the rule lives at the call site, twice, and 0 means "none"
managementPort(service):
    for each port in service.ports:
        if port.name == "weka-api" and port.number > 0 and port.number <= 65535:
            return port.number
    for each port in service.ports:
        if port.number > 0 and port.number <= 65535:
            return port.number
    return 0

# ✅ a Port cannot exist out of range; "first valid" collapses to "first"
parsePort(name, number):          # the Port, or a failure naming the port and the range
    if number <= 0 or number > 65535: fail "port <name>: <number> out of range 1-65535"
    return Port(name, number)
Ports.firstNamed(name):           # the Port, or absent
Ports.first():                    # the Port, or absent
```

> **Spelling:** "the value or a failure" is an error result, an exception or a result
> type; "the value or absent" is an optional type, a declared nullable or a
> found-flag pair, whichever the repository's language and its own code already use.
> A `0`, `""` or `{{.Nil}}` returned where the signature promises a `Port` is a
> sentinel in every language. A wrapper whose only method unwraps the integer scores
> zero on the scorecard: keep the integer.
