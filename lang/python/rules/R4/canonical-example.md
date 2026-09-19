From the Port case (`R1-primitive-obsession.md` carries the full three-stage study).
After extraction, `Port`/`Ports`/`first_named`/`first` say nothing about Kubernetes
or Weka: juicy (range validation, collection queries) and domain-generic → rung 3,
a shared `networking` package. The feature keeps a two-line storified policy method:

```python
def management_port(self) -> networking.Port | None:
    return self.ports.first_named(WEKA_API_PORT) or self.ports.first()
```

Only the domain-generic parts were promoted: the `WEKA_API_PORT` constant is feature
policy and stays in the feature. A shared package that knows one feature's port names
is not shared vocabulary — it is leaked policy.

The rung-1 contrast — a trivial helper that stays put:

```python
def _parse_k3s_argument(arg: str) -> tuple[str, str] | None:
    """One caller, no domain vocabulary, no rules of its own: stays private."""
    key, sep, value = arg.partition("=")
    return (key, value) if sep else None
```

There is no urge to test this directly — and that absence is the point: the promotion
signal (below) never fires. The rungs in Python: rung 1 is a leading-underscore name
in the same module, covered through the module's public API; rung 2 is the feature
package (a directory with `__init__.py` that re-exports the public names in
`__all__`); rung 3 is a shared package under the project's source root, named for a
domain vocabulary. There is no `internal/` convention — the underscore and `__all__`
carry visibility.
