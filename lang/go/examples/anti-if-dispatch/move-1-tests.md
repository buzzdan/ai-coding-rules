Each variant unit-tests as a leaf with literals — no `Alert` construction, no
switch-driving:

```go
func TestSlack_ValidRecipient(t *testing.T) {
    assert.True(t, alert.Slack{}.ValidRecipient("#oncall"))
    assert.False(t, alert.Slack{}.ValidRecipient("oncall"))
}

func TestParseChannel_Unknown(t *testing.T) {
    _, err := alert.ParseChannel("carrier-pigeon")
    require.Error(t, err)
}
```

The drift bug (`pagerduty` missing from `validRecipient`) can no longer be written:
there is no second place to forget.
