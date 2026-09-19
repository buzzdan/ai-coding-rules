```python
    def color(self) -> str:
        match self:
            case Severity.INFO:
                return "blue"
            case Severity.WARNING:
                return "yellow"
            case Severity.CRITICAL:
                return "red"
            case _:
                assert_never(self)  # exhaustive: mypy fails when a Severity is added unhandled
```

The `case _: assert_never(self)` arm is not an unknown-kind default — it is the
completeness proof. mypy narrows `self` through the arms; if a member is left
unhandled, the type reaching `assert_never` is not `Never` and the check fails at
this `match`. Adding `Severity.FATAL` now fails `mypy` instead of falling through to
`""`. That is the whole benefit, at none of the cost. (ruff has no exhaustiveness
rule; without the `assert_never` arm the `match` is incomplete silently.)
