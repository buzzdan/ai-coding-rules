```python
# ❌ public class with no docstring; the comment narrates WHAT the loop does
class Policy:
    def do(self, op: Callable[[], None]) -> None:
        # loop over attempts and back off between failures
        for attempt in range(1, self._max_attempts + 1): ...


# ✅ the summary line states the contract, the body says why,
#    the doc points down at code and code points up at the doc
class Policy:
    """Retry an operation with full-jitter backoff.

    Full jitter over exponential backoff: it spreads retries after an outage so a
    fleet does not thunder back in lockstep. Decision and measurements:
    docs/retry-policy.md.
    """
```

> **In Python:** the PEP 257 summary line states the contract and is never a
> restatement finding; the body earns its lines by saying *why*, and the `Args`,
> `Returns` and `Raises` sections are free. Where ruff's `D` rules require a
> docstring, a WHAT-docstring is rewritten, not deleted; a `_private` name carries no
> `D` obligation, so a WHAT-docstring on one is deleted.
