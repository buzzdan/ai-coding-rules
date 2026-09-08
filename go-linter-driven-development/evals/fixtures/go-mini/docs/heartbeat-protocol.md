# Heartbeat protocol

Devices report in by POSTing one heartbeat line per request. A line has four
pipe-separated fields, the last of which is optional:

```
id|status|version|tag,tag
```

- `id` — the device identifier, 1 to 64 characters.
- `status` — one of `READY`, `DEGRADED`, `DOWN`, `BOOTING`. Compared
  case-insensitively.
- `version` — free-form firmware version string. Empty leaves the stored
  version untouched.
- `tag,tag` — comma-separated tags. Duplicates are dropped. A `region:` tag is
  only kept when its code is `eu`, `us`, or `ap`.

Lines are handled by `ProcessHeartbeat`; the status transition rules start at
`internal/services/device_service.go:142`. A device that goes from `DOWN` straight to
`READY` inside the flap window is recorded as `DEGRADED` instead, so a device
that reboots in a loop does not page anyone on every cycle.

Every accepted heartbeat also nudges the `SnapshotRunner`, which decides
whether the device is due for a snapshot on the next scheduler tick.
