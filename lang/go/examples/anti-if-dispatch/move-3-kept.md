```go
func (s Severity) Color() string {
    switch s { // exhaustive: linter fails the build when a Severity is added unhandled
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

with `exhaustive` enabled in `.golangci.yaml`. Now the linter provides what dispatch
would have: adding `SeverityFatal` fails the build at this switch instead of falling
through to `""`. That is the whole benefit, at none of the cost.
