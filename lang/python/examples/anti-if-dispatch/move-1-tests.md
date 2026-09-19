Each variant unit-tests as a leaf with literals — no `Alert` construction, no
switch-driving:

```python
def test_slack_valid_recipient() -> None:
    assert alert.Slack().valid_recipient("#oncall")
    assert not alert.Slack().valid_recipient("oncall")


def test_parse_channel_rejects_unknown() -> None:
    with pytest.raises(ValueError):
        alert.parse_channel("carrier-pigeon")


def test_every_channel_name_has_a_channel() -> None:
    assert set(alert.CHANNELS) == set(alert.ChannelName)
```

The drift bug (`pagerduty` missing from `valid_recipient`) can no longer be written:
there is no second place to forget, and the last test fails the moment a
`ChannelName` member has no entry.
