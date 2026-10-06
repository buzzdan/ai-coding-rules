```text
# ❌ every method re-asks; a literal Retention(-1) is legal
Retention
    days                          # public: any value gets in
Retention.cutoff(now):
    if self.days <= 0 or self.days > 365: self.days = 30
    return now minus self.days days

# ✅ one constructor, hidden fields, methods trust the receiver
Retention
    days                          # hidden: no literal builds a Retention around the check
parseRetention(days):
    if days <= 0 or days > 365: fail "retention <days>: want 1-365"
    return Retention(days)
Retention.cutoff(now):
    return now minus self.days days
```

> **Spelling:** hidden fields are the language's visibility form: a private field, a
> leading underscore, a module that exports the constructor and not the fields. How
> the constructor fails, an error result or an exception, follows the repository. The
> optional-collaborator stance is opinionated in every language: a missing
> destination is a Null Object passed by name, a real implementation that discards,
> never a `{{.Nil}}` the methods guard, so `newReporter(discardSink())` never branches
> on it.
