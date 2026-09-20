```go
// ❌ the comment is the function name you did not write
func (h *Handler) Heartbeat(ctx context.Context, raw []byte) error {
    // parse and validate
    var hb wire.Heartbeat
    if err := json.Unmarshal(raw, &hb); err != nil {
        return err
    }
    if hb.DeviceID == "" {
        return errNoDevice
    }
    // already seen? skip
    if _, ok := h.seen[hb.DeviceID]; ok {
        return nil
    }
    // ... forty more lines
}

// ✅ three named steps at one level; each is a leaf you can test with literals
func (h *Handler) Heartbeat(ctx context.Context, raw []byte) error {
    hb, err := device.ParseHeartbeat(raw)
    if err != nil {
        return err
    }
    if h.seen.Has(hb.ID()) {
        return nil
    }
    return h.fleet.Record(ctx, hb)
}
```
