The shape below is the same in every language; the Go plugin's version is the real
pull request it was taken from. A service wraps a wire-level description of a network
service and must pick the management port: prefer the port named `weka-api`, else fall
back to the first valid port.

### Before

```text
managementPort(service):
    for each port in service.ports:
        if port.name == "weka-api" and port.number > 0 and port.number <= 65535:
            return port.number
    for each port in service.ports:
        if port.number > 0 and port.number <= 65535:
            return port.number
    return 0
```

Four defects in twelve lines:

- The validity rule `> 0 and <= 65535` is duplicated across the two loops — two
  copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic lives on a wire DTO, so it is testable only by constructing a whole
  service object around it.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none".

### Stage 1 — self-validating types with constructors

```text
Port                         # fields are {{.Unexported}}; the constructor is the only way in
    name, number
parsePort(name, number):     # the value, or a failure that names the port and the range
    if number <= 0 or number > 65535: fail "port <name>: <number> out of range 1-65535"
    return Port(name, number)

Ports                        # a collection of valid Port values
parsePorts(wire):            # drops invalid wire entries — a documented decision that
    for each entry in wire:  # mirrors the original skip-and-fall-back behavior: an
        parsePort(...) ok?   # invalid port was never chosen before; now it never exists
            keep it
Ports.firstNamed(name):      # the port, or an explicit "absent"
Ports.first():               # the port, or an explicit "absent"
Ports.management():          # prefers "weka-api", else the first valid port
    return firstNamed("weka-api") or first()
```

The payoff, stated plainly: notice what was **not** written. There is no `isValid()`
method and no validity loop anywhere. Self-validation does not move the range check
somewhere tidier — it **deletes the concept of a maybe-invalid port from downstream
logic**. Every `Port` inside a `Ports` is valid by construction, so "find the first
valid port" collapses to "find the first port". And `management()` returns the port
or an explicit absence — never a `0` sentinel that smuggles validity back in-band.
How "the value or a failure" and "the value or absent" are spelled — an error
result, an exception, an optional type — follows the repository's language.

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `firstNamed` and `first` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to a shared `networking` package
(rung 3 of `R4-helper-placement.md`). The wire adapter `parsePorts` knows the DTO, so
it stays with the feature. The feature policy stays home as a two-line storified
method: `management()` becomes `firstNamed(managementPortName) or first()` on the
service, with the `"weka-api"` constant beside it.

Teaching point: **promote only the domain-generic parts.** The `"weka-api"` constant
is feature policy and stays in the feature — a shared package that knows one
feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `managementPort` meant constructing a whole service fixture —
building a wire object to check a range predicate. After, the logic is a leaf and its
rung-0 unit tests (the composition ladder's bottom rung — see @testing) are literal
lists of ports: build two ports through `parsePort`, put them in a `Ports`, assert
which one `firstNamed` returns. No big-object construction.

### The opposite failure: don't over-extract

```text
ReplicaCount                 # ❌ ceremony, not a type: no rule, no behavior —
    wraps one integer        #    the only method unwraps it
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the plain integer; if you want a name, a
well-named variable or an {{.Unexported}} helper in the same package is the whole
answer (`R4-helper-placement.md`, rung 1).
