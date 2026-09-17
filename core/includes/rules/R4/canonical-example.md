From the Port case (`R1-primitive-obsession.md` carries the full three-stage study).
After extraction, `Port`/`Ports`/`firstNamed`/`first` say nothing about Kubernetes or
Weka: juicy (range validation, collection queries) and domain-generic → rung 3, a
shared `networking` package. The feature keeps a two-line storified policy method:

```text
kubeService.managementPort():
    return self.ports.firstNamed(managementPortName) or self.ports.first()
```

Only the domain-generic parts were promoted: the `"weka-api"` constant is feature
policy and stays in the feature. A shared package that knows one feature's port names
is not shared vocabulary — it is leaked policy.

The rung-1 contrast — a trivial helper that stays put:

```text
# Trivial: one caller, no domain vocabulary, no rules of its own.
# Stays {{.Unexported}}; covered through the parent's public API.
parseArgument(arg):
    key, sep, value = arg.partition("=")
    if sep is empty: return absent
    return (key, value)
```

There is no urge to test this directly — and that absence is the point: the promotion
signal (below) never fires.
