```go
// ❌ before: if-chain in the middle of business logic
func render(a Alert, format string) string {
    if format == "json" {
        return renderJSON(a)
    }
    if format == "text" {
        return renderText(a)
    }
    return renderMarkdown(a) // silent default — is "yaml" markdown? nobody decided
}
```
