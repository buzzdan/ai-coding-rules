# SMS alert channel

## Why

On-call engineers miss Slack pings and mail when they are away from a desk, and
not every team has PagerDuty. We want a fourth way to reach people: a plain text
message to a phone.

## What we want

- Add an `sms` alert channel next to the existing email, slack and pagerduty channels.
- The recipient of an sms alert is a phone number in international (E.164) form:
  a leading `+` followed by 8 to 15 digits and nothing else — no spaces, dashes
  or brackets. Anything else is a bad recipient and is rejected the same way a
  bad email address or Slack channel is rejected today.
- Text messages are short: if an alert's summary is longer than 160 characters,
  deliver the first 160 characters only. The alert itself is not changed.
- When an sms delivery fails, wait 10 seconds before the next attempt. The
  existing waits for the other channels stay as they are.
- Delivery goes through the webhook the service already posts to (`WEBHOOK_URL`).
  The JSON body of an sms delivery must carry `"channel":"sms"`, the phone number
  as `"to"`, and the (possibly shortened) text as `"message"`.
- sms must work everywhere the other three channels work today: recipient
  checks, delivery, retry timing, and the alerts raised when a device goes DOWN.
  When the configuration setting `ONCALL_PHONE` is set (same place as the other
  settings), a device going DOWN raises an sms alert to that number in addition
  to the page it raises today. When it is not set, nothing changes.
- Add `GET /channels` to the HTTP API. It returns `200`, `application/json`, and
  a JSON array of the supported channel names, for example
  `["email","slack","pagerduty","sms"]`.

## Acceptance criteria

- An sms alert to `+14155550100` is accepted; the same alert to `14155550100`
  (no plus), `+1234567` (too short), `+1 415 555 0100` (spaces) or
  `+1234567890123456` (16 digits) is rejected as a bad recipient.
- An sms alert whose summary is 200 characters long is delivered with exactly the
  first 160 characters as its message.
- A failed sms delivery waits 10 seconds before retrying; email, slack and
  pagerduty keep their current waits.
- Every sms delivery is a POST to the webhook whose JSON body contains
  `"channel":"sms"`, `"to"` and `"message"`.
- With `ONCALL_PHONE=+14155550100`, a device transitioning to DOWN produces an sms
  alert to that number; without it, DOWN behaves exactly as before.
- `GET /channels` lists `sms` together with the three existing channels.
- Everything that works today keeps working: `task test` and `task lint` are
  clean after the change.

## Out of scope

- No new dependencies — `go.mod` stays as it is, and tests keep using the
  standard library `testing` package like the rest of the repository.
- No real SMS provider integration; the webhook is the delivery mechanism.
- No changes to the heartbeat wire format or the device store.
