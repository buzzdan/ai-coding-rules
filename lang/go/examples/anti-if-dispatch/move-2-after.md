```go
type Format string

const (
    FormatJSON     Format = "json"
    FormatText     Format = "text"
    FormatMarkdown Format = "markdown"
)

var renderers = map[Format]func(Alert) string{
    FormatJSON:     renderJSON,
    FormatText:     renderText,
    FormatMarkdown: renderMarkdown,
}

func ParseFormat(raw string) (Format, error) {
    if _, ok := renderers[Format(raw)]; !ok {
        return "", fmt.Errorf("unknown format %q", raw)
    }
    return Format(raw), nil
}

func render(a Alert, f Format) string { return renderers[f](a) }
```

The lookup *is* the dispatch; the comma-ok check lives once, in `ParseFormat`, at the
boundary. The silent markdown default — an undecided decision — became an explicit
error. (The map is package-level immutable data, the sanctioned shape under R8;
naming the enum is R1's "Name enum strings" move.)
