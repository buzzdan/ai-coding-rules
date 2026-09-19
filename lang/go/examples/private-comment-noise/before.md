A 5-line comment on a private constant, with cross-repo provenance:

```go
// nonJSONLeadingByteFloor is the lowest leading byte a non-JSON wire
// frame can start with in the leading-byte detection heuristic:
// JSON-RPC 2.0 envelopes always start with '{' (0x7b), and msgpack maps
// (fixmap, map16, map32) always start at 0x80 or above — the same
// boundary the legacy client's detectCodec uses.
nonJSONLeadingByteFloor byte = 0x80
```

Decoder rings and review-defense narration on another constant:

```go
// msgpackAliasContentType is the second literal spelling D-04 requires
// this package to accept as msgpack, alongside jsonrpc.ContentTypeMsgpack
// ("application/msgpack"). Named as a single constant — not a table —
// per Pitfall 3: a third wire format would earn its own narrow check,
// not a generalized alias registry.
msgpackAliasContentType = "application/x-msgpack"
```

Six lines on a one-line function, with forward references to its callers:

```go
// trimUTF8BOM strips a leading UTF-8 BOM from data, returning data unchanged
// when no BOM is present. Used both to classify a reply's byte verdict
// (detectReplyCodec) and, for a JSON verdict, to decode it
// (Client.ParseResponse): encoding/json treats a BOM as an invalid leading
// byte rather than whitespace, so leaving it in would still fail to decode
// even after correct classification.
func trimUTF8BOM(data []byte) []byte {
    return bytes.TrimPrefix(data, utf8BOM)
}
```

A caller list that rots on the next caller:

```go
// normalizeContentType strips any ";"-delimited parameters (e.g.
// "; charset=binary"), trims surrounding whitespace, and lowercases the
// result — the shared normalization step both isMsgpackAliasContentType and
// replyCodecAndMismatch's header cross-check use (see codec_event.go).
func normalizeContentType(headerContentType string) string {
```

And the centerpiece: **22 prose lines on an unexported function** — over 4× the
budget of an exported crossroads — ending in a sixty-word sentence:

```go
// replyCodecAndMismatch returns the byte-verdict codec (identical to
// detectReplyCodec) plus a bool that is true when the normalized
// Content-Type header disagrees with that byte verdict. The byte verdict
// always governs the actual decode (D-04: bytes-first); mismatch is only a
// signal for the caller's CodecEvent, never a second decode selector.
//
// headerSaysNonJSON is true when the header exactly names nonJSON's own
// content type, OR — the msgpack-alias carve-out D-04 requires — the
// header is either msgpack spelling AND nonJSON's content type IS msgpack
// (the alias never claims agreement for an unrelated non-JSON codec).
//
// An empty body never mismatches: it is not a valid non-JSON envelope
// regardless of what the header claims.
//
// A Client with no distinct non-JSON codec configured (nonJSON is the
// jsonrpc.JSONCodec{} default) never mismatches either: with nothing but
// JSON to disagree with, an ordinary JSON reply's own "Content-Type:
// application/json" header would otherwise satisfy headerSaysNonJSON's
// literal string comparison against nonJSON.ContentType() (also
// "application/json"), producing a false-positive mismatch on every
// zero-config JSON call — a bug this guard forecloses rather than lets a
// caller's mismatch check ever observe.
func replyCodecAndMismatch(data []byte, nonJSON jsonrpc.Codec, headerContentType string) (jsonrpc.Codec, bool) {
```
