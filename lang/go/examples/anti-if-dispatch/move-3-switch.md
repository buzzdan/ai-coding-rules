```go
// alert/severity.go — the ONLY site that inspects Severity
func (s Severity) Color() string {
    switch s {
    case SeverityInfo:
        return "blue"
    case SeverityWarning:
        return "yellow"
    case SeverityCritical:
        return "red"
    }
    return ""
}
```
