```python
# ❌ before: if-chain in the middle of business logic
def render(a: Alert, fmt: str) -> str:
    if fmt == "json":
        return render_json(a)
    if fmt == "text":
        return render_text(a)
    return render_markdown(a)  # silent default — is "yaml" markdown? nobody decided
```
