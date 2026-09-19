```python
class Format(StrEnum):
    JSON = "json"
    TEXT = "text"
    MARKDOWN = "markdown"


RENDERERS: dict[Format, Callable[[Alert], str]] = {
    Format.JSON: render_json,
    Format.TEXT: render_text,
    Format.MARKDOWN: render_markdown,
}


def parse_format(raw: str) -> Format:
    return Format(raw)  # ValueError for "yaml", here and nowhere else


def render(a: Alert, f: Format) -> str:
    return RENDERERS[f](a)
```

The lookup *is* the dispatch; the "is this a known format" question is asked once, in
`parse_format`, at the boundary, and `RENDERERS[f]` never needs a `.get` default
because a `Format` that exists is a key that exists. The silent markdown default — an
undecided decision — became an explicit error. (The dict is module-level immutable
data, the sanctioned shape under R8; naming the enum is R1's "Name enum strings"
move.)
