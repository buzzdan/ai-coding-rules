# Comment Noise Case: Nine Private Helpers, Nine Comments

Demonstrates: R9 (comment policy — the visibility default)

A real 143-line file from a JSON-RPC-over-HTTP client (anonymized), written by an
LLM flow before the visibility default existed. It detects which codec decoded a
reply body: JSON, or the client's configured non-JSON codec (msgpack). Every one
of its nine unexported symbols carries a comment; the file has more comment lines
than code lines. Each comment, judged alone, "delivers a toolbox value". The file
as a whole is unreadable — a human reviewer of a sibling PR called the style
"utterly lacking empathy for the reader".

This is the case law for R9's visibility default: **unexported symbols get no
comment; the special case is one line carrying a very high-value toolbox item.**

## The before — representative excerpts

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

## The verdicts

All nine symbols are unexported, so the question is existence, not size:

| Symbol | Before | Verdict | Why |
|---|---|---|---|
| `nonJsonLeadingByteFloor` | 5 lines | one-liner survives | the WHY of the magic number ('{' is 0x7b; msgpack maps start at 0x80) — the code cannot carry it |
| `msgpackAliasContentType` | 5 lines | DELETE | the name and value say it; "D-04 requires" is a decoder ring; "not a table, per Pitfall 3" is review-defense narration |
| `UTF8_BOM` | 6 lines | one-liner survives | an ordering constraint: 0xEF ≥ the floor, so the BOM check must run before the leading-byte check |
| `trimUtf8Bom` | 6 lines | DELETE | the name is the documentation; the `JSON.parse` quirk belongs to `replyBytesForDecode`, its only decode-side caller |
| `detectReplyCodec` | 7 lines | DELETE | narrated implementation ("Bounds-checked: it never indexes an empty `Uint8Array`") plus cross-repo provenance |
| `replyBytesForDecode` | 8 lines | one-liner survives | a standard-library quirk: `JSON.parse` rejects a leading BOM as an unexpected token, not whitespace, and `TextDecoder` strips it only with `ignoreBOM: false` |
| `normalizeContentType` | 4 lines | DELETE | the name says it; the caller list rots |
| `isMsgpackAliasContentType` | 5 lines | DELETE | the name says it; decoder rings and review-defense again |
| `replyCodecAndMismatch` | 22 lines | one-liner survives | the module's one real policy: bytes pick the decoder, the header is only a signal — the rest moves to the feature doc |

Four one-liners survive out of nine comments; roughly 68 comment lines become 4.
None of the nine is a `jsdoc/require-jsdoc` obligation: the rule, as the house
configures it (`publicOnly`), prices exported names only, so a non-exported helper
with no JSDoc is silent under the strictest config, and a WHAT-comment on one is
deleted, not rewritten.

## The after

```typescript
import type { Codec } from './jsonrpc'
import { CONTENT_TYPE_JSON, CONTENT_TYPE_MSGPACK, JSON_CODEC } from './jsonrpc'

// JSON envelopes start with '{' (0x7b); msgpack maps start at 0x80 or above.
const nonJsonLeadingByteFloor = 0x80

const msgpackAliasContentType = 'application/x-msgpack'

// A BOM's lead byte (0xEF) is above the floor, so strip it before the leading-byte check.
const UTF8_BOM = new Uint8Array([0xef, 0xbb, 0xbf])

function trimUtf8Bom(data: Uint8Array): Uint8Array {
  const hasBom = UTF8_BOM.every((byte, i) => data[i] === byte)
  return hasBom ? data.subarray(UTF8_BOM.length) : data
}

function detectReplyCodec(data: Uint8Array, nonJson: Codec): Codec {
  const body = trimUtf8Bom(data)
  if (body.length === 0) {
    return JSON_CODEC
  }
  if (body[0] >= nonJsonLeadingByteFloor) {
    return nonJson
  }

  return JSON_CODEC
}

// JSON.parse rejects a leading BOM as an unexpected token, and TextDecoder strips it only with ignoreBOM: false, so JSON trims it here.
function replyBytesForDecode(codec: Codec, rawResponse: Uint8Array): Uint8Array {
  if (codec.contentType === CONTENT_TYPE_JSON) {
    return trimUtf8Bom(rawResponse)
  }

  return rawResponse
}

function normalizeContentType(headerContentType: string): string {
  const [contentType] = headerContentType.split(';')
  return contentType.trim().toLowerCase()
}

function isMsgpackAliasContentType(headerContentType: string): boolean {
  const contentType = normalizeContentType(headerContentType)
  return contentType === CONTENT_TYPE_MSGPACK || contentType === msgpackAliasContentType
}

// The body bytes always pick the decoder; a disagreeing Content-Type header is only reported, never trusted.
function replyCodecAndMismatch(
  data: Uint8Array,
  nonJson: Codec,
  headerContentType: string,
): { codec: Codec; mismatch: boolean } {
  const codec = detectReplyCodec(data, nonJson)
  if (data.length === 0 || nonJson.contentType === CONTENT_TYPE_JSON) {
    return { codec, mismatch: false }
  }

  const headerSaysNonJson =
    normalizeContentType(headerContentType) === normalizeContentType(nonJson.contentType) ||
    (isMsgpackAliasContentType(headerContentType) && nonJson.contentType === CONTENT_TYPE_MSGPACK)
  const bodySaysNonJson = codec.contentType !== CONTENT_TYPE_JSON

  return { codec, mismatch: headerSaysNonJson !== bodySaysNonJson }
}
```

The knowledge that was worth keeping and did not fit a one-liner — the
msgpack-alias carve-out, why a JSON-only client never reports a mismatch — moves
to the feature doc, where the exported caller's JSDoc points with its See-edge.
The exported API (`decodeReply`, the module's one export below these helpers, and
the mismatch event `apiClient.parseResponse` raises) is where a reader meets this
module; that is where the tier budgets and the See-edge live.

## The lesson

The tier budget caps how big a comment can be; only the visibility default
decides whether it should exist at all. Before this case, "Helper: 0–1 lines"
read as permission, and a writer in fill-the-menu mode gave every private symbol
its tier maximum — nine comments, each locally justified, jointly unreadable.
The default for unexported symbols is **zero**: the name is the documentation,
and a name that needs a comment wants a rename or an extraction first. The
special case is **one line carrying a very high-value toolbox item** — an
ordering constraint, an external library quirk, the WHY of a magic number, the
package's one real policy. If a private symbol seems to need more than that one
line, the knowledge belongs to the exported symbol that uses it, the package
doc, or the feature doc.
