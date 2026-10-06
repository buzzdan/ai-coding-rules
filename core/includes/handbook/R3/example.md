```text
# ❌ the comment is the function name you did not write
Handler.heartbeat(raw):
    # parse and validate
    hb = decode(raw)                    # fails → return the failure
    if hb.deviceID is empty: fail noDevice
    # already seen? skip
    if hb.deviceID in self.seen: return
    # ... forty more lines

# ✅ three named steps at one level; each is a leaf you can test with literals
Handler.heartbeat(raw):
    hb = device.parseHeartbeat(raw)     # fails → return the failure
    if self.seen.has(hb.id()): return
    return self.fleet.record(hb)
```

> **Spelling:** the extracted step is a function or a method, whichever the
> repository uses for a named step at that level. In every language a name reveals
> its side effect: `align`, `upsert` and `set` mutate; `parse`, `validate` and `is`
> never do. A `parseIP4` that writes a field is a storifying bug even when the flow
> reads well.
