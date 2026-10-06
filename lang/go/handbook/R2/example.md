```go
// ❌ every method re-asks; a literal Retention{Days: -1} is legal
type Retention struct{ Days int }

func (r Retention) Cutoff(now time.Time) time.Time {
    if r.Days <= 0 || r.Days > 365 {
        r.Days = 30
    }
    return now.AddDate(0, 0, -r.Days)
}

// ✅ unexported field, one constructor, methods trust the receiver
type Retention struct{ days int }

func ParseRetention(days int) (Retention, error) {
    if days <= 0 || days > 365 {
        return Retention{}, fmt.Errorf("retention %d: want 1-365", days)
    }
    return Retention{days: days}, nil
}

func (r Retention) Cutoff(now time.Time) time.Time { return now.AddDate(0, 0, -r.days) }
```

> **In Go (opinionated):** an optional collaborator is a Null Object the caller passes by name, never
> a `nil` the methods guard: `io.Discard` is the standard library's, and
> `NewReporter(DiscardSink())` never branches on a missing destination. Never pass
> `nil` into a function, so the function never checks for it.
