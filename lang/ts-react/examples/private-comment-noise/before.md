A 5-line JSDoc on a non-exported constant, with cross-repo provenance:

```typescript
/**
 * nonJsonLeadingByteFloor is the lowest leading byte a non-JSON wire
 * frame can start with in the leading-byte detection heuristic:
 * JSON-RPC 2.0 envelopes always start with '{' (0x7b), and msgpack maps
 * (fixmap, map16, map32) always start at 0x80 or above — the same
 * boundary the legacy client's detectCodec uses.
 */
const nonJsonLeadingByteFloor = 0x80
```

Decoder rings and review-defense narration on another constant:

```typescript
/**
 * msgpackAliasContentType is the second literal spelling D-04 requires
 * this module to accept as msgpack, alongside CONTENT_TYPE_MSGPACK
 * ("application/msgpack"). Named as a single constant — not a table —
 * per Pitfall 3: a third wire format would earn its own narrow check,
 * not a generalized alias registry.
 */
const msgpackAliasContentType = 'application/x-msgpack'
```

Six lines on a two-line function, with forward references to its callers:

```typescript
/**
 * Strips a leading UTF-8 BOM from data, returning data unchanged when no
 * BOM is present. Used both to classify a reply's byte verdict
 * (detectReplyCodec) and, for a JSON verdict, to decode it
 * (apiClient.parseResponse): the client's TextDecoder runs with ignoreBOM: true,
 * and JSON.parse treats a BOM as an unexpected token rather than whitespace,
 * so leaving it in would still fail to decode even after correct classification.
 */
function trimUtf8Bom(data: Uint8Array): Uint8Array {
  const hasBom = UTF8_BOM.every((byte, i) => data[i] === byte)
  return hasBom ? data.subarray(UTF8_BOM.length) : data
}
```

A caller list that rots on the next caller:

```typescript
/**
 * Strips any ";"-delimited parameters (e.g. "; charset=binary"), trims
 * surrounding whitespace, and lowercases the result — the shared
 * normalization step both isMsgpackAliasContentType and
 * replyCodecAndMismatch's header cross-check use (see codecEvent.ts).
 */
function normalizeContentType(headerContentType: string): string {
```

And the centerpiece: **22 prose lines on a non-exported function** — over 4× the
budget of an exported crossroads — ending in a sixty-word sentence:

```typescript
/**
 * Returns the byte-verdict codec (identical to detectReplyCodec) plus a
 * mismatch flag that is true when the normalized Content-Type header
 * disagrees with that byte verdict. The byte verdict always governs the
 * actual decode (D-04: bytes-first); mismatch is only a signal for the
 * caller's CodecEvent, never a second decode selector.
 *
 * headerSaysNonJson is true when the header exactly names nonJson's own
 * content type, OR — the msgpack-alias carve-out D-04 requires — the
 * header is either msgpack spelling AND nonJson's content type IS msgpack
 * (the alias never claims agreement for an unrelated non-JSON codec).
 *
 * An empty body never mismatches: it is not a valid non-JSON envelope
 * regardless of what the header claims.
 *
 * A client with no distinct non-JSON codec configured (nonJson is the
 * JSON_CODEC default) never mismatches either: with nothing but JSON to
 * disagree with, an ordinary JSON reply's own "Content-Type:
 * application/json" header would otherwise satisfy headerSaysNonJson's
 * literal string comparison against nonJson.contentType (also
 * "application/json"), producing a false-positive mismatch on every
 * zero-config JSON call — a bug this guard forecloses rather than lets a
 * caller's mismatch check ever observe.
 */
function replyCodecAndMismatch(
  data: Uint8Array,
  nonJson: Codec,
  headerContentType: string,
): { codec: Codec; mismatch: boolean } {
```
